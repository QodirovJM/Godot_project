extends CanvasLayer

const CFG_PATH := "user://settings.cfg"

@onready var music_slider: HSlider  = $CenterContainer/Box/Music/MusicSlider
@onready var sfx_slider: HSlider    = $CenterContainer/Box/Sfx/SfxSlider
@onready var diff_opt: OptionButton = $CenterContainer/Box/Difficulty/DifficultyOpt
@onready var reset_btn: Button      = $CenterContainer/Box/Buttons/ResetBtn
@onready var back_btn: Button       = $CenterContainer/Box/Buttons/BackBtn

func _ready() -> void:
	_load_settings_into_ui()
	_connect_signals()

func _connect_signals() -> void:
	if not music_slider.value_changed.is_connected(_on_music_changed):
		music_slider.value_changed.connect(_on_music_changed)
	if not sfx_slider.value_changed.is_connected(_on_sfx_changed):
		sfx_slider.value_changed.connect(_on_sfx_changed)
	if not diff_opt.item_selected.is_connected(_on_difficulty_selected):
		diff_opt.item_selected.connect(_on_difficulty_selected)
	reset_btn.pressed.connect(_on_reset_pressed)
	back_btn.pressed.connect(_on_back_pressed)

# ---------- загрузка/сохранение ----------
func _load_settings_into_ui() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CFG_PATH)

	# значения по умолчанию
	var music_db := -6.0
	var sfx_db := 0.0
	var diff_idx := 1   # 0=Лёгкая, 1=Средняя, 2=Сложная

	if err == OK:
		music_db = float(cfg.get_value("audio", "music_db", music_db))
		sfx_db   = float(cfg.get_value("audio", "sfx_db", sfx_db))
		diff_idx = int(cfg.get_value("gameplay", "difficulty_index", diff_idx))

	# выставляем в UI
	music_slider.value = music_db
	sfx_slider.value   = sfx_db
	diff_opt.select(diff_idx)

	# применяем сразу (звук)
	_apply_audio(music_db, sfx_db)

func _save_settings_from_ui() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_db", music_slider.value)
	cfg.set_value("audio", "sfx_db",   sfx_slider.value)
	cfg.set_value("gameplay", "difficulty_index", diff_opt.get_selected_id())
	cfg.save(CFG_PATH)

# ---------- применение ----------
func _apply_audio(music_db: float, sfx_db: float) -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus   := AudioServer.get_bus_index("SFX")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, music_db)
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, sfx_db)

# ---------- обработчики ----------
func _on_music_changed(v: float) -> void:
	_apply_audio(v, sfx_slider.value)
	_save_settings_from_ui()

func _on_sfx_changed(v: float) -> void:
	_apply_audio(music_slider.value, v)
	_save_settings_from_ui()

func _on_difficulty_selected(_idx: int) -> void:
	_save_settings_from_ui()  # применится в main.gd при старте уровня

func _on_reset_pressed() -> void:
	music_slider.value = -6.0
	sfx_slider.value   = 0.0
	diff_opt.select(1)
	_save_settings_from_ui()
	_apply_audio(music_slider.value, sfx_slider.value)

func _on_back_pressed() -> void:
	_save_settings_from_ui()
	get_tree().change_scene_to_file("res://assets/scenes/MainMenu.tscn")
