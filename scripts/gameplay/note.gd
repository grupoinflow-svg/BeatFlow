class_name RhythmNote
extends Control

var target_time: float = 0.0
var lane: int = 0
var approach_time: float = 2.0
var lane_center: float = 0.0
var strike_x: float = 0.0
var note_radius: float = 16.0
var current_song_time: float = 0.0

var note_type: String = "tap"
var duration: float = 0.0
var end_time: float = 0.0
var state: String = "pending" # "pending", "holding", "completed", "missed"

var chord_id: int = -1       # -1 = nota solo; >= 0 = pertence a um grupo
var event_end_time: float = 0.0
var head_judgment: String = ""
var hold_released_in_window: bool = false

var note_color: Color = Color.WHITE

func setup(
	new_target_time: float,
	new_lane: int,
	new_approach_time: float,
	p_type: String,
	p_duration: float
) -> void:
	target_time = new_target_time
	lane = new_lane
	approach_time = maxf(new_approach_time, 0.25)
	note_type = p_type
	duration = p_duration
	end_time = target_time + duration
	note_color = HighwayVisual.NOTE_COLORS[lane]

func set_lane_geometry(center_y: float, receptor_x: float, radius: float) -> void:
	lane_center = center_y
	strike_x = receptor_x
	note_radius = radius
	size = Vector2.ONE * (note_radius * 4.0)

func update_visual(song_time: float) -> void:
	current_song_time = song_time
	var head_x := strike_x if state == "holding" else _note_x(target_time)
	position = Vector2(head_x, lane_center) - size * 0.5
	queue_redraw()

func _note_x(time: float) -> float:
	var progress := 1.0 - (time - current_song_time) / approach_time
	return lerpf(-note_radius, strike_x, maxf(0.0, progress))

func _draw() -> void:
	var center := size * 0.5
	if note_type == "hold":
		var tail_x := minf(_note_x(end_time), strike_x) - position.x
		var tail := Vector2(tail_x, center.y)
		var tail_color := Color(note_color, 0.85 if state == "holding" else 0.52)
		var width := note_radius * 0.7
		draw_line(center, tail, tail_color, width, true)
		draw_circle(tail, width * 0.5, tail_color, true)
	if state == "pending" or state == "holding":
		_draw_head(center)

func _draw_head(center: Vector2) -> void:
	var r: float = note_radius
	
	draw_set_transform(center, 0, Vector2.ONE)
	
	if state == "holding":
		draw_circle(Vector2.ZERO, r + 8.0, Color(note_color, 0.6)) # Glow maior quando pressionado
	else:
		draw_circle(Vector2.ZERO, r + 5.0, Color(note_color, 0.35))
		
	draw_circle(Vector2.ZERO, r, note_color.darkened(0.2))
	draw_circle(Vector2.ZERO, r * 0.6, note_color.lightened(0.3))
	draw_arc(Vector2.ZERO, r * 0.75, PI, PI * 1.5, 16, Color.WHITE, 2.5, true)
	draw_arc(Vector2.ZERO, r * 0.75, 0, PI * 0.4, 16, Color(1.0, 1.0, 1.0, 0.4), 1.5, true)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
