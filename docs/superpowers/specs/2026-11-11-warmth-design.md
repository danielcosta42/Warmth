# Warmth: desenho do addon

Data: 2026-11-11. Estado: para aprovação. O addon se chama **Warmth**; "Fogueira" é o nome do protótipo.

Este documento descreve o addon de verdade. O que existe hoje em `AddOns/Fogueira` é um protótipo descartável
(`Core.lua`, `UI.lua`), feito para sentir a direção visual dentro do jogo. Ele serve de referência de comportamento
e de armadilhas do cliente, não de base de código obrigatória.

## 1. Intenção

No WoW: Forever, uma fogueira acesa por um jogador vira um acampamento: cada jogador põe um objeto da profissão
dele, e quem senta perto por um minuto ganha os benefícios por uma hora. Hoje ninguém sabe onde há uma fogueira
acesa, o que ela oferece, nem se há gente lá.

O Warmth usa a rede ChehulNet para mostrar no mapa as fogueiras que os jogadores **escolheram anunciar**, com o
que cada uma tem e quem está em volta, e ajuda quem acende a montar o acampamento e chamar gente.

O que o torna especial é o clima: tem de parecer um lugar aconchegante e de comunidade, não uma planilha. O dono
do projeto pesa o visual e as transições tanto quanto a função.

## 2. Objetivos, não-objetivos, anti-objetivos

**Objetivos (primeira versão)**

1. Achar uma fogueira acesa: pinos no mapa-múndi e no minimapa, e uma lista por distância com filtros. É o
   coração do addon: se só uma coisa sair perfeita, é esta.
2. Ver um acampamento antes de ir: nível da fogueira, espaços ocupados, quais objetos e o que cada um dá, quem
   está na roda, o recado do dono.
3. Ir até lá: um clique põe o waypoint do jogo.
4. Aviso de proximidade quando anunciam uma fogueira no mapa onde o jogador está.
5. Montar acampamento: checklist do que há na bolsa para acender, para pôr o objeto da profissão e para
   cozinhar; depois, anunciar com um recado.
6. A roda viva: quem tem o addon e senta num acampamento anunciado aparece na roda dos outros, com o objeto
   que pôs.

**Não-objetivos**

- Fogueiras fixas do mundo (de NPC, de vila). Só as acesas por jogadores.
- Acender a fogueira ou pôr o objeto pelo addon. O jogador usa o item da bolsa.
- Agendar acampamentos com hora marcada e confirmação de presença.
- Chat próprio do acampamento.
- Mostrar fogueiras de quem não anunciou, mesmo que o addon consiga detectá-las.

**Anti-objetivos (seria fracasso mesmo funcionando)**

- Mandar à rede algo que o jogador não autorizou: a fogueira só é anunciada com um clique naquela hora (as
  repetições do mesmo anúncio valem pelo clique, e não sobrevivem a um `/reload` ou relog: o dono anuncia de novo);
  a presença na roda só sai depois do "sim" dado uma vez.
- Parecer ferramenta de eficiência: tabela densa, números por toda parte, cara de planilha.
- Pesar na rede: mensagens frequentes, ou qualquer coisa que faça o servidor bloquear o canal da malha de novo.
- Quebrar a tela do jogador (ver "Armadilhas do cliente").

## 3. O que o dono do projeto decidiu

- **Só fogueiras de jogadores**, vistas por **toda a rede** (mesma facção e ruleset, que é até onde a malha vai).
- **Anúncio só manual.** Nada sai sem o jogador clicar em anunciar.
- **Acampamento é fogueira com gente:** o mapa mostra quantos estão em volta.
- Quem está longe ganha: **pino no mapa, aviso de proximidade, seta até lá e lista**. O pino e a lista mostram
  **quais benefícios** a fogueira tem.
- O checklist serve para **acender, pôr/melhorar com o objeto e cozinhar**.
- **Addon novo**, próprio, da família Chehul, chamado **Warmth** (nome em inglês, uma palavra só). Na loja,
  com subtítulo que diga o que é ("Warmth: Campfires & Camps"); comando `/warmth`.
- Direção visual **"Brasa"**: noite quente, o fogo no centro com brilho que respira, as pessoas sentadas em roda,
  os objetos entre as pessoas e o fogo, um lugar vazio marcado "você". Mockups aprovados e protótipo aprovado no
  jogo ("ficou legal, falta refino nas artes").
