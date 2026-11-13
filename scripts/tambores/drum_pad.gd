extends Control

signal struck

const HEAD := Vector2(166, 146)
const HEAD_RADIUS := 111.0
const HIT_RING := 105.0
const LEAD_SPAN := 53.0
const INK := Color("#211a20")
const SKIN := Color("#e7caa4")

@export var drum_name := "Grave"
@export var key_hint := "A"
@export var accent := Color("#8ce5ce")

var _approach: PackedFloat32Array
var _flash := 0.0


func _ready() -> void:
	set_process(false)


func show_notes(approach: PackedFloat32Array) -> void:
	if _approach != approach:
		_approach = approach
		queue_redraw()


func flash() -> void:
	_flash = 0.18
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _flash == 0.0:
		set_process(false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch and event.pressed:
		_strike_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_strike_at(event.position)


func _strike_at(point: Vector2) -> void:
	if point.distance_squared_to(HEAD) <= HEAD_RADIUS * HEAD_RADIUS:
		accept_event()
		struck.emit()


func _draw() -> void:
	draw_set_transform(Vector2(166, 305), 0.0, Vector2(1.0, 0.16))
	draw_circle(Vector2.ZERO, 87.0, Color("#0a1018"), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([
		Vector2(65, 166), Vector2(267, 166), Vector2(231, 297), Vector2(101, 297),
	]), Color("#715047"))
	for index in range(5):
		var top := Vector2(73 + 46 * index, 188)
		var foot := Vector2(103 + 31 * index, 296)
		draw_line(top, foot, Color("#a2775d"), 3.0, true)
		draw_line(top + Vector2(30, 0), foot, Color("#cfa981"), 2.0, true)
	draw_line(Vector2(100, 296), Vector2(232, 296), Color("#3e2b2c"), 9.0, true)

	var skin := SKIN.lerp(accent.lightened(0.3), _flash / 0.18)
	draw_circle(HEAD, HEAD_RADIUS + 4.0, Color("#302831"), true, -1.0, true)
	draw_circle(HEAD, HEAD_RADIUS, skin, true, -1.0, true)
	draw_arc(HEAD, HIT_RING, 0, TAU, 96, Color("#6e5145"), 3.0, true)
	for index in range(8):
		var peg := HEAD + Vector2.from_angle(TAU * (index + 0.5) / 8.0) * 95.0
		draw_circle(peg, 3.0, Color("#9c785e"), true, -1.0, true)
	for index in range(_approach.size() - 1, -1, -1):
		var remaining := _approach[index]
		var radius := HIT_RING + maxf(0.0, remaining) * LEAD_SPAN
		var cue_color := accent if index == 0 else Color(accent, 0.40)
		draw_arc(HEAD, radius, 0, TAU, 96, Color("#172130"), 10.0 if index == 0 else 5.0, true)
		draw_arc(HEAD, radius, 0, TAU, 96, cue_color, 6.0 if index == 0 else 3.0, true)

	_caption(drum_name, 8, 38)
	if not OS.has_feature("mobile"):
		_caption(key_hint, 43, 21)


func _caption(value: String, baseline: int, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, HEAD + Vector2(-width / 2.0, baseline), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, INK)
