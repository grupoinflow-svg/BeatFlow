extends Control

@onready var container = $ScrollContainer/VBoxContainer
@onready var back_btn = $BackButton

func _ready():
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	_populate_songs()

func _populate_songs():
	var songs = GameSession.get_all_songs()
	for s in songs:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 100)
		btn.text = s["title"] + " - " + s["artist"]
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(func(): _on_song_selected(s["id"]))
		container.add_child(btn)

func _on_song_selected(id: String):
	GameSession.current_song_id = id
	get_tree().change_scene_to_file("res://scenes/ui/difficulty_select.tscn")