- **Todas as artes pedem refino:** a chama, as pessoas na roda, a janela e o fundo, as letras.
- **Lançamento: o Warmth sai primeiro**, com o alcance de guilda, grupo e poucos pares. A versão da lib que faz
  os outros addons repassarem os anúncios vem depois, e o alcance cresce sozinho conforme eles forem lançados.
- **Botão nativo:** o addon aparece na lista de addons do próprio jogo (o compartimento de addons), com ícone;
  o comando existe, mas o botão é a entrada principal.
- **As artes são geradas por código** (script que produz os arquivos de textura), sem depender de artista.
- **Cópias da zona (camadas):** o mapa mostra todas as fogueiras; as de outra cópia vêm marcadas, e "Ir até lá"
  oferece pedir ao dono um convite de grupo para cair na cópia dele.
- **Aparecer na roda dos outros:** o addon pergunta uma vez ("aparecer nas rodas?"); com o sim, o jogador entra
  sozinho na roda quando senta num acampamento anunciado, e pode desligar nas opções. Sem o sim, ele não aparece na
  roda de ninguém. (O HELLO do ChehulNet, com classe, nível e zona, sai de todo addon da família e não depende
  disto: é o que faz a rede existir. Os textos do addon prometem só o que é do Warmth: a fogueira e a roda.)

## 4. Como o jogo funciona (o que se sabe e o que falta medir)

Fonte: dois guias de terceiros (wow-professions.com e conquestcapped.com, novembro de 2026). **Nada disto foi
conferido no jogo**; os ids em especial.

- Acende-se com um kit de Culinária: Basic (item 279981, 3 espaços, 1 Simple Wood 4470), Journeyman (279961,
  5 espaços, Star Wood 11291), Expert (279974, 10 espaços, Thick Logs 272941).
- Cada jogador põe um objeto por acampamento; os objetos têm 1 hora de recarga. São 35, três por profissão
  (perícia 20, 140, 300; Culinária tem dois). Os de perícia 20 dão benefício; os outros são estações de ofício.
  A tabela com ids, profissão e efeito está em `Core.lua` do protótipo (`F.OBJECTS`).
- Sentar perto do fogo cerca de 1 minuto dá um benefício único ("Camp Benefits") por 1 hora. Qualquer um pode
  usar, com ou sem grupo. Os benefícios não acumulam com os de classe equivalentes.
- Acampamentos ficam a pelo menos 100 jardas um do outro, fora de cidades. Há um benefício "Campfire Nearby"
  (feitiço 1283391) perto de um acampamento.

**Medido no jogo com `/warmth probe`** (2026-11-11, build 1.60.1.70888, personagem em Durotar):

| Pergunta | Resposta | O que o addon faz com ela |
|---|---|---|
| Os ids dos kits e objetos conferem? | Sim, os 41. `C_Item.GetItemSpell` dá o feitiço de cada um (Basic Campfire 1307227, Journeyman 1307252, Expert 1307237; Camp Chair 1307229...), e `UNIT_SPELLCAST_SUCCEEDED` traz esse id. Acender leva 10 s de conjuração. | Reconhece sozinho o nível aceso e o objeto posto |
| Há sinal de fogueira por perto? | Sim: a aura "Campfire Nearby" (1283391) liga perto de qualquer fogueira acesa, de qualquer jogador, e desliga ao se afastar | Só anuncia com fogo de verdade; só entra na roda com fogo presente; encerra o anúncio quando o fogo do dono some; marca "sem fogo aqui" o acampamento anunciado onde não há fogo (outra cópia da zona, ou apagou) |
| Dá para saber que o jogador sentou e ganhou o benefício? | Sim: "Welcoming Campfire" (1229739, 60 s) é o minuto sentado; "Camp Benefits" (1229741) é o benefício (7200 s no teste, com o brinquedo da Twitch) | Ainda não usado (a roda entra por distância mais fogo presente) |
| Dá para ler a fogueira ou os objetos de quem não tem o addon? | Não automaticamente. Não há alvo de interação com GUID nem marcador de minimapa; o tooltip do objeto do mundo só traz o nome ("Basic Campfire", "Chair"), e só com o mouse em cima | Só aparecem objetos informados por quem tem o addon |
| Chamas violetas (Pouch of Violet Dust, brinquedo da celebração de lançamento) | Lança Throw Violet Dust (1328348) e deixa a aura "Violet Flames" (1328375) em quem está junto do fogo | O dono anuncia a chama violeta (letra `v` junto do nível); quem está no fogo vê na hora |
| Erros do jogo ao montar | "You cannot place a new campfire within 100 yards of an existing campfire." e "You cannot place a feature that close to a creature or object." (`UI_ERROR_MESSAGE`) | Ainda não usados |
| APIs que faltam no Forever | `GetItemSpell` global (há `C_Item.GetItemSpell`), as de ofício clássicas `GetTradeSkill*` (há `C_TradeSkillUI`), `C_SuperTrack.SetSuperTrackingUserWaypoint`, `InviteUnit` global (há `C_PartyInfo.InviteUnit`) | Culinária lê por `C_TradeSkillUI`; o waypoint é posto sem a seta |

