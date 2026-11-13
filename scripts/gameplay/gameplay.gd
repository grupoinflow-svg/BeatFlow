extends Control

const PERFECT_WINDOW: float = 0.090
const GOOD_WINDOW: float = 0.180
const EARLY_RELEASE_TOLERANCE: float = 0.150
const LANE_KEYS: Array[Key] = [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G]

const NOTE_SCENE: PackedScene = preload("res://scenes/gameplay/note.tscn")

var chart_manager: ChartManager
var score_manager: ScoreManager

# Máquina de estados clara
var game_state: String = "loading" # "loading", "countdown", "playing", "paused", "resuming", "finished", "results"

var active_notes: Array = []
var approach_time: float = 2.0

var output_latency: float = 0.0
var song_position: float = 0.0

var note_index: int = 0
var chart_data: Dictionary

var lane_held: Array[bool] = [false, false, false, false, false]
var pending_chord_results: Dictionary[int, Dictionary] = {}
var last_hit_offset: String = ""
var touch_to_lane: Dictionary[int, int] = {}
var held_lane_keys: Array[bool] = [false, false, false, false, false]
var mouse_lane: int = -1

# Audio feedback (volume ducking on miss, restore on hit)
const FULL_VOLUME_DB: float = 0.0
const MISS_VOLUME_DB: float = -18.0  # How quiet music gets on miss streak
const VOLUME_DUCK_SPEED: float = 12.0  # dB per second when ducking down
const VOLUME_RECOVER_SPEED: float = 20.0  # dB per second when recovering
var target_volume_db: float = 0.0
var current_volume_db: float = 0.0

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var notes_container: Control = $Highway/NotesContainer
@onready var highway: HighwayVisual = $Highway

# Layers e UI
@onready var hud: Control = $HUD
@onready var score_label: Label = $HUD/ScoreLabel
@onready var multiplier_label: Label = $HUD/MultiplierLabel
@onready var combo_label: Label = $HUD/CenterFeedback/ComboLabel
@onready var judgment_label: Label = $HUD/CenterFeedback/JudgmentLabel
@onready var debug_label: Label = $HUD/DebugLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var start_btn: Button = $StartRoundButton
@onready var lane_buttons: Array[Button] = [
	$Highway/Lane1, $Highway/Lane2, $Highway/Lane3,
	$Highway/Lane4, $Highway/Lane5,
]

@onready var countdown_layer: Control = $CountdownLayer
@onready var countdown_label: Label = $CountdownLayer/CountdownLabel

@onready var pause_layer: Control = $PauseLayer
@onready var pause_btn: Button = $HUD/PauseButton
@onready var resume_btn: Button = $PauseLayer/VBoxContainer/ResumeButton
@onready var p_restart_btn: Button = $PauseLayer/VBoxContainer/RestartButton
@onready var p_quit_btn: Button = $PauseLayer/VBoxContainer/QuitButton

@onready var results_layer: Control = $ResultsLayer
@onready var title_label: Label = $ResultsLayer/TitleLabel
@onready var stats_label: Label = $ResultsLayer/StatsLabel
@onready var retry_btn: Button = $ResultsLayer/VBoxContainer/RetryButton
@onready var song_select_btn: Button = $ResultsLayer/VBoxContainer/SongSelectButton
@onready var main_menu_btn: Button = $ResultsLayer/VBoxContainer/MainMenuButton

var combo_tween: Tween
var judgment_tween: Tween
var countdown_tween: Tween

func _ready() -> void:
	chart_manager = ChartManager.new()
	score_manager = ScoreManager.new()

	status_label.text = "Carregando chart..."
	
	# Connect UI buttons
	start_btn.pressed.connect(_start_countdown_sequence)
	$RestartButton.pressed.connect(_on_restart_pressed)
	pause_btn.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	p_restart_btn.pressed.connect(_on_restart_pressed)
	p_quit_btn.pressed.connect(_on_quit_to_main_menu)
	retry_btn.pressed.connect(_on_restart_pressed)
	song_select_btn.pressed.connect(_on_quit_to_song_select)
	main_menu_btn.pressed.connect(_on_quit_to_main_menu)

	audio.finished.connect(_on_audio_finished)

	highway.resized.connect(_recalculate_layout)
	get_window().focus_exited.connect(_reset_lane_input)
	_style_lane_buttons()
	_recalculate_layout()
	_load_initial_chart()

