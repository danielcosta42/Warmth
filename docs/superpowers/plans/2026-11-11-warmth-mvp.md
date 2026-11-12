# Warmth MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW: Forever addon that shows player-lit campfires announced over ChehulNet on the map, with who is
around each one, and helps the lighter set up and announce a camp; packaged and ready to publish on CurseForge.

**Architecture:** A core with no UI (`Core/`: data tables, wire codec, camp state, network, game watchers) that the
UI (`UI/`) reads and calls. Every moving visual is computed per frame by one driver (`UI/Motion.lua`); no looping
`Scale` animation exists anywhere. Textures are drawn by `tools/gen-media.py`. Each `tools/*.lua` harness runs the
real files under a simulated client and exits 1 on the first failed check.

**Tech Stack:** Lua 5.1 (WoW: Forever, interface 16001), LibStub, AceComm-3.0, LibChehulMesh + ChehulNet (synced
from `danielcosta42/chehulnet` with `tools/sync.sh`), Python 3 standard library for textures, LuaJIT for harnesses,
BigWigsMods/packager for release.

**Spec:** `docs/superpowers/specs/2026-11-11-warmth-design.md`. Throwaway prototype for reference only:
`E:\World of Warcraft\_forever_\Interface\AddOns\Fogueira`.

## Global Constraints

- Nothing about a player goes to the network without consent: a campfire is announced only by a click at that
  moment (repeats of the same announce ride on that click and do not survive `/reload`); presence in a circle
  only after the one-time "yes" (`WarmthDB.consent == true`).
- Only the owner's announce travels the realm bus (`Mesh:Realm(..., true)`); presence and invite requests go by
  whisper to the owner, and on guild/group.
- Rates are limits: announce every 240 s and only with the owner within 60 yards of the fire; presence every
  120 s; one invite request per camp per 120 s. Camp TTL 720 s, person TTL 360 s. Caps: 100 camps, 40 people.
- Everything from the network is validated before entering state; every network string is escaped (`|` → `||`)
  before display. A relayed sender (`dist == "RELAY"`) is claimed: never authority.
- The announce fits one addon message (≤ 240 bytes): people are dropped first, never objects.
- No `Scale` animation in a loop. Sizes and alphas that vary are computed per frame between fixed bounds.
- One handler per prefix: Warmth registers `ChehulCamp` only. Network tag `cf`, cap `cfv=<version>`.
- Item and spell ids come from third-party guides and are unverified: every feature that depends on them
  degrades to a manual path (the player picks the tier; presence by distance).
- English is the default locale; ptBR ships too. No user-facing string outside `Core/Locale.lua`.
- Check `issecretvalue` on every event/network value before using it.
- Commits carry no AI attribution.

## Review Focus

1. Player in an instance or with no map position: announce is refused with a message, nothing errors, pins hide.
2. A forged or truncated `ChehulCamp` payload (wrong field count, huge numbers, `|` in names, 2000 bytes): dropped.
3. Announce with a 40-person circle and long names: payload stays ≤ 240 bytes and keeps every object.
4. Owner logs off / walks away: the camp disappears from others within 720 s; whispers to it stop.
5. Consent never answered, or answered "no": no presence message is ever sent (asserted on the fake mesh).

Each is pinned by a check in the harness of the task that owns the code (tasks 2, 3 and 4).

---

## File map

| File | Responsibility |
|---|---|
| `Warmth.toc` | load order, compartment functions, icon |
| `Core/Init.lua` | namespace `W`, version, saved variables defaults (`WarmthDB`), event hub `W:On(event, fn)` / `W:Fire(event, ...)` |
| `Core/Locale.lua` | `W.L` (enUS, ptBR) |
| `Core/Data.lua` | tiers, kits, wood, the 35 objects (stable index ↔ item id), classes list |
| `Core/Util.lua` | secrets, names, escaping, bag counts, position, distance, zone copy |
| `Core/Wire.lua` | pure encode/decode of `C2` messages |
| `Core/Camps.lua` | camp state: apply, expire, people, objects, sorted list |
| `Core/Net.lua` | mesh registration, send paths, rates, consent gate, invite requests |
| `Core/Watch.lua` | cast detection (kit, object), 10 s ticker (presence, heartbeat), cooking snapshot |
| `UI/Theme.lua` | colours, fonts, media paths |
| `UI/Motion.lua` | per-frame driver: breathe, flipbook, arrive, enter/leave |
| `UI/Widgets.lua` | text, button, chip, glow, flame, seat, slot, scroll list |
| `UI/Ring.lua` | the circle: fire, slots, seats |
| `UI/Window.lua` | frame, header, view switching |
| `UI/Views.lua` | the three views: list, camp, build |
| `UI/Pins.lua` | world map (zone + continent) and minimap pins |
| `UI/Toast.lua` | proximity toast, consent prompt, invite-request prompt |
| `UI/Options.lua` | category in the game's AddOns options tab |
| `UI/Entry.lua` | compartment functions, slash command |
| `tools/gen-media.py` | every texture in `Media/` |
| `tools/wowstub.lua` | simulated client shared by harnesses |
| `tools/core.lua`, `tools/ui.lua` | harnesses |

