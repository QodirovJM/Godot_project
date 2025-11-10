extends Node2D

var player: CharacterBody2D
var spawner: Node
var hud: CanvasLayer

@onready var pause_btn: Button        = $HUD/PauseButton
@onready var menu_btn: Button         = $HUD/MenuButton
@onready var start_button: Button     = $HUD/StartButton
@onready var topbar_score: Label      = $HUD/TopBar/ScoreLabel
@onready var center_msg: Label        = $HUD/CenterMsg/Message
@onready var hpbar: TextureProgressBar = $HUD/TopBar/HPBar
@onready var vjoy := $HUD/VirtualJoystick
@onready var attack_btn: TextureButton = $HUD/AttackBtn
@onready var sfx_ui: AudioStreamPlayer = $SFX



var game_active := false
var total_to_kill := 0
var killed := 0
var difficulty_index: int = 1  # 0=легко, 1=средне, 2=сложно
var snd_victory := preload("res://assets/audio/victory.wav")
var snd_defeat  := preload("res://assets/audio/defeat.wav")
var snd_click   := preload("res://assets/audio/ui_click.wav")

# ----- КОНФИГ УРОВНЕЙ -----
var level_index: int = 0   # 0..3

var LEVELS: Array[Dictionary] = [
	{
		"name": "Уровень 1",
		"total_to_kill": 2,
		"spawn_points_to_use": 1,
		"max_alive": 2,
		"spawn_interval": 2.0,
		"infinite": false
	},
	{
		"name": "Уровень 2",
		"total_to_kill": 4,
		"spawn_points_to_use": 2,
		"max_alive": 3,
		"spawn_interval": 1.8,
		"infinite": false
	},
	{
		"name": "Уровень 3",
		"total_to_kill": 5,
		"spawn_points_to_use": 3,
		"max_alive": 4,
		"spawn_interval": 1.6,
		"infinite": false
	},
	{
		"name": "Уровень 4 (Выживание)",
		"total_to_kill": 0,  # игнорируется в бесконечном режиме
		"spawn_points_to_use": 4,
		"max_alive": 5,
		"spawn_interval": 1.3,
		"infinite": true
	}
]



func _ready() -> void:
	player  = get_node_or_null("World/Player") as CharacterBody2D
	spawner = get_node_or_null("World/Spawner")
	
	var st := _load_settings()
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if music_bus >= 0: AudioServer.set_bus_volume_db(music_bus, st.get("music_db", -6.0))
	if sfx_bus >= 0:   AudioServer.set_bus_volume_db(sfx_bus, st.get("sfx_db", 0.0))

	# критично необходимые
	if player == null or spawner == null or start_button == null:
		push_error("Main: required nodes not found (Player/Spawner/StartButton).")
		return

	# кнопки HUD
	if not pause_btn.pressed.is_connected(_on_pause_pressed):
		pause_btn.pressed.connect(_on_pause_pressed)
	if not menu_btn.pressed.is_connected(_on_menu_pressed):
		menu_btn.pressed.connect(_on_menu_pressed)
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)

	# сигналы от спавнера/игрока
	if spawner.has_signal("enemy_killed") and not spawner.enemy_killed.is_connected(_on_enemy_killed):
		spawner.enemy_killed.connect(_on_enemy_killed)

	if spawner.has_signal("all_enemies_defeated") and not spawner.all_enemies_defeated.is_connected(_on_victory):
		spawner.all_enemies_defeated.connect(_on_victory)


	if player.has_signal("player_died") and not player.player_died.is_connected(_on_player_died):
		player.player_died.connect(_on_player_died)
	if player.has_signal("hp_changed") and not player.hp_changed.is_connected(_on_hp_changed):
		player.hp_changed.connect(_on_hp_changed)
	
	if vjoy and not vjoy.moved.is_connected(_on_vjoy_moved):
		vjoy.moved.connect(_on_vjoy_moved)
	
	if attack_btn and not attack_btn.pressed.is_connected(_on_attack_btn_pressed):
		attack_btn.pressed.connect(_on_attack_btn_pressed)
	
	# передаём игрока спавнеру НАДЁЖНО
	spawner.player_ref = player
	
	_apply_level_settings()
	
	_show_start_screen()

