extends Control

@onready var play_btn = $VBoxContainer/PlayButton
@onready var quit_btn = $VBoxContainer/QuitButton

func _ready():
    play_btn.pressed.connect(_on_play_pressed)
    quit_btn.pressed.connect(func(): get_tree().quit())

func _on_play_pressed():
    get_tree().change_scene_to_file("res://scenes/ui/song_select.tscn")
