extends Control

signal struck(zone: int)

enum Zone { CENTER, RIM }

const HEAD := Vector2(260, 250)
const HEAD_RADIUS := 222.0
const CENTER_RADIUS := 134.0
const TEAL := Color("#99f2d0")
const GOLD := Color("#ffd894")
const INK := Color("#241a18")

var _cue := -1
var _flash := -1
var _flash_time := 0.0


func _ready() -> void:
	set_process(false)


func show_cue(zone: int) -> void:
	_cue = zone
	queue_redraw()


func flash(zone: int) -> void:
	_flash = zone
	_flash_time = 0.24
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_flash_time -= delta
	if _flash_time <= 0.0:
		_flash = -1
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
	var distance := point.distance_to(HEAD)
	if distance <= HEAD_RADIUS:
		accept_event()
		struck.emit(Zone.CENTER if distance <= CENTER_RADIUS else Zone.RIM)


func _draw() -> void:
	# The wood and lacing sit behind the skin. Only the circular head receives hits.
	draw_circle(Vector2(260, 292), 246, Color("#18252c"), true, -1.0, true)
	draw_ellipse_band()
	draw_colored_polygon(PackedVector2Array([
		Vector2(65, 315), Vector2(455, 315), Vector2(381, 530), Vector2(139, 530),
	]), Color("#613f34"))
	for i in range(7):
		var top := Vector2(82.0 + 59.0 * i, 325.0)
		var foot := Vector2(145.0 + 38.0 * i, 529.0)
		draw_line(top, foot, Color("#98684f"), 3.0, true)
		if i < 6:
			draw_line(top + Vector2(47, 0), foot, Color("#d0a779"), 3.0, true)
	draw_line(Vector2(139, 530), Vector2(381, 530), Color("#2d2223"), 12.0, true)

	draw_circle(HEAD, HEAD_RADIUS + 8, Color("#33292a"), true, -1.0, true)
	draw_circle(HEAD, HEAD_RADIUS, _zone_color(Zone.RIM, Color("#cd9d68"), GOLD), true, -1.0, true)
	draw_circle(HEAD, CENTER_RADIUS, _zone_color(Zone.CENTER, Color("#f1d3a5"), TEAL), true, -1.0, true)
	draw_arc(HEAD, CENTER_RADIUS, 0, TAU, 100, Color("#614735"), 3.0, true)
	draw_arc(HEAD, HEAD_RADIUS - 3.0, 0, TAU, 120, Color("#80593f"), 2.0, true)

	for i in range(16):
		var pin := HEAD + Vector2.from_angle(TAU * i / 16.0) * (HEAD_RADIUS - 14.0)
		draw_circle(pin, 3.0, Color("#895f42"), true, -1.0, true)
	if _cue == Zone.CENTER:
		draw_arc(HEAD, CENTER_RADIUS - 10.0, 0, TAU, 100, INK, 4.0, true)
	elif _cue == Zone.RIM:
		draw_arc(HEAD, HEAD_RADIUS - 21.0, 0, TAU, 100, INK, 4.0, true)

	_draw_caption("GRAVE", 0.0, 41)
	_draw_caption("centro", 33.0, 23)
	_draw_caption("AGUDO", -166.0, 30)
	_draw_caption("borda", -143.0, 19)


func draw_ellipse_band() -> void:
	draw_set_transform(Vector2(260, 536), 0.0, Vector2(1.0, 0.13))
	draw_circle(Vector2.ZERO, 166, Color("#090e13"), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func _zone_color(zone: int, rest: Color, active: Color) -> Color:
	var color := active if _cue == zone else rest
	if _flash == zone:
		return color.lerp(Color.WHITE, clampf(_flash_time / 0.24, 0.0, 1.0) * 0.7)
	return color


func _draw_caption(caption: String, baseline: float, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, HEAD + Vector2(-width / 2.0, baseline), caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, INK)