func _load_initial_chart() -> void:
	# Fallback caso execute a cena direto no editor
	if GameSession.current_song_id == "": GameSession.current_song_id = "demo"
	if GameSession.current_difficulty == "": GameSession.current_difficulty = "medium"
	
	var song_info = GameSession.get_current_song()
	var audio_path: String = song_info.get("audio_file", "")
	if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
		audio.stream = load(audio_path) as AudioStream
		if audio.stream != null:
			chart_data = chart_manager.load_song(
				GameSession.current_song_id, GameSession.current_difficulty, audio.stream.get_length()
			)

	if not chart_data.get("notes", []).is_empty():
		
		approach_time = chart_data.get("approach_time", 2.0)
		_count_total_events()
		var diff_str = GameSession.current_difficulty.to_upper()
		var title_str = song_info.get("title", "Unknown Song")
		status_label.text = "%s [%s] | Press Space or tap START" % [title_str, diff_str]
		title_label.text = "%s\n[%s]" % [title_str, diff_str]
		game_state = "loading"
		start_btn.show()
		_update_hud()
	else:
		status_label.text = "Could not load %s [%s]." % [GameSession.current_song_id, GameSession.current_difficulty]

func _cleanup_session():
	audio.stop()
	for note in active_notes:
		if is_instance_valid(note): note.queue_free()
	active_notes.clear()

func _on_quit_to_main_menu():
	_cleanup_session()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_quit_to_song_select():
	_cleanup_session()
	get_tree().change_scene_to_file("res://scenes/ui/song_select.tscn")

func _count_total_events() -> void:
	score_manager.set_total_events(chart_data.get("total_events", 0))

func _process(_delta: float) -> void:
	if game_state == "loading":
		return
		
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if game_state == "playing":
			_on_pause_pressed()
		elif game_state == "paused":
			_on_resume_pressed()

	if game_state == "playing" or game_state == "resuming":
		var song_time: float = get_song_position()
		
		# Permitir o spawn visual e movimento das notas mesmo no resume countdown (que congele visualmente se for o caso)
		# No resuming, o tempo fica travado porque audio não roda e get_song_position retorna tempo congelado
		_spawn_due_notes(song_time)
		_update_active_notes(song_time)
		
		if game_state == "playing":
			_check_missed_notes(song_time)
		_clean_up_notes()
	
	# Smooth volume ducking (runs in all active states)
	if current_volume_db != target_volume_db:
		var speed: float = VOLUME_RECOVER_SPEED if target_volume_db > current_volume_db else VOLUME_DUCK_SPEED
		current_volume_db = move_toward(current_volume_db, target_volume_db, speed * _delta)
		audio.volume_db = current_volume_db

func _input(event: InputEvent) -> void:
	if game_state == "loading" and start_btn.visible and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_start_countdown_sequence()
		return

	var accepts_press := game_state in ["countdown", "playing", "resuming"]
	if event is InputEventKey and not event.echo:
		var lane := LANE_KEYS.find(event.keycode)
		if lane >= 0 and (accepts_press or not event.pressed):
			held_lane_keys[lane] = event.pressed
			_refresh_lane_input(lane)
		return

	# Emulated pointer events remain available to the menus and round buttons.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if not accepts_press or touch_to_lane.has(event.index):
				return
			var lane := _screen_pos_to_lane(event.position)
			if lane < 0:
				return
			touch_to_lane[event.index] = lane
			_refresh_lane_input(lane)
			get_viewport().set_input_as_handled()
		elif touch_to_lane.has(event.index):
			var lane: int = touch_to_lane[event.index]
			touch_to_lane.erase(event.index)
			_refresh_lane_input(lane)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not event.canceled:
			if not accepts_press or mouse_lane >= 0:
				return
			mouse_lane = _screen_pos_to_lane(event.position)
			if mouse_lane < 0:
				return
			_refresh_lane_input(mouse_lane)
			get_viewport().set_input_as_handled()
		elif mouse_lane >= 0:
			var lane := mouse_lane
			mouse_lane = -1
			_refresh_lane_input(lane)
			get_viewport().set_input_as_handled()

