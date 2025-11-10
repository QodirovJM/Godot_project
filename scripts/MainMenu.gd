extends CanvasLayer

@onready var play_btn: Button = $Center/Box/PlayButton
@onready var settings_btn: Button = $Center/Box/Button
@onready var exit_btn: Button = $Center/Box/ExitButton
@onready var sfx: AudioStreamPlayer = $SFX

var snd_click := preload("res://assets/audio/ui_click.wav")

func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)

func _on_play_pressed() -> void:
	# Загружаем основную сцену игры (Main.tscn)
	if sfx and snd_click:
		sfx.stream = snd_click
		sfx.play()
	get_tree().change_scene_to_file("res://assets/scenes/main.tscn")

func _on_settings_pressed() -> void:
	if sfx and snd_click:
		sfx.stream = snd_click
		sfx.play()
	get_tree().change_scene_to_file("res://assets/scenes/SettingsMenu.tscn")

func _on_exit_pressed() -> void:
	if sfx and snd_click:
		sfx.stream = snd_click
		sfx.play()
	get_tree().quit()
