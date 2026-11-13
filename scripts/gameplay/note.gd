class_name RhythmNote
extends Control

var target_time: float = 0.0
var lane: int = 0
var approach_time: float = 2.0
var spawn_y: float = -30.0    # Atua como Spawn X agora
var hit_line_y: float = 500.0 # Atua como Hit X agora

var top_cx: float = 0.0       # Atua como Esquerda Y agora
var bottom_cx: float = 0.0    # Atua como Direita Y agora
var note_radius: float = 16.0
var current_scale: float = 0.35
var current_song_time: float = 0.0

var note_type: String = "tap"
var duration: float = 0.0
var end_time: float = 0.0
var state: String = "pending" # "pending", "holding", "completed", "missed"

var chord_id: int = -1       # -1 = nota solo; >= 0 = pertence a um grupo
var event_end_time: float = 0.0
var head_judgment: String = ""
var hold_released_in_window: bool = false

const NOTE_COLORS: Array[Color] = [
	Color(0.2, 0.75, 0.65), # Teal
	Color(0.35, 0.6, 0.85), # Blue
	Color(0.85, 0.75, 0.3), # Gold
	Color(0.85, 0.45, 0.5), # Rose
	Color(0.6, 0.4, 0.75)   # Lavender
]

var note_color: Color = Color.WHITE

func setup(
	new_target_time: float,
	new_lane: int,
	new_approach_time: float,
	new_spawn_y: float, # É o X
	new_hit_line_y: float, # É o X
	lane_width: float,
	p_top_cx: float, # É o Y
	p_bottom_cx: float, # É o Y
	p_type: String = "tap",
	p_duration: float = 0.0
) -> void:
	target_time = new_target_time
	lane = new_lane
	approach_time = maxf(new_approach_time, 0.25)
	
	spawn_y = new_spawn_y
	hit_line_y = new_hit_line_y
	top_cx = p_top_cx
	bottom_cx = p_bottom_cx
	
	note_type = p_type
	duration = p_duration
	end_time = target_time + duration
	state = "pending"
	
	note_radius = maxf(10.0, lane_width * 0.22)
	note_color = NOTE_COLORS[lane]
	
	var draw_size: float = note_radius * 4.0
	custom_minimum_size = Vector2(draw_size, draw_size)
	size = custom_minimum_size
	
	position = Vector2(spawn_y - size.x * 0.5, top_cx - size.y * 0.5)

func update_visual(song_time: float) -> void:
	current_song_time = song_time
	var time_until_hit: float = target_time - song_time
	var head_progress: float = 1.0 - (time_until_hit / approach_time)
	
	if state == "holding":
		head_progress = 1.0 # Trava a cabeça na Performance Line (Hit Zone)
		
	var p: float = clampf(head_progress, 0.0, 1.0)
	current_scale = lerpf(0.35, 1.0, p)
	
	var center_x: float
	if head_progress <= 1.0:
		center_x = lerpf(spawn_y, hit_line_y, p)
	else:
		center_x = hit_line_y + minf((head_progress - 1.0) * 800.0, 50.0)
		current_scale = 1.0
		
	var center_y: float
	if head_progress <= 1.0:
		center_y = lerpf(top_cx, bottom_cx, p)
	else:
		center_y = bottom_cx
		
	position.x = center_x - size.x * 0.5
	position.y = center_y - size.y * 0.5
	queue_redraw()

func _draw() -> void:
	var head_center: Vector2 = size * 0.5
	
	if note_type == "hold":
		_draw_tail(head_center)
	
	if state == "pending" or state == "holding":
		_draw_head(head_center)

func _draw_tail(head_center: Vector2) -> void:
	var time_until_tail: float = end_time - current_song_time
	var tail_progress: float = 1.0 - (time_until_tail / approach_time)
	
	var tail_p: float = clampf(tail_progress, 0.0, 1.0)
	
	var global_tail_x: float = lerpf(spawn_y, hit_line_y, tail_p)
	var global_tail_y: float = lerpf(top_cx, bottom_cx, tail_p)
	
	var global_center: Vector2 = position + head_center
	var global_tail_pos: Vector2 = Vector2(global_tail_x, global_tail_y)
	
	var local_tail_pos: Vector2 = global_tail_pos - global_center + head_center
	
	var tail_c: Color = note_color
	tail_c.a = 0.85 if state == "holding" else 0.45
	
	# Usa o _draw line continuo. Em 3D a espessura no final pode ser menor (perspectiva), mas por ser simples usaremos escala linear.
	var tail_thickness: float = note_radius * 0.6
	draw_line(head_center, local_tail_pos, tail_c, tail_thickness, true)
	draw_circle(local_tail_pos, tail_thickness * 0.5, tail_c)

func _draw_head(center: Vector2) -> void:
	var r: float = note_radius * current_scale
	
	draw_set_transform(center, 0, Vector2(0.9, 1.1))
	
	if state == "holding":
		draw_circle(Vector2.ZERO, r + 8.0, Color(note_color, 0.6)) # Glow maior quando pressionado
	else:
		draw_circle(Vector2.ZERO, r + 5.0, Color(note_color, 0.35))
		
	draw_circle(Vector2.ZERO, r, note_color.darkened(0.2))
	draw_circle(Vector2.ZERO, r * 0.6, note_color.lightened(0.3))
	draw_arc(Vector2.ZERO, r * 0.75, PI, PI * 1.5, 16, Color.WHITE, 2.5 * current_scale, true)
	draw_arc(Vector2.ZERO, r * 0.75, 0, PI * 0.4, 16, Color(1.0, 1.0, 1.0, 0.4), 1.5 * current_scale, true)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
