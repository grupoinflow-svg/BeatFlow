class_name HighwayVisual
extends Control

const LANE_COUNT: int = 5
const STRIKE_POSITION: float = 0.82
const NOTE_COLORS: Array[Color] = [
	Color(0.2, 0.75, 0.65),
	Color(0.35, 0.6, 0.85),
	Color(0.85, 0.75, 0.3),
	Color(0.85, 0.45, 0.5),
	Color(0.6, 0.4, 0.75),
]

var hit_glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var lane_held: Array[bool] = [false, false, false, false, false]
var board_style := _make_board_style()

func _process(delta: float) -> void:
	for lane in LANE_COUNT:
		if hit_glow[lane] > 0.0:
			hit_glow[lane] = maxf(0.0, hit_glow[lane] - delta * 4.0)
			queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var strike_x := get_strike_x()
	var strike_area := _get_strike_area()
	draw_style_box(board_style, Rect2(Vector2.ZERO, size))
	draw_rect(strike_area, Color(0.75, 0.58, 0.33, 0.10))
	draw_line(Vector2(strike_x, 0.0), Vector2(strike_x, size.y), Color(0.88, 0.74, 0.49, 0.70), 3.0, true)

	for lane in LANE_COUNT:
		var center_y := get_lane_center(lane)
		var color := NOTE_COLORS[lane]
		var intensity := maxf(hit_glow[lane], 0.55 if lane_held[lane] else 0.0)
		var from := Vector2(0.0, center_y)
		var to := Vector2(size.x, center_y)
		draw_line(from + Vector2(0.0, 3.0), to + Vector2(0.0, 3.0), Color(0.0, 0.0, 0.0, 0.65), 6.0, true)
		if intensity > 0.0:
			draw_line(from, to, Color(color, intensity * 0.32), 13.0, true)
		draw_line(from, to, color.lightened(0.20 + intensity * 0.35), 3.0, true)
		var receptor := Vector2(strike_x, center_y)
		var radius := get_note_radius() + 4.0
		draw_arc(receptor, radius, 0.0, TAU, 32, Color(color, 0.72 + intensity * 0.28), 3.0, true)
		if hit_glow[lane] > 0.0:
			draw_arc(receptor, radius + 12.0 * (1.0 - hit_glow[lane]), 0.0, TAU, 32, Color(color, hit_glow[lane]), 2.0, true)

func _make_board_style() -> StyleBoxFlat:
	var board := StyleBoxFlat.new()
	board.bg_color = Color(0.075, 0.058, 0.053)
	board.border_color = Color(0.31, 0.24, 0.17)
	board.set_border_width_all(2)
	board.set_corner_radius_all(12)
	return board

func get_lane_center(lane: int) -> float:
	return (lane + 0.5) * (size.y / LANE_COUNT)

func get_note_radius() -> float:
	return clampf((size.y / LANE_COUNT) * 0.23, 15.0, 27.0)

func get_strike_x() -> float:
	return size.x * STRIKE_POSITION

func _get_strike_area() -> Rect2:
	var half_width := minf(size.x * 0.12, 132.0)
	return Rect2(get_strike_x() - half_width, 0.0, half_width * 2.0, size.y)

func lane_at_position(local_position: Vector2) -> int:
	if size.y <= 0.0 or not _get_strike_area().has_point(local_position):
		return -1
	var spacing := size.y / LANE_COUNT
	var lane := int(local_position.y / spacing)
	if lane >= LANE_COUNT or absf(local_position.y - get_lane_center(lane)) > spacing * 0.45:
		return -1
	return lane

func set_lane_held(lane: int, is_held: bool) -> void:
	lane_held[lane] = is_held
	queue_redraw()

func hit_receptor(lane: int) -> void:
	hit_glow[lane] = 1.0
	queue_redraw()
