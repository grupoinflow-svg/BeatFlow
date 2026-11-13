extends Control

const BEAT_SECONDS := 5.0 / 6.0
const BEATS_PER_PHRASE := 8
const LISTEN_BEATS := 4
const PHRASES := [[0.0, 1.0, 3.0], [0.0, 2.0, 3.0], [0.0, 1.5, 3.0]]
const HITS_PER_PHRASE := 3
const HIT_WINDOW := 0.19
const FILL_BEAT := 7.4
const SOUND_SOL := preload("res://assets/audio/violao/sol.ogg")
const SOUND_SI := preload("res://assets/audio/violao/si.ogg")
const SOUND_MI := preload("res://assets/audio/violao/mi.ogg")

@onready var total_hits := PHRASES.size() * HITS_PER_PHRASE

var playing := false
var song_time := 0.0
var latency := 0.0
var hit_slots: Array[bool] = []
var extras: Array[int] = []
var hit_count := 0
var phrases_checked := 0
var previous_beat := -1
var voices: Array[AudioStreamPlayer] = []

@onready var strings: BeatFlowStrumSurface = $Strings
@onready var band: AudioStreamPlayer = $Band
@onready var fill: AudioStreamPlayer = $Fill
@onready var phase_label: Label = $Phase
@onready var hint: Label = $Hint
@onready var feedback: Label = $Footer/Feedback
@onready var start_button: Button = $Footer/Start
@onready var beat_labels: Array[Label] = [$Beats/One, $Beats/Two, $Beats/Three, $Beats/Four]

func _ready() -> void:
	_add_voice(SOUND_SOL, 0)
	_add_voice(SOUND_SI, 0)
	_add_voice(SOUND_SI, 3)
	_add_voice(SOUND_MI, 3)
	strings.string_crossed.connect(_pluck)
	strings.strum_completed.connect(_judge_strum)
	band.finished.connect(_finish)
	start_button.pressed.connect(_start)
	$Back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and playing:
		_stop_round()
		phase_label.text = "RODADA INTERROMPIDA"
		feedback.text = "Toque em Iniciar para tocar de novo."
		start_button.text = "INICIAR"

func _add_voice(stream: AudioStream, fret: int) -> void:
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.pitch_scale = pow(2.0, fret / 12.0)
	voice.volume_db = -13.0
	add_child(voice)
	voices.append(voice)

func _start() -> void:
	if playing:
		return
	for voice in voices:
		voice.stop()
	fill.stop()
	strings.reset_gesture()
	strings.reset_feedback()
	hit_slots.resize(total_hits)
	hit_slots.fill(false)
	extras.resize(PHRASES.size())
	extras.fill(0)
	hit_count = 0
	phrases_checked = 0
	previous_beat = -1
	song_time = 0.0
	latency = AudioServer.get_output_latency()
	playing = true
	start_button.hide()
	feedback.text = "A banda começa. Depois é a sua vez."
	band.play()
	set_process(true)
	_process(0.0)

func _read_clock() -> float:
	if band.playing:
		var time := band.get_playback_position() + AudioServer.get_time_since_last_mix() - latency
		song_time = maxf(song_time, time)
	return song_time

func _process(_delta: float) -> void:
	var now := _read_clock()
	var beat := mini(int(now / BEAT_SECONDS), PHRASES.size() * BEATS_PER_PHRASE - 1)
	if beat != previous_beat:
		_update_beat(beat)
		previous_beat = beat
	while phrases_checked < PHRASES.size() and now >= _phrase_end(phrases_checked):
		_check_phrase(phrases_checked)
		phrases_checked += 1

func _update_beat(beat: int) -> void:
	var phrase := floori(float(beat) / BEATS_PER_PHRASE)
	var count := beat % LISTEN_BEATS
	var listening := beat % BEATS_PER_PHRASE < LISTEN_BEATS
	phase_label.text = "%s   ·   FRASE %d/%d" % ["OUÇA" if listening else "SUA VEZ", phrase + 1, PHRASES.size()]
	phase_label.modulate = Color("#edbf88") if listening else Color("#a3e2b8")
	hint.text = "Escute a batida do violão." if listening else "Repita a batida. Respeite as pausas."
	if listening and count == 0:
		feedback.text = "O baixo e a percussão marcam os quatro tempos."
	elif not listening and count == 0:
		feedback.text = "Deslize para baixo ou para cima nas cordas."
	for index in beat_labels.size():
		beat_labels[index].modulate = Color("#ffe1a1") if index == count else Color("#927d65")

func _pluck(index: int) -> void:
	voices[index].play()

func _judge_strum() -> void:
	if not playing:
		feedback.text = "Isso é uma batida. Experimente para cima também."
		return

	var now := _read_clock()
	var phrase := clampi(int(now / (BEATS_PER_PHRASE * BEAT_SECONDS)), 0, PHRASES.size() - 1)
	var response_start := (phrase * BEATS_PER_PHRASE + LISTEN_BEATS) * BEAT_SECONDS
	if now < response_start - HIT_WINDOW or now >= _phrase_end(phrase):
		return

	for index: int in range(PHRASES[phrase].size()):
		var target := response_start + float(PHRASES[phrase][index]) * BEAT_SECONDS
		if absf(now - target) > HIT_WINDOW:
			continue
		var slot := phrase * HITS_PER_PHRASE + index
		if not hit_slots[slot]:
			hit_slots[slot] = true
			hit_count += 1
			feedback.text = "No ritmo!   %d / %d batidas" % [hit_count, total_hits]
			return
		break

	extras[phrase] += 1
	feedback.text = "Fora do tempo. Volte no próximo tempo."

func _phrase_end(phrase: int) -> float:
	return (phrase * BEATS_PER_PHRASE + FILL_BEAT) * BEAT_SECONDS

func _check_phrase(phrase: int) -> void:
	var hits := 0
	for index: int in range(PHRASES[phrase].size()):
		hits += int(hit_slots[phrase * HITS_PER_PHRASE + index])
	if hits == PHRASES[phrase].size() and extras[phrase] == 0:
		fill.play()
		feedback.text = "Frase completa! A banda respondeu."
	else:
		feedback.text = "%d de 3 batidas no tempo nessa frase." % hits

func _stop_round() -> void:
	playing = false
	band.stop()
	fill.stop()
	strings.reset_gesture()
	for voice in voices:
		voice.stop()
	set_process(false)
	for label in beat_labels:
		label.modulate = Color("#927d65")
	start_button.show()

func _finish() -> void:
	if not playing:
		return
	_stop_round()
	phase_label.text = "FIM DA RODA"
	phase_label.modulate = Color("#edbf88")
	hint.text = "Toque em Repetir para fazer outra rodada."
	feedback.text = "%d de %d batidas no tempo" % [hit_count, total_hits]
	start_button.text = "REPETIR"
