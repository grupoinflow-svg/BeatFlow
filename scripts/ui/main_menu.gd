extends Control

func _ready() -> void:
	$VBoxContainer/DrumButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/atabaque/atabaque_round.tscn"))
	$VBoxContainer/RodaButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/roda/roda_round.tscn"))
	$VBoxContainer/PlayButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/song_select.tscn"))
	$VBoxContainer/GuitarButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/violao/guitar_round.tscn"))
	$VBoxContainer/QuitButton.pressed.connect(func(): get_tree().quit())
