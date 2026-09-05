# Music

Drop original tracks here with these exact filenames and `Music.play("...")`
calls already wired into the game will pick them up automatically — no code
changes needed:

| File | Used for |
|---|---|
| `menu.ogg` | Title / attract screen |
| `gameplay.ogg` | Normal combat waves |
| `challenge.ogg` | Challenge stages |
| `boss.ogg` | Boss fights |
| `game_over.ogg` | Game over screen |
| `high_score.ogg` | Initials-entry screen |

`.ogg` is recommended (small, loops cleanly), but any format Godot can import
works. Until a file exists, `Music.play()` for that track is a silent no-op —
nothing breaks, no console errors.