func _screen_pos_to_lane(pos: Vector2) -> int:
	for lane in lane_buttons.size():
		var button := lane_buttons[lane]
		if button.is_visible_in_tree() and button.get_global_rect().has_point(pos):
			return lane
	return -1

func _refresh_lane_input(lane: int) -> void:
	var held := held_lane_keys[lane] or mouse_lane == lane or lane in touch_to_lane.values()
	if held == lane_held[lane]:
		return
	if held:
		_on_lane_down(lane)
	else:
		_on_lane_up(lane)

func _reset_lane_input() -> void:
	touch_to_lane.clear()
	held_lane_keys.fill(false)
	mouse_lane = -1
	for lane in lane_buttons.size():
		_refresh_lane_input(lane)

# ================= ESTADOS =================

func _start_countdown_sequence() -> void:
	if game_state != "loading" or not start_btn.visible:
		return
	game_state = "countdown"
	start_btn.hide()
	status_label.text = ""
	countdown_layer.show()
	pause_btn.disabled = true
	$RestartButton.disabled = true
	
	_animate_countdown(3)

func _animate_countdown(step: int) -> void:
	if game_state != "countdown" and game_state != "resuming":
		return # Interrompido por restart
		
	if step > 0:
		countdown_label.text = str(step)
		countdown_label.modulate.a = 1.0
		countdown_label.scale = Vector2(1.5, 1.5)
		
		if countdown_tween: countdown_tween.kill()
		countdown_tween = create_tween().set_parallel(true)
		countdown_tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BOUNCE)
		countdown_tween.tween_property(countdown_label, "modulate:a", 0.0, 0.3).set_delay(0.6)
		
		get_tree().create_timer(1.0).timeout.connect(func(): _animate_countdown(step - 1))
	else:
		countdown_label.text = "GO!"
		countdown_label.modulate.a = 1.0
		countdown_label.scale = Vector2(1.5, 1.5)
		
		if countdown_tween: countdown_tween.kill()
		countdown_tween = create_tween().set_parallel(true)
		countdown_tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3)
		countdown_tween.tween_property(countdown_label, "modulate:a", 0.0, 0.5).set_delay(0.5)
		
		if game_state == "countdown":
			_start_playing()
		elif game_state == "resuming":
			_finish_resume()

func _start_playing() -> void:
	game_state = "playing"
	countdown_layer.hide()
	pause_btn.disabled = false
	$RestartButton.disabled = false
	
	song_position = 0.0
	output_latency = AudioServer.get_output_latency()
	audio.play()

func _on_pause_pressed() -> void:
	if game_state != "playing": return
	
	get_song_position()
	game_state = "paused"
	audio.stream_paused = true
	pause_layer.show()

func _on_resume_pressed() -> void:
	if game_state != "paused": return
	
	game_state = "resuming"
	pause_layer.hide()
	countdown_layer.show()
	_animate_countdown(3)

func _finish_resume() -> void:
	countdown_layer.hide()
	# Restaurar tocadores lógicos baseados no touch state real, para que holds continuem vivas:
	# Como lanes podem estar held fisicamente ao voltar, resetaremos visual de lane pra refletir o input validado 
	# (o jogador precisará ter repousado o dedo no hold note antes do "GO" concluir).
	
	audio.stream_paused = false
	game_state = "playing"

func _on_restart_pressed() -> void:
	audio.stop()
	audio.stream_paused = false
	game_state = "loading"
	
	note_index = 0
	pending_chord_results.clear()
	last_hit_offset = ""
	song_position = 0.0
	
	score_manager = ScoreManager.new()
	_count_total_events()
	
	_reset_lane_input()
	_audio_reset()
	
	for note in active_notes:
		if is_instance_valid(note): note.queue_free()
	active_notes.clear()
	
	judgment_label.text = ""
	combo_label.text = ""
	
	pause_layer.hide()
	results_layer.hide()
	countdown_layer.hide()
	pause_btn.disabled = false
	$RestartButton.disabled = false
	if not chart_data.get("notes", []).is_empty():
		status_label.text = "%s [%s] | Press Space or tap START" % [GameSession.get_current_song().get("title", "Song"), GameSession.current_difficulty.to_upper()]
		start_btn.show()
	_update_hud()