**Ainda a medir:** quanto dura a fogueira; o que a bolsa de dormir (item 211527) põe no jogador e como combina com o
fogo; os campos de `C_TradeSkillUI` na janela de Culinária (a sonda já os grava); Flint and Tinder e a perícia dos
kits maiores.

## 5. Rede

O addon embute a lib ChehulNet (`LibChehulMesh.lua` + `ChehulNet.lua`) vinda de `danielcosta42/chehulnet` pelo
`tools/sync.sh`, com `chehulnet.lock`, como os outros addons da família. Registra-se como nó (`ChehulNet:Register`)
com a tag `cf` e a cap `cfv=<versão>`, e passa um `Mesh:PeerStore`.

Prefixo `ChehulCamp`. O formato abaixo (versão `C2`) substitui o `C1` do protótipo, que nunca foi publicado e não
precisa de compatibilidade. O desenho é: **só o anúncio do dono viaja pelo realm**; a presença de cada um vai só
ao dono, que a resume no anúncio seguinte. Assim o custo na rede não cresce com o tamanho da roda.

- **Anúncio (dono, pelo realm com repasse, pela guilda e pelo grupo):** mapa, x, y (inteiros de 0 a 10000), a
  cópia da zona (o `zoneUID` que o ChehulNet já conhece, 0 se desconhecido), nível da fogueira, quantas pessoas na
  roda, há quantos minutos foi anunciado pela primeira vez, os objetos postos, até 9 pessoas (nome e classe) para
  desenhar a roda, e o recado (até 80 bytes, sem `|`). O formato exato está no cabeçalho de `Core/Wire.lua`.
  Tem de caber em uma mensagem; se não couber, cortam-se as pessoas, nunca os objetos.
- **Presença (visitante que deu o "sim", por whisper ao dono; e pela guilda e pelo grupo, onde é de graça):**
  "estou na sua roda", com a classe e o objeto que pus (0 = nenhum).
- **Encerrar (dono, pelos mesmos caminhos do anúncio).**
- **Pedido de convite (visitante, por whisper ao dono):** "quero ir para a sua cópia". O dono vê um aviso com
  aceitar/recusar; aceitar convida para o grupo (ação do dono, com clique). O dono pode desligar os pedidos.

Ritmo máximo, que é restrição e não sugestão: o anúncio se repete a cada 4 minutos e só com o dono perto do fogo;
a presença, a cada 2 minutos; um pedido de convite por acampamento a cada 2 minutos. Um acampamento sem notícia há
12 minutos some; uma pessoa sem notícia há 6 minutos sai da roda. Dimensionar para até 50 acampamentos simultâneos
na rede (cerca de 12 anúncios por minuto no total).

Regras de confiança:

- Tudo que chega é validado antes de entrar no estado (faixas numéricas, tamanho, item conhecido) e todo texto
  da rede é escapado antes de ir para a tela (`|` vira `||`). O protótipo e o `tools/selftest.lua` dele mostram os
  casos.
- O remetente de um item repassado (`dist == "RELAY"`) é **alegado**, não verificado. Serve para desenhar um pino;
  nunca para autoridade. Em especial, "encerrar" repassado só vale para o acampamento do próprio remetente alegado,
  e o pior que um forjador consegue é um pino falso ou apagar um pino: aceitável para esta versão. Presença e
  pedido de convite chegam por whisper, guilda ou grupo, onde o remetente é autêntico.
