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

## A medir antes de construir

A sonda (`/warmth probe`) já grava o que falta saber. Uma rodada abrindo uma profissão, um vendedor e um instrutor
responde:

| Pergunta | O que muda |
|---|---|
| O cliente diz as profissões e a perícia sem abrir a janela? | Se não, a Oficina pede para abrir cada profissão uma vez |
| Dá para saber que uma receita foi aprendida? (os ids de receita vieram de um guia só) | Se não, "falta a receita" e "falta material" viram um estado só |
| O cliente dá os materiais de uma receita? | Se sim, a tabela de materiais do guia vira só reserva |
| Como o cliente lista os itens de um vendedor e identifica o NPC? | Define o aprendizado pela rede |
| A missão "Camping 101" aparece como concluída? | Diz se a receita de nível 1 já foi pega |

## Fora desta versão

- Fabricar direto pela Oficina.
- Catálogo das profissões que o jogador não tem.
- Preços e leilão.