## Tasks

### Task 1: Repository scaffold and libraries

**Files:** `Warmth.toc`, `.pkgmeta`, `.luacheckrc`, `VERSION`, `.github/workflows/lint.yml`, `Libs/*`,
`chehulnet.lock`, `tools/chehulnet-lock.sh`, `Core/Init.lua`, `tools/wowstub.lua`, `tools/core.lua`.

**Produces:** `W` (the addon namespace, also `_G.Warmth`), `W.VERSION`, `W.db` (after `ADDON_LOADED`) with
defaults `{ consent = nil, toast = true, lessMotion = false, pins = true, invites = true, meshPeers = {} }`,
`W:On(event, fn)`, `W:Fire(event, ...)`.

- [ ] Sync the lib: `tools/sync.sh "../Warmth" Libs/LibChehulMesh.lua Libs/ChehulNet.lua` from the chehulnet repo.
- [ ] `tools/core.lua` check: loading the toc's Core files under the stub leaves `Warmth.VERSION` set and
      `WarmthDB.toast == true` after `ADDON_LOADED`; a saved `consent = false` survives.
- [ ] Implement, run `luajit tools/core.lua`, commit.

### Task 2: Data, wire codec, camp state

**Files:** `Core/Data.lua`, `Core/Util.lua`, `Core/Wire.lua`, `Core/Camps.lua`, `Core/Locale.lua`; test `tools/core.lua`.

**Produces:**
- `W.TIERS = {"Basic","Journeyman","Expert"}`, `W.SLOTS = {3,5,10}`, `W.KITS`, `W.WOOD`, `W.OBJECTS[i] = { id, name, prof, effectKey|nil }`
  (i = 1..35, stable), `W.OBJECT_BY_ID[id] = i`, `W.CLASSES` (13 tokens), `W.TENT`, `W.REPAIR` (object indexes).
- `W.Esc(s)`, `W.Short(name)`, `W.IsSecret(...)`, `W.Count(itemID)`, `W.Position() -> map, x, y | nil`,
  `W.Distance(camp) -> yards | nil`, `W.ZoneName(map)`, `W.MyCopy(map) -> zoneUID | 0`.
- `W.Wire.Announce(camp) -> payload` (≤ 240 bytes), `W.Wire.Join(owner, classIdx, objIdx)`, `W.Wire.End()`,
  `W.Wire.Invite(owner)`, `W.Wire.Decode(payload) -> { kind = "A"|"J"|"X"|"I", ... } | nil`.
  Format: `C2|A|map|x|y|zuid|tier|n|o,o,o|Name~c;Name~c|note`, `C2|J|owner|c|o`, `C2|X`, `C2|I|owner`.
- `W.Camps:Announce(owner, fields) -> camp, isNew`, `:Join(who, owner, classIdx, objIdx)`, `:End(owner)`,
  `:Get(owner)`, `:List() -> camps` (my map by distance, my copy first, then others by zone name),
  `:People(camp) -> { {name, class, obj} }`, `:Objects(camp) -> { objIdx }`, `:Has(camp, objIdx)`,
  `:Count(camp)` (max of announced n and people known), `:OtherCopy(camp) -> true|false|nil`.
  Fires `W:Fire("CAMPS")` on change and `W:Fire("CAMP_NEW", camp)` for a new camp that is not mine.

- [ ] Checks: round-trip of every message; Review Focus 2 and 3; expiry at 720 s / 360 s; list order;
      `OtherCopy` true/false/nil; caps of 100 camps and 40 people.
- [ ] Implement, run, commit.

### Task 3: Network and watchers

**Files:** `Core/Net.lua`, `Core/Watch.lua`; test `tools/core.lua`.

