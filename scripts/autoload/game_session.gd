extends Node

var current_song_id: String = ""
var current_difficulty: String = ""

# Estrutura base escalonável para futuras músicas
var songs_db: Dictionary = {
	"demo": {
		"id": "demo",
		"title": "BeatFlow Demo",
		"artist": "The BeatFlow Team",
		"audio_file": "res://assets/audio/demo_clicktrack.wav",
		"difficulties": ["easy", "medium", "hard", "expert"]
	}
}

func get_current_song() -> Dictionary:
	if songs_db.has(current_song_id):
		return songs_db[current_song_id]
	return {}

func get_all_songs() -> Array:
	return songs_db.values()

func reset_session() -> void:
	current_song_id = ""
	current_difficulty = ""
