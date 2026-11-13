extends Control

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const PERFECT_WINDOW := 0.09
const GOOD_WINDOW := 0.18
const BEAT_SECONDS := 2.0 / 3.0
const FIRST_NOTE_BEAT := 4
const STRING_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/violao/sol.ogg"),
	preload("res://assets/audio/violao/si.ogg"),
	preload("res://assets/audio/violao/mi.ogg"),
]

# Vector2i(string index, fret); one note per beat, after a four-beat count-in.
const MELODY: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 3),
	Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 2), Vector2i(0, 0),
	Vector2i(1, 1), Vector2i(1, 3), Vector2i(2, 0), Vector2i(2, 1),
	Vector2i(2, 3), Vector2i(2, 0), Vector2i(1, 3), Vector2i(1, 1),
	Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0),
	Vector2i(1, 3), Vector2i(1, 1), Vector2i(0, 2), Vector2i(0, 0),
]

enum RoundState { PRACTICE, PLAYING, FINISHED }

var state := RoundState.PRACTICE
var score := ScoreManager.new()
var note_index := 0
var song_time := 0.0
var output_latency := 0.0
var string_players: Array[AudioStreamPlayer] = []

@onready var fretboard: GuitarFretboard = $Fretboard
@onready var pulse: AudioStreamPlayer = $Pulse
@onready var back_button: Button = $Back
@onready var round_button: Button = $Footer/RoundButton
@onready var progress: Label = $Progress
@onready var feedback: Label = $Footer/Feedback

func _ready() -> void:
	for stream in STRING_SOUNDS:
		for fret in GuitarFretboard.FRET_COUNT:
			var player := AudioStreamPlayer.new()
			player.stream = stream
			player.pitch_scale = pow(2.0, float(fret) / 12.0)
			player.volume_db = -8.0
			add_child(player)
			string_players.append(player)

	fretboard.string_plucked.connect(_on_string_plucked)
	round_button.pressed.connect(_start_round)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	pulse.finished.connect(_finish_round)
	_update_progress()
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and state == RoundState.PLAYING:
		pulse.stop()
		for player in string_players:
			player.stop()
		state = RoundState.PRACTICE
		fretboard.update_cue(0.0)
		round_button.text = "INICIAR"
		round_button.show()
		feedback.text = "Partida interrompida. Toque em Iniciar para recomeçar."
		_update_progress()
		set_process(false)

func _start_round() -> void:
	if state == RoundState.PLAYING:
		return
	for player in string_players:
		player.stop()
	score = ScoreManager.new()
	score.set_total_events(MELODY.size())
	note_index = 0
	song_time = 0.0
	output_latency = AudioServer.get_output_latency()
	fretboard.feedback_remaining = 0.0
	state = RoundState.PLAYING
	round_button.hide()
	feedback.text = "Prepare-se. A primeira nota acende na quarta batida."
	_update_progress()
	fretboard.update_cue(0.0, MELODY[0], _target_time(0))
	pulse.play()
	set_process(true)

func _process(_delta: float) -> void:
	var now := _read_clock()
	_resolve_overdue_notes(now)
	if note_index < MELODY.size():
		fretboard.update_cue(now, MELODY[note_index], _target_time(note_index))
	else:
		_finish_round()

func _read_clock() -> float:
	if pulse.playing:
		var playback_time := pulse.get_playback_position() + AudioServer.get_time_since_last_mix() - output_latency
		song_time = maxf(song_time, playback_time)
	return song_time

func _target_time(index: int) -> float:
	return (FIRST_NOTE_BEAT + index) * BEAT_SECONDS

func _on_string_plucked(string_index: int, fret: int) -> void:
	string_players[string_index * GuitarFretboard.FRET_COUNT + fret].play()
	var played := Vector2i(string_index, fret)

	if state != RoundState.PLAYING:
		fretboard.flash(played, Color("#edb879"))
		if state == RoundState.PRACTICE:
			feedback.text = "%s • %s" % [
				GuitarFretboard.NOTE_NAMES[string_index][fret],
				GuitarFretboard.FRET_NAMES[fret].capitalize(),
			]
		return

	var now := _read_clock()
	_resolve_overdue_notes(now)
	if note_index >= MELODY.size():
		_finish_round()
		return

	var offset := now - _target_time(note_index)
	if played != MELODY[note_index]:
		fretboard.flash(played, Color("#fa9d86"))
		feedback.text = "Procure a posição iluminada."
		return
	if absf(offset) > GOOD_WINDOW:
		fretboard.flash(played, Color("#edb879"))
		feedback.text = "Espere o anel fechar na batida."
		return

	var is_perfect := absf(offset) <= PERFECT_WINDOW
	score.add_hit(is_perfect)
	score.add_event_result("perfect" if is_perfect else "good")
	feedback.text = "No tempo!" if is_perfect else "Bom toque!"
	fretboard.flash(played, Color("#9ae4b2") if is_perfect else Color("#f7cf86"))
	note_index += 1
	_update_progress()
	if note_index < MELODY.size():
		fretboard.update_cue(now, MELODY[note_index], _target_time(note_index))
	else:
		_finish_round()

func _resolve_overdue_notes(now: float) -> void:
	while note_index < MELODY.size() and now > _target_time(note_index) + GOOD_WINDOW:
		fretboard.flash(MELODY[note_index], Color("#fa9d86"))
		score.add_miss()
		score.add_event_result("miss")
		note_index += 1
		feedback.text = "Passou. Siga para a próxima nota."
		_update_progress()

func _finish_round() -> void:
	if state != RoundState.PLAYING:
		return
	_resolve_overdue_notes(INF)
	state = RoundState.FINISHED
	pulse.stop()
	set_process(false)
	fretboard.update_cue(song_time)
	var hits := score.events_perfect + score.events_good
	feedback.text = "%d de %d notas no tempo  •  Precisão %.0f%%" % [hits, MELODY.size(), score.get_accuracy()]
	round_button.text = "REPETIR"
	round_button.show()
	_update_progress()

func _update_progress() -> void:
	if state == RoundState.PRACTICE:
		progress.text = "EXPLORAÇÃO LIVRE"
	else:
		progress.text = "%02d / %02d   •   %d PTS" % [note_index, MELODY.size(), score.score]
