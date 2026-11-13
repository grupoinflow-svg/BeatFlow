# BeatFlow Demo para Android

O APK de depuração da versão 0.1.4-demo abre em paisagem como **BeatFlow Demo · Roda**.

## Roda de violão

Abra **RODA DE VIOLÃO** e experimente deslizar por duas ou mais cordas para cima ou para baixo. Cada corda soa na ordem em que o dedo passa por ela. A área inteira aceita o gesto. No computador, clique e arraste.

Toque em **INICIAR**. São três frases em 20 segundos, a 72 BPM. Em cada frase, a banda demonstra por quatro tempos. Nos quatro seguintes, repita a batida enquanto o baixo e a percussão seguem tocando. O indicador **OUÇA** ou **SUA VEZ** mostra quem está tocando. A banda toca uma virada curta quando você acerta todas as batidas da frase e mantém as pausas.

O acompanhamento e a virada foram sintetizados para esta demo. As quatro cordas usam as notas Sol, Si, Ré e Sol.

## Testar violão

No menu, toque em **TESTAR VIOLÃO**. Explore as cordas Sol, Si e Mi agudo, da corda solta à 3ª casa. Cada posição toca a altura correspondente à afinação padrão. O timbre de corda dedilhada e o pulso foram sintetizados para esta demo. A amostra de cada corda é transposta um semitom a cada casa.

Toque em **INICIAR** para tocar uma melodia de 24 notas a 90 BPM. Depois da contagem de quatro batidas, toque na posição iluminada quando o anel fechar. A rodada usa um pulso de referência e a melodia é produzida pelos toques. No fim, confira os acertos e a precisão ou toque em **REPETIR**.

## Demo anterior

Em **PLAY**, selecione **BeatFlow Demo** e escolha **Easy**, **Medium**, **Hard** ou **Expert**. Toque em **START** para começar.

As notas percorrem as cinco cordas da esquerda para a direita. Toque diretamente na corda quando a nota cruzar o marcador à direita. Para uma nota longa, mantenha o dedo na corda até a cauda alcançar o marcador. Para um acorde, toque nas cordas correspondentes com dedos diferentes. No teclado, use A, S, D, F e G de cima para baixo. **Retry** volta à tela de início da mesma faixa.

## Regras de julgamento

- Perfect até ±90 ms. Good até ±180 ms. A precisão dá peso de 100% a Perfect e 70% a Good.
- Um acorde vale um evento. Cada pista é julgada no instante do próprio toque. O resultado do acorde é Good se alguma pista tiver sido Good. Uma pista ausente ou uma sustentada solta cedo faz o acorde contar como um único Miss.
- A sustentada pode ser solta até 150 ms antes do fim. A precisão do acorde é registrada quando todas as sustentadas são concluídas.
- O placar dá pontos pelo início das sustentadas e um bônus pelo fim. Os contadores de precisão da tela de resultados são por evento.
- O HUD mostra o último desvio de um acerto. Valor negativo indica toque antecipado. Valor positivo indica toque atrasado.

## Exportação

No Godot 4.7.2 stable com os templates da mesma versão, configure o JDK e o Android SDK em **Editor Settings → Export → Android**. Em **Project → Export**, use o preset **Android Demo** e exporte com depuração. O APK inclui o áudio da Demo e os quatro charts correspondentes. Use a assinatura de depuração do seu ambiente para novos testes.

## Validação

| Verificação | Resultado |
|---|---|
| Godot 4.7.2 | Importação, navegação, início, pausa, retomada, pontuação e Retry verificados |
| Julgamento | Acordes mistos, sustentações, limites das janelas, notas no final e validação do chart verificados |
| Demo Easy | Partida completa e Retry verificados |
| APK | Assinatura, alinhamento e conteúdo conferidos com as ferramentas do SDK Android |
| Aparelho físico | Latência de áudio e resposta a múltiplos dedos pendentes |

No primeiro teste em celular, use a Demo Easy com o alto-falante do aparelho. Compare o sinal e a magnitude do desvio no começo e no fim da faixa. Pause, retome e repita. Use a Demo Medium ou Expert para testar acordes e sustentadas.
