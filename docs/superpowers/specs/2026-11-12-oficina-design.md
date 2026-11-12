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

- **O que se aprende:** id do NPC, mapa, posição, e quais materiais de acampamento ele vende. Nada do jogador.
- **Quando:** ao abrir um vendedor (`MERCHANT_SHOW`), se ele vende algum material da lista.
- **Como viaja:** um item de taxa baixa no barramento do realm, com chave por NPC, só quando o vendedor é novo para
  este cliente. A rede não precisa de mais de um aviso por vendedor.
- **Confiança:** um vendedor falso só produz um marcador no lugar errado. Limites: por mapa e no total; posição
  dentro do mapa; id de item da lista. Um vendedor que o próprio jogador abriu vale mais que um ouvido.
- **Fica guardado** entre sessões (os vendedores não mudam de lugar).

A lista de materiais de vendedor ainda precisa ser levantada (madeira, frascos, linhas, especiarias, água, farinha);
o resto é coleta ou fabricação.

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

**A tabela inicial vem do QuestieDB do Forever** (pedido do dono, 2026-11-12): `tools/gen-vendors.py` lê o banco
com o decodificador do Lodestar e escreve `Core/VendorData.lua`, com 413 vendedores de 23 materiais, a facção de
cada um e a posição. Confere com a medição: o banco põe o Xen'to em Orgrimmar 57.6, 52.9 com os mesmos sete itens.
O que o jogador abre no jogo e o que a rede ensina ficam por cima da tabela. O QuestieDB é GPL-3.0; o arquivo
gerado leva esse aviso e essa licença, e o resto do Warmth continua MIT.

Ainda não medido: se `GetRecipeSchematic` responde antes de qualquer janela de profissão ter sido aberta na sessão
(se não responder, a linha pede "abra a profissão uma vez"); os instrutores (a sonda não conseguiu listar o que
ensinam); os kits de fogueira ficaram na tela "Set up a camp", não na Oficina.

## Fora desta versão

- Fabricar direto pela Oficina.
- Catálogo das profissões que o jogador não tem.
- Preços e leilão.
