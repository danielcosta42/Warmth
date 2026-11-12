# Warmth

Campfires lit by players, on your map, for **WoW: Forever** (interface 16001). See what each camp offers and who
is around the fire, go there, and set up your own. Runs on the [ChehulNet](https://github.com/danielcosta42/chehulnet)
network, shared with GuildOS, Lodestar and PartyLens.

The store page text is in [CURSEFORGE-DESCRIPTION.md](CURSEFORGE-DESCRIPTION.md). The design is in
[docs/superpowers/specs/2026-11-11-warmth-design.md](docs/superpowers/specs/2026-11-11-warmth-design.md).

## Layout

| Path | What it is |
|---|---|
| `Core/` | No frames: data tables, the `ChehulCamp` wire format (`C2`), camp state, network rules, game watchers |
| `UI/` | The window (list, circle, set-up), map and minimap pins, toast and questions, options, entry points |
| `Media/` | Textures drawn by `tools/gen-media.py`, the store logo and the title font (Young Serif, OFL) |
| `Libs/` | LibStub, AceComm-3.0, and the ChehulNet library synced from its own repository (`chehulnet.lock`) |
| `tools/` | Harnesses that run the real files under a simulated client, the texture script, the key lister |

## Working on it

```bash
luacheck Core UI                      # undefined globals are errors (.luacheckrc is the API inventory)
luajit tools/core.lua                 # wire format, camps, network and consent rules
luajit tools/ui.lua                   # views, motion bounds, pins, toast, options, ptBR completeness
python -I tools/gen-media.py          # redraw Media/*.tga (add --check to verify, --preview DIR for PNGs)
bash tools/chehulnet-lock.sh          # the vendored network library is untouched
```

Rules that are easy to break:

- **Nothing about a player leaves without consent.** Announcing is a click; presence in a circle needs the
  one-time yes (`WarmthDB.consent`). `tools/core.lua` asserts both on a fake mesh.
- **Only the owner's announce uses the realm bus.** Presence and invite requests go to the owner by whisper.
- **No looping `Scale` animation.** On the Forever client it accumulates until the region covers the screen.
  Everything that moves is computed per frame in `UI/Motion.lua`.
- **Item and spell ids are unverified** (third-party guides). Every feature built on them has a manual path.
  `/warmth probe` records what the client reveals (casts, auras, vignettes, tooltips, the interact target, which
  APIs exist) into `WarmthDB.probe`; read it in `WTF/Account/<account>/SavedVariables/Warmth.lua` after a `/reload`.
- **The network library is never edited here.** Change it in `danielcosta42/chehulnet` and run its `tools/sync.sh`.
- **Every user-facing string goes through `W.L`**; `luajit tools/keys.lua` lists them and `tools/ui.lua` fails
  when ptBR misses one.

## Releasing

Edit `VERSION` and `CHANGELOG.md` and merge to `main`. `auto-tag.yml` tags `vX.Y.Z`; `release.yml` packages with
BigWigsMods/packager and publishes to CurseForge. It needs the secrets `CF_API_KEY` and `RELEASE_PAT`, and
`## X-Curse-Project-ID` in `Warmth.toc` once the CurseForge project exists.

## License

MIT. The title font is Young Serif, under the SIL Open Font License (`Media/Fonts/OFL.txt`).