func _on_audio_finished() -> void:
	if game_state != "playing": return
	var audio_end := audio.stream.get_length()
	_spawn_due_notes(audio_end)
	_update_active_notes(audio_end)
	# Resolve every unplayed note now that the track can accept no more hits.
	_check_missed_notes(INF)
	_clean_up_notes()
	game_state = "finished"
	_reset_lane_input()
	
	# Aguardar notas que talvez ainda estejam tocando no finalzinho (fadeouts)
	get_tree().create_timer(1.5).timeout.connect(_show_results)

func _show_results() -> void:
	if game_state != "finished": return
	game_state = "results"
	pause_btn.disabled = true
	$RestartButton.disabled = true
	
	var acc = score_manager.get_accuracy()
	var rank = score_manager.get_rank()
	
	stats_label.text = (
		"Score: %d\n" % score_manager.score +
		"Accuracy: %.2f%%\n" % acc +
		"Rank: %s\n" % rank +
		"Max Combo: %d\n\n" % score_manager.max_combo +
		"Perfect: %d\n" % score_manager.events_perfect +
		"Good: %d\n" % score_manager.events_good +
		"Miss: %d\n" % score_manager.events_miss +
		"(Events: %d)" % score_manager.total_events
	)
	
	results_layer.show()

# ================= TIME & SPAWN =================

func get_song_position() -> float:
	if game_state == "playing" and audio.playing:
		var playback_position := audio.get_playback_position()
		var mixed_position := playback_position + AudioServer.get_time_since_last_mix()
		song_position = maxf(song_position, mixed_position - output_latency)
	return song_position

func _spawn_due_notes(song_time: float) -> void:
	var lookahead: float = song_time + approach_time
	var notes_array: Array = chart_data.get("notes", [])
	while note_index < notes_array.size():
		var next_note: Dictionary = notes_array[note_index]
		if float(next_note["event_time"]) <= lookahead:
			_spawn_note(next_note)
			note_index += 1
		else:
			break

func _spawn_note(note_data: Dictionary) -> void:
	var note := NOTE_SCENE.instantiate() as RhythmNote
	notes_container.add_child(note)

	var lane: int = int(note_data["lane"])
	var p_type: String = str(note_data.get("type", "tap"))
	var p_duration: float = float(note_data.get("duration", 0.0))
	var t: float = float(note_data["time"])
	
	note.setup(t, lane, approach_time, p_type, p_duration)
	note.set_lane_geometry(highway.get_lane_center(lane), highway.get_hit_y(), highway.get_note_radius())

	note.chord_id = note_data["chord_id"]
	note.event_end_time = note_data["event_end_time"]
	active_notes.append(note)

# ================= UPDATE & MISS =================

func _update_active_notes(song_time: float) -> void:
	for note in active_notes:
		if not is_instance_valid(note): continue
		if note.state == "pending" or note.state == "holding":
			note.update_visual(song_time)
		if note.state != "holding" or game_state != "playing":
			continue
		if note.hold_released_in_window:
			_complete_hold(note)
		elif not lane_held[note.lane]:
			_judge_hold_release(note, song_time)
		elif song_time >= note.end_time:
			_complete_hold(note)

func _check_missed_notes(song_time: float) -> void:
	for note in active_notes:
		if not is_instance_valid(note) or note.state != "pending":
			continue
		if song_time <= note.event_end_time + GOOD_WINDOW:
			continue
		if note.chord_id >= 0:
			_miss_chord(note.chord_id)
		else:
			note.state = "missed"
			_register_miss()
			_fade_and_free(note)

func _miss_chord(chord_id: int) -> void:
	var found_any: bool = false
	for note in active_notes:
		if is_instance_valid(note) and note.chord_id == chord_id and note.state == "pending":
			note.state = "missed"
			_fade_and_free(note)
			found_any = true
	
	if found_any:
		_register_miss()

func _register_miss() -> void:
	score_manager.add_event_result("miss")
	score_manager.add_miss()
	_show_judgment("MISS", Color(0.8, 0.45, 0.45))
	_update_hud()

