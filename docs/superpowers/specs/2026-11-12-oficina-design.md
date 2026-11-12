# Oficina: desenho

Data: 2026-11-12. Estado: decidido com o dono em conversa; falta medir no jogo antes de construir. "Oficina" é o
nome de trabalho em português; na interface em inglês, "Workshop".

## Intenção

Responder, para quem quer contribuir com um acampamento: **o que eu consigo fazer, o que falta, e onde consigo.**
Hoje o Warmth mostra os objetos que já estão na bolsa; a Oficina mostra os que o jogador *poderia* ter.

## O que o dono decidiu

- **Cobre os 35 objetos de acampamento e os 3 kits de fogueira**, só das profissões que o jogador tem.
- **Vendedores pelos dois caminhos:** uma tabela inicial feita à mão (capitais e zonas iniciais) e a rede
  completando. Quando um jogador com o Warmth abre um vendedor que vende um material de acampamento, o addon anota
  o NPC e o lugar e compartilha na ChehulNet.
- **"Pronto para fazer" abre a profissão.** Um botão abre a janela da profissão; fabricar é por lá.
- **Liga com os acampamentos anunciados.** A tela de um acampamento diz o que falta ali e o que o jogador consegue
  trazer: "falta tenda e mana aqui; você consegue fazer a Sharpening Wheel, falta 1 Copper Bar".
- Entra como uma tela nova na janela e uma fatia na roda da bússola.

## Como aparece

Para cada profissão do jogador, os objetos dela (e os kits, na Culinária), cada um em um de quatro estados:

| Estado | O que a linha mostra |
|---|---|
| Pronto para fazer | quantos dá para fazer; botão que abre a profissão |
| Falta material | cada material com "tem / precisa" |
| Falta perícia | "Ferraria 140, você tem 95" |
| Falta a receita | de onde ela vem: instrutor, a missão "Camping 101" da profissão, ou o projeto que cai de um chefe |

Tocar num material que falta mostra a origem: vendedor, coleta (erva, minério, couro, pesca) ou outro ofício (fundir
a barra). Para os de vendedor, "Marcar no mapa" põe o marcador do jogo no vendedor conhecido mais próximo.

## Vendedores pela rede

Depois da revisão de 2026-11-12, três graus de confiança, porque uma mensagem na rede pode ser forjada e o remetente
de um item repassado é só alegado:

- **Tabela:** `Core/VendorData.lua`, gerada do QuestieDB.
- **Meu:** um vendedor que o jogador abriu. Vence a tabela, que pode estar errada. Se a tabela já diz o mesmo
  (o NPC, mais ou menos ali, vendendo aqueles itens), nada é guardado nem contado.
- **Ouvido:** o que alguém na rede contou. Nunca sobre um NPC que a tabela conhece, nunca por cima de um "meu",
  nunca conta como vendedor de confiança, só é usado para um item que nenhum vendedor de confiança vende (e a
  tela diz "outro jogador informa"), é descartado em zona inicial da outra facção, expira em duas semanas, tem
  teto próprio (100) e **nunca é repassado**.

**O que sai deste cliente:** nada ao abrir o vendedor (diria onde o jogador está naquele momento). Um vendedor
"meu" que a tabela não tem espera pelo menos dez minutos e sai na fofoca de meia em meia hora, uma vez, pela
guilda e pelo realm. A opção `shareVendors` (ligada por padrão) desliga isso.

## Medido no jogo (2026-11-12, build 1.60.1.70888)

| Pergunta | Resposta |
|---|---|
| O cliente diz as profissões e a perícia sem abrir a janela? | Sim: `GetProfessions` + `GetProfessionInfo` (nome, perícia, máximo, linha de perícia) |
| Dá para saber que uma receita foi aprendida? | Sim: `IsPlayerSpell(receita)`. Os 35 ids de receita do guia conferem com os nomes do cliente |
| O cliente dá os materiais de uma receita? | Sim: `C_TradeSkillUI.GetRecipeSchematic(receita)`, com id e quantidade de cada material |
| Como o cliente lista um vendedor? | `UnitGUID("npc")` traz o id do NPC; `GetMerchantNumItems` + `GetMerchantItemID` listam os itens |
| Na janela de profissão | No `TRADE_SKILL_SHOW` a lista de receitas ainda é a da janela anterior: quem precisar dela lê no `TRADE_SKILL_LIST_UPDATE`. A Oficina não depende disso |

Vendedor medido: Xen'to (NPC 3400, Orgrimmar 57.5, 53.1) vende Simple Wood, Star Wood, Thick Logs, Flint and Tinder,
Refreshing Spring Water, Soothing Spices e Simple Flour.

**A tabela inicial vem do QuestieDB do Forever** (pedido do dono, 2026-11-12): `tools/gen-questie.py` lê o banco
com o decodificador do Lodestar e escreve `Core/VendorData.lua`, com 444 vendedores de 24 materiais, a facção de
cada um e a posição. Confere com a medição: o banco põe o Xen'to em Orgrimmar 57.6, 52.9 com os mesmos sete itens.
O que o jogador abre no jogo e o que a rede ensina ficam por cima da tabela. O QuestieDB é GPL-3.0; o arquivo
gerado leva esse aviso e essa licença, e o resto do Warmth continua MIT.

Ainda não medido: se `GetRecipeSchematic` responde antes de qualquer janela de profissão ter sido aberta na sessão
(se não responder, a linha pede "abra a profissão uma vez"); os instrutores (a sonda não conseguiu listar o que
ensinam); os kits de fogueira ficaram na tela "Set up a camp", não na Oficina.

## Como conseguir o que ninguém vende (pedido do dono, 2026-11-12)

Para cada material que falta, uma frase com o caminho mais fácil, nesta ordem:

1. **Vendedor**, se pelo menos cinco vendem (menos que isso é estoque limitado em algum canto do mundo).
2. **Como se faz ou se ganha**, quando se sabe: uma barra do minério, um rolo do tecido, uma atadura, uma peça de
   engenharia; couro esfolado, tecido de humanoides, material de desencantar, peixe. Para o que é fabricado, a
   linha seguinte explica o ingrediente (o minério da barra).
3. **Onde há mais nós**, para erva, minério e pedra: as duas zonas com mais, do `Core/SourceData.lua`.
4. **Quem solta**, para o resto: a criatura mais comum, o nível e a zona.
5. Se nada disso existe, "ainda não se sabe de onde vem" (as sete peças novas do Forever, como Golem Heart).

Nunca manda para a zona inicial ou a capital da outra facção. Um botão abre o mapa da zona indicada, ou marca o
vendedor.

De onde vem cada coisa: zonas e criaturas saem do QuestieDB (`tools/gen-questie.py`, 40 materiais). As receitas um
passo atrás e as faixas de nível são conhecimento geral do jogo clássico, escritas à mão em `Core/Sources.lua` e
**não medidas no Forever**; por isso o texto diz "por volta do nível".

## Fora desta versão

- Fabricar direto pela Oficina.
- Catálogo das profissões que o jogador não tem.
- Preços e leilão.
