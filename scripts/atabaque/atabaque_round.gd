extends Control

const DrumSurface = preload("res://scripts/atabaque/drum_surface.gd")
const PATTERNS := [
	[DrumSurface.Zone.CENTER, DrumSurface.Zone.RIM],
	[DrumSurface.Zone.RIM, DrumSurface.Zone.CENTER],
]
const BEAT_GAPS := [0.52, 0.76]
const ROUND_TITLE := "Rodada %d de %d"

enum Phase { READY, LISTEN, RESPOND, COMPLETE }

var _phase := Phase.READY
var _round := 0
var _stroke := 0
var _resume_call := false

@onready var drum: DrumSurface = %Drum
@onready var heading: Label = %Heading
@onready var hint: Label = %Hint
@onready var round_label: Label = %Round
@onready var action: Button = %Action
@onready var timer: Timer = $CallTimer
@onready var grave: AudioStreamPlayer = $Grave
@onready var agudo: AudioStreamPlayer = $Agudo


func _ready() -> void:
	%Back.pressed.connect(_go_back)
	action.pressed.connect(_on_action)
	drum.struck.connect(_on_strike)
	timer.timeout.connect(_play_next_call_stroke)
	_render_ready()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED and _phase == Phase.LISTEN:
		timer.stop()
		grave.stop()
		agudo.stop()
		_resume_call = true
	elif what == NOTIFICATION_APPLICATION_RESUMED and _resume_call:
		_resume_call = false
		_start_call()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_J:
				_on_strike(DrumSurface.Zone.CENTER)
				get_viewport().set_input_as_handled()
			KEY_K:
				_on_strike(DrumSurface.Zone.RIM)
				get_viewport().set_input_as_handled()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _render_ready() -> void:
	round_label.text = ROUND_TITLE % [_round + 1, PATTERNS.size()]
	heading.text = "Ouça e repita"
	hint.text = "Experimente o centro e a borda. Depois, ouça duas batidas."
	action.text = "Ouvir as batidas"


func _on_action() -> void:
	if _phase == Phase.LISTEN:
		return
	if _phase == Phase.COMPLETE:
		_round = (_round + 1) % PATTERNS.size()
	_start_call()


func _start_call() -> void:
	_phase = Phase.LISTEN
	_stroke = 0
	round_label.text = ROUND_TITLE % [_round + 1, PATTERNS.size()]
	heading.text = "Ouça"
	hint.text = "Veja onde o tambor acende."
	action.text = "Ouvindo…"
	action.disabled = true
	drum.show_cue(-1)
	timer.start(0.28)


func _play_next_call_stroke() -> void:
	var pattern: Array = PATTERNS[_round]
	if _stroke == pattern.size():
		_phase = Phase.RESPOND
		_stroke = 0
		heading.text = "Sua vez"
		action.text = "Ouvir de novo"
		action.disabled = false
		_prompt_stroke()
		return

	var zone: int = pattern[_stroke]
	drum.show_cue(zone)
	_sound(zone)
	_stroke += 1
	timer.start(BEAT_GAPS[_round] if _stroke < pattern.size() else 0.55)


func _prompt_stroke() -> void:
	var pattern: Array = PATTERNS[_round]
	var zone: int = pattern[_stroke]
	drum.show_cue(zone)
	hint.text = "Batida %d de %d · Toque %s" % [_stroke + 1, pattern.size(), _place(zone)]


func _place(zone: int) -> String:
	return "no centro" if zone == DrumSurface.Zone.CENTER else "na borda"


func _on_strike(zone: int) -> void:
	if _phase == Phase.LISTEN:
		return
	_sound(zone)
	if _phase != Phase.RESPOND:
		return

	var pattern: Array = PATTERNS[_round]
	var expected: int = pattern[_stroke]
	if zone != expected:
		hint.text = "Batida %d de %d · Tente %s" % [_stroke + 1, pattern.size(), _place(expected)]
		return

	_stroke += 1
	if _stroke < pattern.size():
		_prompt_stroke()
		return
	_phase = Phase.COMPLETE
	drum.show_cue(-1)
	if _round + 1 == PATTERNS.size():
		heading.text = "Você completou!"
		hint.text = "As duas sequências foram tocadas."
		action.text = "Tocar de novo"
	else:
		heading.text = "Boa batida!"
		hint.text = "Vamos ouvir uma nova sequência."
		action.text = "Próxima rodada"


func _sound(zone: int) -> void:
	if zone == DrumSurface.Zone.CENTER:
		grave.play()
	else:
		agudo.play()
	drum.flash(zone)
