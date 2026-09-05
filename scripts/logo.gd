extends Node2D

# The STARBYTE wordmark, drawn as a blocky pixel grid so it stays crisp at any
# resolution. Letters cycle hue along the word and the whole sign flickers like
# a tired arcade marquee.

const CELL := 10.0
const WORD := "STARBYTE"
const GLYPHS := {
	"S": [".#####.", "##...##", "##.....", "###....", ".#####.", "....###", ".....##", "##...##", ".#####."],
	"T": ["#######", "#######", "...#...", "...#...", "...#...", "...#...", "...#...", "...#...", "...#..."],
	"A": ["..###..", ".##.##.", "##...##", "##...##", "#######", "#######", "##...##", "##...##", "##...##"],
	"R": ["######.", "##...##", "##...##", "######.", "#####..", "##.##..", "##..##.", "##...##", "##...##"],
	"B": ["######.", "##...##", "##...##", "######.", "######.", "##...##", "##...##", "##...##", "######."],
	"Y": ["##...##", "##...##", ".##.##.", "..###..", "...#...", "...#...", "...#...", "...#...", "...#..."],
	"E": ["#######", "##.....", "##.....", "######.", "######.", "##.....", "##.....", "##.....", "#######"],
}

var _t := 0.0
var _stars: Array[Vector3] = []


func _ready() -> void:
	var span := WORD.length() * 8 - 1
	for i in 22:
		_stars.append(Vector3(randf_range(-40.0, span * CELL + 40.0),
			randf_range(-46.0, 9 * CELL + 40.0), randf() * TAU))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for s in _stars:
		var twinkle := 0.3 + 0.7 * absf(sin(_t * 2.1 + s.z))
		draw_rect(Rect2(s.x, s.y, 4.0, 4.0), Color(0.8, 0.9, 1.0, twinkle * 0.8))

	# A brief dip every few seconds reads as a failing neon tube.
	var flicker := 1.0
	if fposmod(_t, 4.3) < 0.06:
		flicker = 0.45

	for i in WORD.length():
		var rows: Array = GLYPHS[WORD[i]]
		var ox := i * 8 * CELL
		var tint := Color.from_hsv(fposmod(_t * 0.22 + i * 0.085, 1.0), 0.68, 1.0)
		tint.a = flicker
		for y in rows.size():
			var line: String = rows[y]
			for x in line.length():
				if line[x] != "#":
					continue
				var at := Vector2(ox + x * CELL, y * CELL)
				draw_rect(Rect2(at + Vector2(0.0, CELL), Vector2(CELL, CELL)),
					Color(0.10, 0.02, 0.24, 0.75 * flicker))
				draw_rect(Rect2(at, Vector2(CELL, CELL)), tint)
				if y == 0 or (y > 0 and rows[y - 1][x] != "#"):
					draw_rect(Rect2(at, Vector2(CELL, CELL * 0.34)),
						Color(1.0, 1.0, 1.0, 0.85 * flicker))
