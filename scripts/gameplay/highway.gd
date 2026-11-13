class_name HighwayVisual
extends Control

const LANE_COUNT: int = 5
const PAD_GAP: float = 8.0
const PAD_HEIGHT: float = 84.0
const NOTE_COLORS: Array[Color] = [
	Color(0.2, 0.75, 0.65),
	Color(0.35, 0.6, 0.85),
	Color(0.85, 0.75, 0.3),
	Color(0.85, 0.45, 0.5),
	Color(0.6, 0.4, 0.75),
]

var hit_glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var lane_held: Array[bool] = [false, false, false, false, false]

func _process(delta: float) -> void:
	for lane in LANE_COUNT:
		if hit_glow[lane] > 0.0:
			hit_glow[lane] = maxf(0.0, hit_glow[lane] - delta * 4.0)
			queue_redraw()

func _draw() -> void:
	var lane_width := get_lane_width()
	var hit_y := get_hit_y()
	for lane in LANE_COUNT:
		var left := lane * lane_width
		var color := NOTE_COLORS[lane]
		var intensity := maxf(hit_glow[lane], 0.55 if lane_held[lane] else 0.0)
		draw_rect(Rect2(left, 0.0, lane_width, size.y), Color(color, 0.075 + intensity * 0.16))
		draw_line(Vector2(left, 0.0), Vector2(left, size.y), Color(color, 0.4), 2.0)
		var receptor := Vector2(get_lane_center(lane), hit_y)
		var half_width := (lane_width - PAD_GAP) * 0.5
		draw_line(receptor - Vector2(half_width, 0), receptor + Vector2(half_width, 0), Color(color, 0.8 + intensity * 0.2), 4.0, true)
		draw_arc(receptor, get_note_radius() + 3.0, 0.0, TAU, 32, Color(color, 0.65 + intensity * 0.35), 3.0, true)
	draw_line(Vector2(size.x, 0.0), size, Color(NOTE_COLORS[-1], 0.4), 2.0)

func get_lane_width() -> float:
	return size.x / LANE_COUNT

func get_lane_center(lane: int) -> float:
	return (lane + 0.5) * get_lane_width()

func get_note_radius() -> float:
	return clampf(get_lane_width() * 0.135, 15.0, 30.0)

func get_hit_y() -> float:
	return size.y - get_note_radius() - 6.0

func get_pad_rect(lane: int) -> Rect2:
	var lane_width := get_lane_width()
	return Rect2(lane * lane_width + PAD_GAP * 0.5, size.y + PAD_GAP, lane_width - PAD_GAP, PAD_HEIGHT)

func set_lane_held(lane: int, is_held: bool) -> void:
	lane_held[lane] = is_held
	queue_redraw()

func hit_receptor(lane: int) -> void:
	hit_glow[lane] = 1.0
	queue_redraw()