func _show_start_screen() -> void:
	var cfg: Dictionary = LEVELS[level_index]
	center_msg.text = "%s\nНажмите Старт" % cfg["name"]
	start_button.visible = true
	if spawner:
		if cfg["infinite"]:
			topbar_score.text = "Счёт: 0 / ∞"
		else:
			topbar_score.text = "Счёт: 0 / " + str(cfg["total_to_kill"])
	if hpbar:
		hpbar.value = 100


func _on_start_pressed() -> void:
	if player == null or not is_instance_valid(player):
		get_tree().reload_current_scene()
		return
	var cfg: Dictionary = LEVELS[level_index]
	center_msg.text = ""
	start_button.visible = false
	game_active = true
	killed = 0

	# применим настройки ещё раз на всякий случай
	_apply_level_settings()

	spawner.killed_count = 0
	if spawner.infinite:
		topbar_score.text = "Счёт: 0 / ∞"
	else:
		topbar_score.text = "Счёт: 0 / " + str(spawner.total_to_kill)

	if spawner.timer:
		spawner.timer.start()


func _on_enemy_killed(current_kills: int, total: int) -> void:
	killed = current_kills
	if spawner and spawner.infinite:
		topbar_score.text = "Счёт: " + str(killed) + " / ∞"
	else:
		topbar_score.text = "Счёт: " + str(killed) + " / " + str(total)
	print("[MAIN] got enemy_killed")



func _on_victory() -> void:
	game_active = false
	var passed_level := level_index + 1
	center_msg.text = "Победа! Уровень %d пройден" % passed_level
	start_button.text = "Дальше"
	start_button.visible = true

	# переходим к следующему уровню (максимум — 4-й)
	level_index = min(level_index + 1, LEVELS.size() - 1)

	# применяем настройки нового уровня (но не запускаем)
	_apply_level_settings()
	if sfx_ui and snd_victory:
		sfx_ui.stream = snd_victory
		sfx_ui.play()

func _on_player_died() -> void:
	game_active = false
	center_msg.text = "Поражение!"
	start_button.visible = true
	if spawner and spawner.timer:
		spawner.timer.stop()
	if sfx_ui and snd_defeat:
		sfx_ui.stream = snd_defeat
		sfx_ui.play()

func _on_hp_changed(hp: int, max_hp: int) -> void:
	if hpbar:
		hpbar.value = float(hp) / float(max_hp) * 100.0

func _on_pause_pressed() -> void:
	if not game_active:
		return
	get_tree().paused = not get_tree().paused
	center_msg.text = "Пауза" if get_tree().paused else ""
	if sfx_ui and snd_click:
		sfx_ui.stream = snd_click
		sfx_ui.play()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://assets/scenes/MainMenu.tscn")
	if sfx_ui and snd_click:
		sfx_ui.stream = snd_click
		sfx_ui.play()

func _on_vjoy_moved(v: Vector2) -> void:
	if player:
		player.set_move_vector(v)

func _on_attack_btn_pressed() -> void:
	# удобный способ: сгенерируем событие, как будто нажали клавишу "attack"
	Input.action_press("attack")
	await get_tree().process_frame
	Input.action_release("attack")

func _apply_level_settings() -> void:
	var cfg: Dictionary = LEVELS[level_index]
	spawner.total_to_kill       = cfg["total_to_kill"]
	spawner.spawn_points_to_use = cfg["spawn_points_to_use"]
	spawner.max_alive           = cfg["max_alive"]
	spawner.spawn_interval      = cfg["spawn_interval"]
	spawner.infinite            = cfg["infinite"]
	
	var st := _load_settings()
	difficulty_index = int(st.get("difficulty_index", 1))


	# синхронизируем таймер с новым интервалом
	if spawner.timer:
		spawner.timer.wait_time = spawner.spawn_interval

	# Обновим верхнюю панель (счёт)
	killed = 0
	total_to_kill = spawner.total_to_kill
	if spawner.infinite:
		topbar_score.text = "Счёт: 0 / ∞"
	else:
		topbar_score.text = "Счёт: 0 / " + str(total_to_kill)

	# Центровое сообщение
	center_msg.text = LEVELS[level_index]["name"]

func _load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return {}
	return {
		"music_db": float(cfg.get_value("audio", "music_db", -6.0)),
		"sfx_db": float(cfg.get_value("audio", "sfx_db", 0.0)),
		"difficulty_index": int(cfg.get_value("gameplay", "difficulty_index", 1))
	}
