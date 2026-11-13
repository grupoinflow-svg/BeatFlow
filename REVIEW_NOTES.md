# BeatFlow — Revisão técnica do Milestone 1

## Estado após revisão

O projeto continua adequado como prova de conceito do rhythm engine.

### Mantido
- 5 lanes.
- Chart JSON externo.
- Faixa de teste de 60 s / 120 BPM.
- Perfect ±60 ms.
- Good ±120 ms.
- Miss automático.
- Score, combo e max combo.
- Relógio de áudio baseado no playback/hardware clock.
- Proteção monotônica contra pequenos recuos no timestamp.
- Botões de gameplay e controles A/S/D/F/G.
- Restart e debug.

### Ajustado
- Versão-alvo: Godot 4.7.2 stable.
- `config/features` fixado em 4.7 / GL Compatibility.
- Landscape explicitado.
- Stretch aspect `expand` adicionado para telas mobile com proporções variadas.
- README atualizado.

### Ainda depende de teste real
- Parsing/execução dentro do editor Godot.
- Sensação de timing.
- Latência do dispositivo.
- Multitouch em aparelho real.
- Exportação Android.

Esses itens não devem ser considerados defeitos antes do primeiro teste no engine/dispositivo.
