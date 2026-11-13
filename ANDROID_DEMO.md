# BeatFlow Demo para Android

O APK de depuração da versão 0.1.0-demo abre em paisagem. Em **Play**, selecione **BeatFlow Demo** e escolha **Easy**, **Medium**, **Hard** ou **Expert**. Toque em **START** para começar. Use as cinco pistas na tela ou A, S, D, F e G em um teclado. **Retry** volta à tela de início da mesma faixa.

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
