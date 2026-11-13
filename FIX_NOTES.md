# BeatFlow — correção 0.0.1b

Correção motivada pelo primeiro teste real no Godot 4.7.2, que exibiu Parse error em `gameplay.gd`.

## Mudanças de robustez

- Removida a lambda inline usada para conectar os cinco botões.
- Conexão agora usa `Callable.bind()`, padrão documentado pela Godot.
- Removida dependência de tipos globais customizados (`RhythmNote`) dentro de `gameplay.gd`.
- Managers agora são carregados por `preload`.
- `sort_custom` não usa mais lambda inline.
- `_recalculate_layout()` foi simplificada e não contém `await`.
- Variável local `position` foi renomeada para `playback_time`.
- Mantida a mesma lógica de gameplay, timing, chart, score e combo.

## Próximo teste

Abra este pacote no Godot 4.7.2 e pressione Play.

Se ainda aparecer Parse error, abra a aba **Erros** no painel inferior e envie uma captura mostrando a mensagem completa com arquivo e linha.