# ================= INPUT & HIT =================

func _on_lane_down(lane: int) -> void:
	lane_held[lane] = true
	lane_buttons[lane].set_pressed_no_signal(true)
	highway.set_lane_held(lane, true)
	
	if game_state != "playing": return

	var song_time := get_song_position()
	var candidate: RhythmNote
	var smallest_delta := INF

	for note in active_notes:
		if not is_instance_valid(note) or note.state != "pending" or note.lane != lane or not note.head_judgment.is_empty():
			continue
		var delta: float = song_time - note.target_time
		if song_time >= note.target_time - GOOD_WINDOW and song_time <= note.target_time + GOOD_WINDOW and absf(delta) < absf(smallest_delta):
			smallest_delta = delta
			candidate = note

	if candidate == null:
		return

	var is_perfect := song_time >= candidate.target_time - PERFECT_WINDOW and song_time <= candidate.target_time + PERFECT_WINDOW
	candidate.head_judgment = "perfect" if is_perfect else "good"
	last_hit_offset = "%s %+.1f ms" % [OS.get_keycode_string(LANE_KEYS[lane]), smallest_delta * 1000.0]
	highway.hit_receptor(lane)
	if candidate.chord_id >= 0:
		_try_resolve_chord(candidate.chord_id)
		_update_hud()
		return

	score_manager.add_hit(is_perfect)
	if candidate.note_type == "hold":
		candidate.state = "holding"
	else:
		score_manager.add_event_result(candidate.head_judgment)
		candidate.state = "completed"
		_fade_and_free(candidate)
	_show_hit(candidate.head_judgment)

func _try_resolve_chord(chord_id: int) -> void:
	var chord_notes: Array[RhythmNote] = []
	for note in active_notes:
		if is_instance_valid(note) and note.chord_id == chord_id and note.state == "pending":
			if note.head_judgment.is_empty():
				return
			chord_notes.append(note)

	var hits: Array[bool] = []
	var judgment := "perfect"
	var holds_remaining := 0
	for note in chord_notes:
		hits.append(note.head_judgment == "perfect")
		if note.head_judgment == "good":
			judgment = "good"
		if note.note_type == "hold":
			note.state = "holding"
			holds_remaining += 1
		else:
			note.state = "completed"
			_fade_and_free(note)

	score_manager.add_chord_hit(hits)
	if holds_remaining > 0:
		pending_chord_results[chord_id] = {"judgment": judgment, "holds_remaining": holds_remaining}
	else:
		score_manager.add_event_result(judgment)
	_show_hit(judgment)

func _show_hit(judgment: String) -> void:
	var color := Color(0.9, 0.9, 0.95) if judgment == "perfect" else Color(0.6, 0.7, 0.75)
	_show_judgment(judgment.to_upper(), color)
	_audio_on_hit()
	_animate_combo()
	_update_hud()

func _on_lane_up(lane: int) -> void:
	lane_held[lane] = false
	lane_buttons[lane].set_pressed_no_signal(false)
	highway.set_lane_held(lane, false)
	if game_state != "playing":
		return
	var release_time := get_song_position()
	for note in active_notes:
		if not is_instance_valid(note) or note.lane != lane or note.note_type != "hold" or note.head_judgment.is_empty():
			continue
		if note.state == "holding":
			_judge_hold_release(note, release_time)
		elif note.state == "pending":
			# A sustained chord head can be released before the last lane is hit.
			if release_time >= note.end_time - EARLY_RELEASE_TOLERANCE:
				note.hold_released_in_window = true
			else:
				_miss_chord(note.chord_id)

func _judge_hold_release(note: RhythmNote, release_time: float) -> void:
	if release_time >= note.end_time - EARLY_RELEASE_TOLERANCE:
		_complete_hold(note)
	else:
		_fail_hold(note)

func _complete_hold(note: RhythmNote) -> void:
	note.state = "completed"
	score_manager.complete_hold()
	if note.chord_id < 0:
		score_manager.add_event_result(note.head_judgment)
	elif pending_chord_results.has(note.chord_id):
		var result: Dictionary = pending_chord_results[note.chord_id]
		result["holds_remaining"] -= 1
		if result["holds_remaining"] == 0:
			score_manager.add_event_result(result["judgment"])
			pending_chord_results.erase(note.chord_id)
	_update_hud()
	highway.hit_receptor(note.lane)
	_fade_and_free(note)