- Tetos: 100 acampamentos, 40 pessoas por roda.

**Mudança na lib (no repo `chehulnet`, depois do lançamento do Warmth e fora do plano dele):** incluir `ChehulCamp` em `Mesh.FAMILY`, para
que clientes sem o Warmth (GuildOS, Lodestar, PartyLens) passem o anúncio adiante. Sem isso o alcance é guilda,
grupo e poucos pares. É uma versão nova da lib e depende do lançamento dos outros addons; o Warmth funciona sem
ela, com alcance menor. Como a primeira versão sai com a lista quase sempre vazia fora da guilda, a lista vazia
precisa explicar isso com gentileza e convidar a acender e anunciar (não pode parecer addon quebrado). O backoffice (CehulNet) já reconhece o prefixo e a tag.

## 6. Telas

Uma janela só, com três vistas, mais os pinos e o aviso. Os mockups aprovados estão em `docs/mockups/`
(`direcao-visual.html` e `telas-brasa.html`): referência de clima e fluxo.

- **Lista "Fogueiras acesas".** Resumo (quantas na rede, quanta gente em volta), filtros (todas, com tenda, com
  conserto, com espaço livre), uma linha por acampamento: título, distância ou zona, gente na roda, espaços, ícones
  dos objetos, e a marca "outra cópia" quando for o caso. Entram todas as fogueiras da rede, sem filtro de nível:
  primeiro as do mapa do jogador (por distância, as da cópia dele antes), depois as outras, pelo nome da zona.
  Com rolagem. Botão "Montar acampamento".
- **Acampamento (a roda).** O fogo no centro; os espaços do nível em volta dele, ocupados com o ícone do objeto ou
  vazios; as pessoas por fora, na cor da classe; um lugar vazio "você" quando o jogador não está lá. Recado do
  dono, lista dos objetos com o que dão, espaços livres, e "sua `<objeto>` cabe aqui" quando o jogador tem na bolsa um
  objeto que falta. Botões: "Ir até lá" e, para o dono, "Encerrar anúncio". "Ir até lá" põe o waypoint; se o acampamento
  está em outra cópia da zona (ou a cópia é desconhecida e o jogador chega e não acha o fogo), oferece "pedir
  convite ao dono".
- **Montar acampamento.** Checklist: kits e madeira na bolsa; objetos de acampamento na bolsa; o que dá para
  cozinhar agora; depois nível da fogueira (preenchido pela detecção, corrigível), recado e "Anunciar acampamento
  aqui". Uma linha fixa: "Nada vai para a rede sem você clicar em anunciar".
- **Pinos.** No mapa da zona, no mapa do continente e no minimapa: brilho que respira, maior com mais gente;
  número de pessoas; os de outra cópia mais apagados; tooltip com o resumo; clique abre a roda.
- **Aviso de proximidade.** Desliza no alto da tela quando anunciam no mapa do jogador; some sozinho; clique abre
  a roda. Vale também para outra cópia da zona, dizendo que é outra cópia. Pode ser desligado.
- **Botão nativo.** A entrada no compartimento de addons do jogo, declarada no `.toc` (`AddonCompartmentFunc`,
  `AddonCompartmentFuncOnEnter`, `AddonCompartmentFuncOnLeave`, `IconTexture` com o ícone próprio do addon), como
  o protótipo já faz. Clique abre ou fecha a janela; clique direito vai a Montar acampamento; a dica diz quantas
  fogueiras estão acesas e quanta gente há em volta. As opções do addon ficam na aba AddOns das opções do jogo.
- **A pergunta única.** Na primeira vez que o jogador chega a um acampamento anunciado: "aparecer nas rodas?",
  com o que isso mostra aos outros (nome, classe, objeto) e onde desligar.

**Transições** (parte do pedido, não enfeite): troca de vista com fade e deslize; pessoas e objetos "chegam" à roda
um a um; o brilho respira e a chama treme. Uma opção "menos animação" deixa só os fades.

## 7. Arte

Todas geradas por script versionado no repo (ex.: `tools/art/*.py` produzindo TGA/PNG em `Media/`), para poder
refazer mudando parâmetros. Nada de arte de terceiros sem licença compatível.

