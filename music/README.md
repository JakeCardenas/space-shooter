# Music

Drop original tracks here named after the game state they belong to. They are
picked up automatically — no code changes needed.

| File | Used for |
|---|---|
| `menu` | Title / attract screen |
| `gameplay` | Normal combat waves |
| `challenge` | Challenge stages |
| `boss` | Boss fights |
| `game_over` | Game over screen |
| `high_score` | Initials-entry screen |

`.ogg`, `.mp3` and `.wav` all work — `Music.track_path()` tries them in that
order, so `menu.ogg` wins over `menu.mp3` if both exist. `.ogg` is the best
choice for size.

You do not need all six. Asking for a track with no file leaves whatever is
already playing alone, so a single `menu` track plays continuously through the
whole game rather than cutting to silence the moment a wave starts. Each file
you add simply takes over its own state.

## Credit

`menu.mp3` is *Press Start (NES 8-bit Remix)* by **MDK**. MDK's tracks are
free to use in projects **provided you credit him and link his channel** —
see <https://www.mdkofficial.com>. If STARBYTE stays public, keep that credit
somewhere visible.
