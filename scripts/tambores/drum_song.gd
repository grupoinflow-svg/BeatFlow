extends Control

const DrumPad = preload("res://scripts/tambores/drum_pad.gd")
const CHART_PATH := "res://data/charts/demo_pulso_tambores.json"
const COUNT_BEAT := 60.0 / 96.0
const COUNT_BEATS := 4
const PERFECT_WINDOW := 0.080
const GOOD_WINDOW := 0.150
const DEFAULT_INSTRUCTION := "Toque no tambor quando o aro chegar à marca."

enum Phase { READY, PLAYING, PAUSED, RESULTS }

@onready var pads: Array[DrumPad] = [%Grave, %Medio, %Agudo]
@onready var voices: Array[AudioStreamPlayer] = [$BassDrum, $MidDrum, $HighDrum]
@onready var backing: AudioStreamPlayer = $Backing
@onready var title: Label = %Title
@onready var status: Label = %Status
@onready var hint: Label = %Hint
@onready var stats: Label = %Stats
@onready var progress: ProgressBar = %Progress
@onready var action: Button = %Action
@onready var back_button: Button = %Back

var _phase := Phase.READY
var _chart := [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
var _cursor := PackedInt32Array([0, 0, 0])
var _total := 0
var _lookahead := 1.15
var _song_time := 0.0
var _latency := 0.0
var _feedback_until := 0.0
var _score := ScoreManager.new()


func _ready() -> void:
	for index in pads.size():
		pads[index].struck.connect(_strike.bind(index))
	action.pressed.connect(_on_action)
	back_button.pressed.connect(_go_back)
	backing.finished.connect(_finish)
	set_process(false)

	var song := ChartManager.new().load_chart(CHART_PATH, backing.stream.get_length())
	_lookahead = song.get("approach_time", _lookahead)
	for note: Dictionary in song.get("notes", []):
		var drum: int = note["lane"]
		if drum < pads.size() and note["type"] == "tap":
			_chart[drum].append(float(note["time"]))
			_total += 1
	if _total == 0:
		hint.text = "O mapa de batidas da faixa não foi carregado."
		action.disabled = true
		return

	progress.max_value = backing.stream.get_length()
	title.text = "Pulso da Roda"
	_update_stats()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and _phase == Phase.PLAYING:
		_pause()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _phase == Phase.PLAYING:
			_pause()
		else:
			_go_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var index := [KEY_A, KEY_S, KEY_D].find(event.physical_keycode)
		if index >= 0:
			_strike(index)
			get_viewport().set_input_as_handled()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_action() -> void:
	match _phase:
		Phase.PLAYING:
			_pause()
		Phase.PAUSED:
			_resume()
		_:
			_start()


func _start() -> void:
	if _total == 0:
		return
	_cursor.fill(0)
	_score = ScoreManager.new()
	_score.set_total_events(_total)
	_song_time = 0.0
	_feedback_until = 0.0
	_latency = AudioServer.get_output_latency()
	progress.value = 0.0
	for voice in voices:
		voice.stop()
	_update_stats()
	_phase = Phase.PLAYING
	action.text = "Pausar"
	hint.text = DEFAULT_INSTRUCTION
	backing.stream_paused = false
	backing.play()
	set_process(true)
	_process(0.0)


func _pause() -> void:
	_read_clock()
	_phase = Phase.PAUSED
	backing.stream_paused = true
	set_process(false)
	status.text = "Faixa pausada"
	hint.text = "Continue do mesmo ponto."
	action.text = "Continuar"


func _resume() -> void:
	_phase = Phase.PLAYING
	backing.stream_paused = false
	action.text = "Pausar"
	hint.text = DEFAULT_INSTRUCTION
	_feedback_until = 0.0
	set_process(true)
	_process(0.0)


func _read_clock() -> float:
	if backing.playing:
		var position := backing.get_playback_position() + AudioServer.get_time_since_last_mix() - _latency
		_song_time = maxf(_song_time, position)
	return _song_time


func _process(_delta: float) -> void:
	var now := _read_clock()
	_expire_notes(now)
	progress.value = now
	if now < COUNT_BEAT * COUNT_BEATS:
		status.text = "Prepare-se · %d" % (COUNT_BEATS - floori(now / COUNT_BEAT))
	else:
		status.text = "%d / %d batidas" % [_score.perfects + _score.goods, _total]
		if now >= _feedback_until:
			hint.text = DEFAULT_INSTRUCTION
	for drum in pads.size():
		var upcoming := PackedFloat32Array()
		for index in range(_cursor[drum], _chart[drum].size()):
			var remaining: float = _chart[drum][index] - now
			if remaining > _lookahead:
				break
			upcoming.append(remaining / _lookahead)
		pads[drum].show_notes(upcoming)


func _expire_notes(now: float) -> void:
	var missed := false
	for drum in pads.size():
		while _cursor[drum] < _chart[drum].size() and now - _chart[drum][_cursor[drum]] > GOOD_WINDOW:
			_cursor[drum] += 1
			_score.add_miss()
			_score.add_event_result("miss")
			missed = true
	if missed:
		_update_stats()
		_feedback("Retome na próxima batida.", now)


func _strike(drum: int) -> void:
	if _phase == Phase.PAUSED:
		return
	if _phase != Phase.PLAYING:
		_play_drum(drum)
		return
	var now := _read_clock()
	_expire_notes(now)
	var index := _cursor[drum]
	if index >= _chart[drum].size() or absf(now - _chart[drum][index]) > GOOD_WINDOW:
		_feedback("Fora do tempo", now)
		return
	var perfect := absf(now - _chart[drum][index]) <= PERFECT_WINDOW
	_cursor[drum] += 1
	_score.add_hit(perfect)
	_score.add_event_result("perfect" if perfect else "good")
	_play_drum(drum)
	_feedback("No ritmo!" if perfect else "Boa batida", now)
	_update_stats()


func _play_drum(drum: int) -> void:
	voices[drum].play()
	pads[drum].flash()


func _feedback(message: String, now: float) -> void:
	hint.text = message
	_feedback_until = now + 0.7


func _update_stats() -> void:
	stats.text = "%d pontos  ·  %d em sequência" % [_score.score, _score.combo]


func _finish() -> void:
	_expire_notes(progress.max_value + GOOD_WINDOW)
	_phase = Phase.RESULTS
	set_process(false)
	progress.value = progress.max_value
	for pad in pads:
		pad.show_notes(PackedFloat32Array())
	status.text = "%d de %d batidas no tempo" % [_score.perfects + _score.goods, _total]
	hint.text = "Precisão %d%%  ·  Maior sequência %d" % [roundi(_score.get_accuracy()), _score.max_combo]
	action.text = "Tocar de novo"
