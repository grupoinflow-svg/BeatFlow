class_name GuitarFretboard
extends Control

signal string_plucked(string_index: int, fret: int)

const STRING_NAMES := ["SOL", "SI", "MI"]
const NOTE_NAMES := [
	["Sol", "Sol♯", "Lá", "Si♭"],
	["Si", "Dó", "Dó♯", "Ré"],
	["Mi", "Fá", "Fá♯", "Sol"],
]
const FRET_NAMES := ["SOLTA", "1ª CASA", "2ª CASA", "3ª CASA"]
const STRING_COUNT := 3
const FRET_COUNT := 4
const CUE_LEAD := 0.95
const FLASH_DURATION := 0.22

var round_time := 0.0
var next_note: Vector2i = Vector2i(-1, -1)
var next_note_time := 0.0
var feedback_position: Vector2i = Vector2i(-1, -1)
var feedback_color: Color = Color.WHITE
var feedback_remaining := 0.0

var board_style := _make_board_style()

func _ready() -> void:
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if feedback_remaining > 0.0:
		feedback_remaining = maxf(0.0, feedback_remaining - delta)
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	var pointer_position: Vector2
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		pointer_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer_position = event.position
	else:
		return

	var spot := position_at(make_canvas_position_local(pointer_position))
	if spot.x >= 0:
		get_viewport().set_input_as_handled()
		string_plucked.emit(spot.x, spot.y)

func update_cue(song_time: float, spot: Vector2i = Vector2i(-1, -1), note_time: float = 0.0) -> void:
	round_time = song_time
	next_note = spot
	next_note_time = note_time
	queue_redraw()

func flash(spot: Vector2i, color: Color) -> void:
	feedback_position = spot
	feedback_color = color
	feedback_remaining = FLASH_DURATION
	queue_redraw()

func _board_rect() -> Rect2:
	return Rect2(108.0, 58.0, maxf(0.0, size.x - 126.0), maxf(0.0, size.y - 74.0))

func position_at(local_position: Vector2) -> Vector2i:
	var board := _board_rect()
	if not board.has_point(local_position):
		return Vector2i(-1, -1)
	var fraction := (local_position - board.position) / board.size
	return Vector2i(int(fraction.y * STRING_COUNT), int(fraction.x * FRET_COUNT))

func spot_center(string_index: int, fret: int) -> Vector2:
	var board := _board_rect()
	return board.position + board.size * Vector2((fret + 0.5) / FRET_COUNT, (string_index + 0.5) / STRING_COUNT)

func _draw() -> void:
	var board := _board_rect()
	if not board.has_area():
		return

	var font := get_theme_default_font()
	var column_width := board.size.x / FRET_COUNT
	var row_height := board.size.y / STRING_COUNT
	draw_style_box(board_style, board)
	for fret in FRET_COUNT:
		var left := board.position.x + column_width * fret
		_draw_centered(font, FRET_NAMES[fret], Vector2(left + column_width * 0.5, 30.0), 19, Color("#e7c799"))
		if fret > 0:
			var edge := Vector2(left, board.position.y)
			draw_line(edge, edge + Vector2(0.0, board.size.y), Color("#96765b"), 5.0 if fret == 1 else 3.0, true)
	for string_index in STRING_COUNT:
		var y := spot_center(string_index, 0).y
		var from := Vector2(board.position.x, y)
		var to := Vector2(board.end.x, y)
		_draw_centered(font, STRING_NAMES[string_index], Vector2(53.0, y), 24, Color("#f0dbba"))
		draw_line(from + Vector2.DOWN * 3.0, to + Vector2.DOWN * 3.0, Color("#211914"), 7.0, true)
		draw_line(from, to, Color("#cfac77"), 3.7 - 0.65 * string_index, true)
		for fret in FRET_COUNT:
			var center := spot_center(string_index, fret)
			var radius := minf(column_width, row_height) * 0.25
			var spot := Vector2i(string_index, fret)
			var cue := spot == next_note and next_note_time - round_time <= CUE_LEAD
			var flash_opacity := feedback_remaining / FLASH_DURATION if spot == feedback_position else 0.0
			_draw_spot(font, center, radius, spot, cue, flash_opacity)

func _draw_spot(font: Font, center: Vector2, radius: float, spot: Vector2i, cue: bool, flash_opacity: float) -> void:
	var gold := Color("#ffd38e")
	if cue:
		var countdown := clampf((next_note_time - round_time) / CUE_LEAD, 0.0, 1.0)
		draw_circle(center, radius * (1.0 + countdown * 0.72), Color(gold, 0.18), true)
		draw_arc(center, radius * (1.0 + countdown * 0.72), 0.0, TAU, 48, gold, 3.0, true)
	if flash_opacity > 0.0:
		draw_circle(center, radius * (1.22 + (1.0 - flash_opacity) * 0.22), Color(feedback_color, flash_opacity * 0.34), true)
		draw_arc(center, radius * 1.22, 0.0, TAU, 32, Color(feedback_color, flash_opacity), 4.0, true)
	draw_circle(center, radius, Color("#9e602d") if cue else Color("#433126"), true)
	draw_arc(center, radius, 0.0, TAU, 40, gold if cue else Color("#a08362"), 2.0, true)
	_draw_centered(font, NOTE_NAMES[spot.x][spot.y], center, int(clampf(radius * 0.72, 17.0, 26.0)), Color("#fff1d8"))

func _draw_centered(font: Font, label: String, center: Vector2, font_size: int, color: Color) -> void:
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, center + Vector2(-width * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _make_board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#36271f")
	style.border_color = Color("#684a36")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style