func _fail_hold(note: RhythmNote) -> void:
	note.state = "missed"
	if note.chord_id < 0 or pending_chord_results.erase(note.chord_id):
		_register_miss()
		_audio_on_miss()
	_fade_and_free(note)

# ================= AUDIO FEEDBACK =================

func _audio_on_hit() -> void:
	target_volume_db = FULL_VOLUME_DB

func _audio_on_miss() -> void:
	target_volume_db = MISS_VOLUME_DB

func _audio_reset() -> void:
	target_volume_db = FULL_VOLUME_DB
	current_volume_db = FULL_VOLUME_DB
	audio.volume_db = FULL_VOLUME_DB

func _fade_and_free(note) -> void:
	var tween = create_tween()
	tween.tween_property(note, "modulate:a", 0.0, 0.15)
	tween.tween_callback(note.queue_free)

func _clean_up_notes() -> void:
	var active_count: int = active_notes.size()
	for i in range(active_count - 1, -1, -1):
		var note = active_notes[i]
		if not is_instance_valid(note) or note.state == "completed" or note.state == "missed":
			active_notes.remove_at(i)

# ================= HUD E LAYOUT =================

func _show_judgment(text_val: String, color: Color) -> void:
	judgment_label.text = text_val
	judgment_label.add_theme_color_override("font_color", color)
	judgment_label.scale = Vector2(0.5, 0.5)
	judgment_label.modulate.a = 1.0

	if judgment_tween: judgment_tween.kill()
	judgment_tween = create_tween().set_parallel(true)
	judgment_tween.tween_property(judgment_label, "scale", Vector2(1.1, 1.1), 0.1)
	judgment_tween.tween_property(judgment_label, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.1)
	judgment_tween.tween_property(judgment_label, "modulate:a", 0.0, 0.2).set_delay(0.3)

func _animate_combo() -> void:
	if score_manager.combo < 3: return
	combo_label.scale = Vector2(1.3, 1.3)
	if combo_tween: combo_tween.kill()
	combo_tween = create_tween()
	combo_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.15)

func _update_hud() -> void:
	score_label.text = "%06d" % score_manager.score
	multiplier_label.text = "x%d" % score_manager.multiplier
	
	if score_manager.combo >= 3:
		combo_label.text = "%d COMBO" % score_manager.combo
	else:
		combo_label.text = ""

	debug_label.text = (
		"State: %s\n" % game_state +
		"Score: %d\n" % score_manager.score +
		"Combo: %d\n" % score_manager.combo +
		"P: %d G: %d M: %d\n" % [score_manager.events_perfect, score_manager.events_good, score_manager.events_miss] +
		"Acc: %.2f%%\n" % score_manager.get_accuracy() +
		"Offset: %s" % (last_hit_offset if not last_hit_offset.is_empty() else "--")
	)

func _style_lane_buttons() -> void:
	for lane in lane_buttons.size():
		var button := lane_buttons[lane]
		var color := HighwayVisual.NOTE_COLORS[lane]
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.055, 0.065, 0.09).lerp(color, 0.18)
		normal.border_color = color
		normal.set_border_width_all(2)
		normal.border_width_top = 5
		normal.set_corner_radius_all(10)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = color
		for state in ["normal", "hover"]:
			button.add_theme_stylebox_override(state, normal)
		for state in ["pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, pressed)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color(0.015, 0.02, 0.03))

func _recalculate_layout() -> void:
	if highway.size.x <= HighwayVisual.PAD_GAP * HighwayVisual.LANE_COUNT or highway.get_hit_y() <= 0.0:
		return
	for lane in lane_buttons.size():
		var pad_rect := highway.get_pad_rect(lane)
		lane_buttons[lane].position = pad_rect.position
		lane_buttons[lane].size = pad_rect.size
	highway.queue_redraw()

	for note in active_notes:
		if is_instance_valid(note):
			note.set_lane_geometry(highway.get_lane_center(note.lane), highway.get_hit_y(), highway.get_note_radius())
			note.update_visual(song_position)
