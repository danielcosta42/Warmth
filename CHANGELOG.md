# Changelog

Todas as mudanças relevantes do Warmth. Formato baseado em
[Keep a Changelog](https://keepachangelog.com/), versionamento [SemVer](https://semver.org/).

## [Unreleased]

- **Fogueira avistada.** Quem tem o Warmth e para ao lado de uma fogueira que a rede não conhece (acesa por quem
  não tem o addon) a anuncia sozinho, marcada como "vista por". Apontar o mouse para o fogo diz o nível. O anúncio
  do próprio dono, se chegar, toma o lugar. Vale a mesma opção do anúncio automático.

## [0.3.0]

- **Os tempos na bússola.** Um aro de pontos enche durante o minuto sentado, com os segundos que faltam; depois,
  quanto resta do benefício.
- **Benefícios para você.** A tela do acampamento marca o benefício que você não ganharia, porque já tem o de
  classe equivalente.
- **Pedido de objeto.** O acampamento diz à rede o que ainda falta (a tenda primeiro); quem está por perto e tem
  o objeto na bolsa, ou sabe fabricar, recebe um aviso. O dono pode desligar.
- **Calor do anfitrião.** Quem senta no seu fogo pode agradecer com um clique, uma vez por dia; os agradecimentos
  viram calor e o anfitrião sobe de nível (Graveto, Brasa, Lareira, Fogueira, Farol), que aparece no acampamento.
- **Livro de visitas.** Os acampamentos em que você sentou, e o seu calor como anfitrião.
- **Peças de quem não tem o addon.** Estando no acampamento, aponte o mouse para a tenda, a cadeira ou outra peça
  e o Warmth anota; o seu acampamento deixa de pedir o que já está lá.
- O Warmth responde ao diagnóstico do operador da rede (contagens e opções, nada sobre onde você está).

## [0.2.0]

- **Oficina.** Uma tela nova (e uma fatia na roda da bússola) mostra os objetos de acampamento que as suas
  profissões fazem: pronto para fazer, falta material, falta perícia ou falta a receita, com o que cada um leva.
  Um botão abre a profissão, marca no mapa o vendedor do material que falta ou abre o mapa da zona onde ele se
  consegue.
- **Vendedores.** 444 vendedores de 24 materiais já vêm no addon (do banco do Questie do Forever), só os da sua
  facção, com o mais perto no seu continente.
- **Como conseguir cada material.** Para o que ninguém vende, a Oficina diz o caminho: as zonas com mais nós de
  uma erva ou de um minério, a criatura que solta (com nível e zona), do que uma barra ou um rolo é feito, e as
  faixas de nível de couro, tecido e material de encantamento. Nunca manda para a zona inicial da outra facção.
- **A rede completa a tabela, com cuidado.** Um vendedor que você abre e a tabela não conhece é contado à rede
  mais tarde (nunca na hora, para não dizer onde você está), e dá para desligar nas opções. O que a rede conta
  nunca corrige a tabela nem o que você mesmo viu, vale só para o que nenhum vendedor conhecido vende, e expira.
- A tela de um acampamento diz o que você conseguiria fabricar para ele.
- A sonda `/warmth probe` grava profissões, receitas, vendedores e instrutores.

## [0.1.0]

Primeira versão, para o **WoW: Forever** (interface 16001).

- **Fogueiras no mapa.** Um pino para cada fogueira que um jogador escolheu anunciar, no mapa da zona, no do
  continente e no minimapa; o brilho cresce com a gente em volta do fogo.
- **A roda.** O fogo no centro, os lugares dos objetos de acampamento em volta dele e as pessoas por fora, cada
  uma chegando; o nível da fogueira, o que cada objeto dá, os lugares livres e o recado do dono.
- **Lista das fogueiras acesas**, da mais perto à mais longe, com filtros: com tenda, com conserto, com lugar
  livre.
- **Ir até lá** põe o marcador do jogo na fogueira.
- **Montar acampamento.** Checklist dos kits e da madeira, dos objetos das suas profissões e do que dá para
  cozinhar agora, e o recado do acampamento.
- **Você decide se aparece.** O addon pergunta uma vez se você quer aparecer nas rodas dos outros; sem o sim,
  nada sobre você é enviado.
- **Cópias da zona.** Os acampamentos de outra cópia vêm marcados, e dá para pedir ao dono um convite de grupo
  para cair na dele.
- **Aviso de proximidade** quando anunciam uma fogueira na zona em que você está.
- **Acender pelo addon.** Com o kit na bolsa, um clique em Montar acampamento usa o kit (fora de combate).
- **Fogo de verdade.** O addon confere pelo próprio jogo que há uma fogueira acesa: só anuncia com fogo, só
  põe você na roda com fogo presente, e encerra o anúncio sozinho quando o seu fogo apaga.
- **Chamas violetas.** Uma fogueira com Pó Violeta (o brinquedo da celebração de lançamento) aparece violeta no
  mapa, na lista e na roda, com o aviso de que ali os benefícios duram duas horas.
- **Bússola e roda de ações.** Uma fogueirinha na tela aponta para a fogueira mais útil por perto; um clique abre
  uma roda com acender, os seus objetos de acampamento, o saco de dormir, sentar, cozinhar e o Pó Violeta.
- **Anúncio automático.** Acender uma fogueira avisa a rede; dá para desligar nas opções.
- **Botão nativo** no compartimento de addons do jogo, opções na aba AddOns e `/warmth`.
- `/warmth probe` grava o que o cliente revela sobre acampamentos, para conferir no jogo o que hoje vem de guias.
- Em inglês e em português do Brasil.

Roda na ChehulNet (lib v1.4.0), em que GuildOS, Lodestar e PartyLens repassam os anúncios de fogueira: o alcance
cresce conforme os jogadores atualizam esses addons.
