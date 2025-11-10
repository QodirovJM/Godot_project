extends Node2D

signal all_enemies_defeated
signal enemy_spawned(enemy: CharacterBody2D)
signal enemy_killed(current_kills: int, total: int)

@export var orc_scene: PackedScene
@export var max_alive: int = 3
@export var spawn_interval: float = 2.0
@export var total_to_kill: int = 10
@export var spawn_points_to_use: int = 1
@export var infinite: bool = false
@export var difficulty_index: int = 1


var player_ref: CharacterBody2D = null
var alive_enemies: Array = []
var killed_count: int = 0

@onready var timer: Timer = $SpawnTimer

func _ready() -> void:
	if timer == null:
		timer = Timer.new()
		timer.name = "SpawnTimer"
		add_child(timer)
	timer.one_shot = false
	timer.wait_time = spawn_interval
	if not timer.timeout.is_connected(_on_spawn_timer_timeout):
		timer.timeout.connect(_on_spawn_timer_timeout)
	# запуск из main по кнопке старт
	print("[SPAWNER] ready")

func _on_spawn_timer_timeout() -> void:
	if not infinite and killed_count >= total_to_kill:
		return
	if alive_enemies.size() >= max_alive:
		return
	if orc_scene == null:
		return

	# собираем точки спавна
	var points: Array[Marker2D] = []
	for c in get_children():
		if c is Marker2D:
			points.append(c)
	if points.is_empty():
		return

	# выбираем, сколько спавнов использовать
	var n: int = clampi(spawn_points_to_use, 1, points.size())
	var usable: Array = points.slice(0, n)
	var spawn_point: Marker2D = usable.pick_random()


	# создаём орка
	var enemy := orc_scene.instantiate() as CharacterBody2D
	get_parent().add_child(enemy)
	enemy.global_position = spawn_point.global_position

	# привязываем игрока
	if "player" in enemy:
		enemy.player = player_ref


	# гарантированно подключаем сигнал через Callable
	if enemy.has_signal("orc_died"):
		enemy.connect("orc_died", Callable(self, "_on_orc_died"))
		print("[SPAWNER] connected to orc_died")
	else:
		push_error("[SPAWNER] enemy has no orc_died signal")

	# передаём сложность орку
	if "difficulty_index" in enemy:
		enemy.difficulty_index = difficulty_index

	alive_enemies.append(enemy)
	emit_signal("enemy_spawned", enemy)
	print("[SPAWNER] spawned enemy at ", spawn_point.name)

func _on_orc_died(enemy: CharacterBody2D, _points: int) -> void:
	print("[SPAWNER] got orc_died signal")
	alive_enemies.erase(enemy)
	killed_count += 1
	emit_signal("enemy_killed", killed_count, total_to_kill)

	if infinite:
		return

	if killed_count >= total_to_kill:
		timer.stop()
		print("[SPAWNER] all enemies defeated")
		emit_signal("all_enemies_defeated")
