extends Control

@onready var title_label = $SongTitle
@onready var start_btn = $StartButton
@onready var back_btn = $BackButton
@onready var diff_container = $DifficultyContainer

var difficulties_setup = [
    {"id": "easy", "label": "EASY", "dots": "●○○○", "color": Color(0.4, 0.8, 0.4)},
    {"id": "medium", "label": "MEDIUM", "dots": "●●○○", "color": Color(0.9, 0.8, 0.2)},
    {"id": "hard", "label": "HARD", "dots": "●●●○", "color": Color(0.9, 0.5, 0.2)},
    {"id": "expert", "label": "EXPERT", "dots": "●●●●", "color": Color(0.9, 0.2, 0.2)}
]

func _ready():
    start_btn.disabled = true
    start_btn.pressed.connect(_on_start_pressed)
    back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/song_select.tscn"))
    
    var song = GameSession.get_current_song()
    if song.is_empty():
        title_label.text = "ERROR: No Song Selected"
        return
        
    title_label.text = song["title"] + "\n" + song["artist"]
    
    var available = song.get("difficulties", [])
    for setup in difficulties_setup:
        if setup["id"] in available:
            var btn = Button.new()
            btn.custom_minimum_size = Vector2(0, 70)
            btn.text = setup["label"] + "  " + setup["dots"]
            btn.add_theme_color_override("font_color", setup["color"])
            btn.add_theme_font_size_override("font_size", 28)
            btn.pressed.connect(func(): _select_difficulty(setup["id"]))
            diff_container.add_child(btn)

func _select_difficulty(diff_id: String):
    GameSession.current_difficulty = diff_id
    start_btn.disabled = false
    start_btn.text = "START " + diff_id.to_upper()

func _on_start_pressed():
    if GameSession.current_difficulty != "":
        get_tree().change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