- **Chama:** uma fogueira desenhada (lenha e chama), em folha de quadros para animar, no lugar do ícone de feitiço
  recortado do protótipo.
- **Brilho:** um gradiente radial de verdade, no lugar dos círculos empilhados.
- **Pessoas na roda:** mais vivas que círculo com iniciais. Proposta: anel na cor da classe com o ícone de classe
  do próprio jogo dentro, e o nome ao passar o mouse; o dono do fogo com uma marca.
- **Janela e fundo:** textura (grão, vinheta quente) e moldura próprias, no lugar do fundo liso.
- **Letras:** uma fonte serifada livre embutida para títulos (o mockup usa Fraunces, licença OFL) que cubra os
  acentos do português; corpo numa fonte legível em tamanho pequeno.

A arte é um marco cedo, não um acabamento no fim: primeiro as texturas e a fonte dentro da roda do protótipo, para
o dono ver no jogo e pedir ajustes (contar com duas ou três rodadas); as telas definitivas são construídas sobre a
arte aprovada. Os mockups valem pelo clima e pelo fluxo, não pela posição exata de cada coisa.

## 8. Restrições

- **Cliente WoW: Forever** (interface 16001), API moderna com valores secretos e restrições de chat: checar
  `issecretvalue` em tudo que vem de evento, como o ChehulNet faz.
- **Armadilhas do cliente, aprendidas no protótipo:**
  - Animação `Scale` em laço **acumula** e o elemento cresce sem parar até cobrir a tela. Nada de `Scale` em
    laço: tamanho e transparência que variam são calculados a cada quadro, entre limites fixos.
  - Addon novo só aparece depois de sair para a tela de personagens; `/reload` não basta.
- **Um handler por prefixo** na LibChehulMesh: o Warmth só registra `ChehulCamp`.
- **Padrão de engenharia do dono** (ferion-engineering): repositório próprio, issue antes de código, `specs/`,
  revisão e preflight antes de PR, sem assinatura de IA em commit ou PR.
- **Teste:** um `tools/selftest.lua` em luajit com cliente simulado, como o do protótipo e o do CehulNet, cobrindo
  validação da rede, a regra "nada sai sem clique" e que nenhuma animação passa dos limites.

## 9. Decisões minhas (para o dono conferir)

Não foram ditas por ele; são o padrão que adotei:

- Subtítulo da loja "Campfires & Camps" e comando `/warmth`.
- Tag de rede `cf`, prefixo `ChehulCamp`, e todo o desenho da seção 5: só o anúncio do dono vai pelo realm e leva o
  resumo da roda; a presença vai só ao dono; os ritmos e o teto de 50 acampamentos.
- O pedido de convite passa por um aceitar/recusar do dono, que também pode desligar os pedidos.
- O anúncio não sobrevive a `/reload` ou relog: o dono anuncia de novo.
- A lista mostra todas as fogueiras da rede, sem filtro de nível; pinos também no mapa do continente.
- A arte é aprovada cedo, em duas ou três rodadas, antes das telas definitivas.
- Entrar na roda por distância (25 jardas) enquanto a medição dos benefícios não disser que dá para fazer melhor.
- O anúncio some 12 minutos depois de o dono se afastar, enquanto não se souber quando o fogo apaga.
- Idiomas: inglês e português do Brasil desde a primeira versão, como os outros addons publicados da família.
- Pino no minimapa entra na primeira versão (ficou fora do protótipo).
- No botão nativo: clique direito abre Montar acampamento, e a dica mostra o resumo da rede. Sem botão próprio
  no minimapa na primeira versão (o pino de fogueira no minimapa continua).
- Opções mínimas: desligar o aviso de proximidade, "menos animação", esconder pinos.
- Pessoas na roda com ícone de classe do jogo (seção 7).

## 10. Deixado ao construtor

- Estrutura de arquivos e módulos, e o quanto do protótipo se aproveita.
- Como desenhar pinos no minimapa e no mapa (biblioteca de pinos ou cálculo próprio).
- A técnica das texturas geradas (formato, resolução, quadros da chama).
- Como descobrir "o que dá para cozinhar agora".
- Empacotamento e publicação (CurseForge), seguindo os outros addons da família.

## 11. Em aberto, para o dono

Nada. As medições da seção 4 são a primeira tarefa da construção.
