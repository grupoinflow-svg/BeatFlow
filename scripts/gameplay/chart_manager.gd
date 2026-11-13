class_name ChartManager
extends RefCounted

const CHORD_GROUP_EPSILON: float = 0.001

func load_song(song_id: String, difficulty: String, audio_length: float = INF) -> Dictionary:
	var path = "res://data/charts/%s_%s.json" % [song_id, difficulty]
	return load_chart(path, audio_length)

func load_chart(path: String, audio_length: float = INF) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Chart file not found: %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open chart: %s" % path)
		return {}

	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		push_error(
			"Invalid chart JSON at line %d: %s"
			% [parser.get_error_line(), parser.get_error_message()]
		)
		return {}

	var data = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Chart root must be a JSON object.")
		return {}

	var raw_notes = data.get("notes", [])
	if typeof(raw_notes) != TYPE_ARRAY:
		push_error("Chart 'notes' must be an array.")
		return {}

	var valid_notes: Array[Dictionary] = []

	for raw_note in raw_notes:
		if typeof(raw_note) != TYPE_DICTIONARY:
			push_warning("Skipping invalid note entry.")
			continue

		var raw_time = raw_note.get("time", -1.0)
		var raw_lane = raw_note.get("lane", -1)
		var raw_duration = raw_note.get("duration", 0.0)
		if not _is_finite_number(raw_time) or not _is_finite_number(raw_lane) or not _is_finite_number(raw_duration):
			push_warning("Skipping note with invalid numeric fields in %s." % path)
			continue
		var target_time := float(raw_time)
		var lane := int(raw_lane)

		var note_type: String = str(raw_note.get("type", "tap"))
		var duration := float(raw_duration)

		if target_time < 0.0:
			push_warning("Skipping note with negative timestamp.")
			continue

		if float(raw_lane) != float(lane) or lane < 0 or lane > 4:
			push_warning("Skipping note with invalid lane %d." % lane)
			continue
			
		if note_type == "hold":
			if duration <= 0.0:
				push_warning("Skipping hold note with invalid duration at time %f." % target_time)
				continue
		else:
			note_type = "tap"
			duration = 0.0

		if target_time >= audio_length or target_time + duration > audio_length:
			push_warning("Skipping note outside audio duration at %.3f s in %s." % [target_time, path])
			continue

		valid_notes.append({
			"time": target_time,
			"lane": lane,
			"type": note_type,
			"duration": duration
		})

	valid_notes.sort_custom(_sort_notes_by_time)
	var total_events := _group_notes(valid_notes)

	return {
		"song_id": str(data.get("song_id", "unknown")),
		"difficulty": str(data.get("difficulty", "unknown")),
		"approach_time": maxf(0.25, float(data.get("approach_time", 2.0))),
		"total_events": total_events,
		"notes": valid_notes
	}

func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _group_notes(notes: Array[Dictionary]) -> int:
	var group_start := 0
	var total_events := 0
	while group_start < notes.size():
		var event_time := float(notes[group_start]["time"])
		var group_end := group_start + 1
		while group_end < notes.size() and float(notes[group_end]["time"]) - event_time <= CHORD_GROUP_EPSILON:
			group_end += 1
		var chord_id := total_events if group_end - group_start > 1 else -1
		var event_end_time := float(notes[group_end - 1]["time"])
		for index in range(group_start, group_end):
			notes[index]["event_time"] = event_time
			notes[index]["event_end_time"] = event_end_time
			notes[index]["chord_id"] = chord_id
		group_start = group_end
		total_events += 1
	return total_events

func _sort_notes_by_time(a: Dictionary, b: Dictionary) -> bool:
	return float(a["time"]) < float(b["time"])