**Produces:** `W.Net:Announce(tier, note) -> camp | nil, reasonKey`, `W.Net:End()`, `W.Net:Presence(owner)`
(no-op unless `W.db.consent == true` or `owner == W.me`), `W.Net:RequestInvite(owner) -> ok, reasonKey`,
`W.Net:AnswerInvite(name, accept)`; fires `W:Fire("INVITE_REQUEST", name)`, `W:Fire("CONSENT_NEEDED", camp)`,
`W:Fire("LIT", tier)`. `W.lit = { at, tier }`, `W.myObject` (object index or 0), `W.cooking = { at, ready = n, names = {} } | nil`.

- [ ] Checks: Review Focus 1, 4, 5; announce goes Guild + Group + Realm(relay); presence goes Whisper(owner) +
      Guild + Group and never Realm; rates (second announce inside 20 s refused; heartbeat only within 60 yards);
      lighting a kit sends nothing; placing an object near a camp sends presence only with consent; invite
      request reaches only the owner and respects `W.db.invites`.
- [ ] Implement, run, commit.

### Task 4: Textures and font

**Files:** `tools/gen-media.py`, `Media/*.tga`, `Media/Fonts/*` (+ its OFL licence); lint step.

**Produces (all white-in-alpha unless noted):** `glow` (radial falloff), `flame` (8-frame sheet, coloured),
`logs` (coloured), `ring`, `disc`, `slot`, `slot-empty`, `grain` (tileable), `vignette`, `corner`, `crown`
(owner mark), `logo` (coloured, 64) and `logo-512.png` for the store.

- [ ] `python -I tools/gen-media.py` writes them; `--check` passes; render previews and look at them.
- [ ] Commit.

### Task 5: Motion and widgets

**Files:** `UI/Theme.lua`, `UI/Motion.lua`, `UI/Widgets.lua`; test `tools/ui.lua`.

**Produces:** `Motion.Breathe(region, speed, apply)`, `Motion.Flipbook(texture, frames, fps)`,
`Motion.Arrive(frame, delay)` (needs `Motion.Place(frame, parent, x, y)` first), `Motion.Enter(frame, dy)`,
`Motion.Leave(frame, onDone)`, `Motion.Tick(now)` (the driver's body, callable from tests); `W.db.lessMotion`
turns Arrive/Enter into plain fades. Widgets: `Text`, `Button`, `Chip`, `Glow`, `Flame`, `Seat`, `Slot`,
`ScrollList`.

- [ ] Check: one simulated minute of `Motion.Tick` leaves every scale in [0.4, 1] and every size ≤ its start × 1.1.
- [ ] Implement, run, commit.

### Task 6: Window, ring and the three views

**Files:** `UI/Ring.lua`, `UI/Window.lua`, `UI/Views.lua`; test `tools/ui.lua`.

**Produces:** `W.UI:Show(view, owner)`, `W.UI:Toggle()`, `W.UI:Render()`; views `"list"`, `"camp"`, `"build"`.

- [ ] Checks: every view draws under the stub with 0, 1 and 12 camps; the ring shows up to 9 seats plus the
      empty "you" seat, the tier's slots, the owner's mark; other-copy camps are labelled; the empty list
      explains itself; Build shows kits, objects, cooking snapshot, and Announce calls `W.Net:Announce`.
- [ ] Implement, run, commit.

### Task 7: Pins, toast, prompts, options, entry

**Files:** `UI/Pins.lua`, `UI/Toast.lua`, `UI/Options.lua`, `UI/Entry.lua`; test `tools/ui.lua`.

- [ ] Checks: one pin per camp on the zone map and on the continent map; minimap pin placed inside the
      minimap radius and clamped at the edge up to 1000 yards; toast on `CAMP_NEW` in my map only and only
      with `W.db.toast`; consent prompt once, its answer stored; invite prompt accept/decline; compartment
      functions named in the toc exist; `/warmth` toggles.
- [ ] Implement, run, commit.

### Task 8: Release readiness

**Files:** `README.md`, `CHANGELOG.md`, `CURSEFORGE-DESCRIPTION.md`, `.pkgmeta`, workflows, `AGENTS.md`.

- [ ] `luacheck Core UI` clean (install locally if available; otherwise CI is the gate, and say so).
- [ ] Build the package folder locally exactly as `.pkgmeta` would, install it into the game's AddOns as
      `Warmth`, and disable the prototype (both register `ChehulCamp`).
- [ ] Whole-branch review by a fresh reviewer; fix what it finds.
- [ ] Hand over: what is left for the owner (CurseForge project id, GitHub repo and secrets, in-game checks).
