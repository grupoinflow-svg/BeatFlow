class_name BeatFlowStrumSurface
extends Control

signal string_crossed(index: int)
signal strum_completed

const STRING_COUNT := 4
const STRING_THICKNESS := [5.0, 4.0, 3.0, 2.5]
const FLASH_DURATION := 0.22
const REVERSAL_DISTANCE := 14.0
const NO_POINTER := -2
const MOUSE_POINTER := -1

var pointer := NO_POINTER
var last_position := Vector2.ZERO
var direction := 0.0
var crossed_strings: Array[int] = []
var flashes := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var wood := _wood_style()

func _ready() -> void:
	resized.connect(queue_redraw)
	get_window().focus_exited.connect(reset_gesture)

func _process(delta: float) -> void:
	for index in STRING_COUNT:
		if flashes[index] > 0.0:
			flashes[index] = maxf(0.0, flashes[index] - delta)
			queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_begin_gesture(event.index, event.position)
		elif pointer == event.index:
			reset_gesture()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == pointer:
		_drag_to(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_gesture(MOUSE_POINTER, event.position)
		elif pointer == MOUSE_POINTER:
			reset_gesture()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer == MOUSE_POINTER:
		_drag_to(event.position)

func reset_gesture() -> void:
	pointer = NO_POINTER
	direction = 0.0
	crossed_strings.clear()

func reset_feedback() -> void:
	flashes.fill(0.0)
	queue_redraw()

func string_y(index: int) -> float:
	return size.y * (index + 1) / (STRING_COUNT + 1)

func flash_string(index: int) -> void:
	flashes[index] = FLASH_DURATION
	queue_redraw()

func _begin_gesture(id: int, viewport_position: Vector2) -> void:
	var local := make_canvas_position_local(viewport_position)
	if pointer != NO_POINTER or not Rect2(Vector2.ZERO, size).has_point(local):
		return
	pointer = id
	last_position = local
	crossed_strings.clear()
	get_viewport().set_input_as_handled()

func _drag_to(viewport_position: Vector2) -> void:
	var current := make_canvas_position_local(viewport_position)
	var dy := current.y - last_position.y
	get_viewport().set_input_as_handled()
	if is_zero_approx(dy):
		last_position.x = current.x
		return
	if direction != 0.0 and signf(dy) != direction:
		if absf(dy) < REVERSAL_DISTANCE:
			return
		crossed_strings.clear()
	direction = signf(dy)
	for step in STRING_COUNT:
		var index := step if direction > 0.0 else STRING_COUNT - 1 - step
		var fraction := (string_y(index) - last_position.y) / dy
		if fraction <= 0.0 or fraction > 1.0 or index in crossed_strings:
			continue
		var crossing_x := lerpf(last_position.x, current.x, fraction)
		if crossing_x < 0.0 or crossing_x >= size.x:
			continue
		crossed_strings.append(index)
		flash_string(index)
		string_crossed.emit(index)
		if crossed_strings.size() == 2:
			strum_completed.emit()
	last_position = current

func _draw() -> void:
	draw_style_box(wood, Rect2(Vector2.ZERO, size))
	var bridge_x := size.x * 0.13
	draw_rect(Rect2(bridge_x, 12.0, 14.0, maxf(0.0, size.y - 24.0)), Color("#4b2e22"))
	for index in STRING_COUNT:
		var y := string_y(index)
		var glow := flashes[index] / FLASH_DURATION
		var from := Vector2(14.0, y)
		var to := Vector2(size.x - 14.0, y)
		draw_line(from + Vector2.DOWN * 3.0, to + Vector2.DOWN * 3.0, Color("#211612"), STRING_THICKNESS[index] + 3.0, true)
		if glow > 0.0:
			draw_line(from, to, Color(1.0, 0.77, 0.39, glow * 0.27), STRING_THICKNESS[index] + 13.0, true)
		draw_line(from, to, Color("#d5b587").lerp(Color("#ffe1a1"), glow), STRING_THICKNESS[index], true)
		draw_circle(Vector2(bridge_x + 7.0, y), 6.0, Color("#f1d5a2"), true)

func _wood_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#38251e")
	style.border_color = Color("#73513c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	return style
