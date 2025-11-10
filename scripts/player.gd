extends CharacterBody2D

signal player_died
signal hp_changed(new_hp, max_hp)

@export var max_hp: int = 3
@export var move_speed: float = 180.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 0.5
@export var attack_active_time: float = 0.15
@export var knockback_on_hurt: float = 220.0
@onready var sfx: AudioStreamPlayer = $SFX


var hp: int
var is_attacking: bool = false
var is_dead: bool = false
var move_input: Vector2 = Vector2.ZERO        # сюда можно подавать вектор с виртуального джойстика
var facing: int = 1    
var _hit_this_swing: = {}   # Set без типов: кто уже получил урон в текущем взмахе
var snd_swing := preload("res://assets/audio/swing.wav")
var snd_hurt  := preload("res://assets/audio/player_hurt.wav")
var snd_die   := preload("res://assets/audio/player_die.mp3")


@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_cd: Timer = $AttackCooldown
@onready var attack_active: Timer = $AttackActive

func _ready() -> void:
	hp = max_hp
	attack_cd.wait_time = attack_cooldown
	attack_active.wait_time = attack_active_time
	hitbox.monitoring = false                 # удар активируем только в окно атаки
	# подписки на сигналы
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	# Hurtbox обычно не "monitoring", но другие Hitbox могут ловить его.
	sprite.play("idle")
	attack_active.timeout.connect(_on_AttackActive_timeout)
	if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	if not attack_active.timeout.is_connected(_on_AttackActive_timeout):
		attack_active.timeout.connect(_on_AttackActive_timeout)


func set_move_vector(v: Vector2) -> void:
	# вызывать из мобильного джойстика: v.x и v.y в диапазоне [-1..1]
	move_input = v.limit_length(1.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	# ПК-управление (клавиатура) + объединение с мобильным вектором
	var kbd := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
	)
	var dir := (kbd + move_input).limit_length(1.0)

	# поворот по направлению
	if abs(dir.x) > 0.05:
		facing = 1 if dir.x > 0.0 else -1
		sprite.flip_h = (facing == -1)

	# движение, если не атакуем (можно разрешить и во время атаки — на твой вкус)
	if not is_attacking:
		velocity = dir * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		move_and_slide()

	# анимации по приоритету
	if is_attacking:
		if sprite.animation != "attack":
			sprite.play("attack")
	elif velocity.length() > 5.0:
		if sprite.animation != "walk":
			sprite.play("walk")
	else:
		if sprite.animation != "idle":
			sprite.play("idle")

	# кнопка атаки (клавиатура/кнопка на экране)
	if Input.is_action_just_pressed("attack"):
		_try_attack()


func _try_attack() -> void:
	if is_dead or is_attacking:
		return
	if attack_cd.time_left > 0.0:
		return

	is_attacking = true
	sprite.play("attack")
	
	if sfx and snd_swing:
		sfx.stream = snd_swing
		sfx.pitch_scale = randf_range(0.95, 1.05)  # лёгкая вариация
		sfx.play()
	
	_hit_this_swing.clear()    # << добавь

	hitbox.monitoring = true
	attack_active.start()
	attack_cd.start()


func _on_AttackActive_timeout() -> void:
	hitbox.monitoring = false
	is_attacking = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	# Поднимаемся вверх, пока не найдём CharacterBody2D (цель), т.к. Hurtbox может быть вложен в BodyRoot
	var target: Node = area
	while target != null and not (target is CharacterBody2D):
		target = target.get_parent()

	if target == null:
		return
	if _hit_this_swing.has(target):
		return
	if target.has_method("apply_damage"):
		_hit_this_swing[target] = true
		var dir := Vector2(facing, 0)
		(target as Node).apply_damage(attack_damage, dir)


func apply_damage(amount: int, from_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	hp = max(0, hp - amount)
	emit_signal("hp_changed", hp, max_hp)

	# короткая реакция на урон (анимация/нокбэк)
	if hp > 0:
		sprite.play("hurt")
		if from_dir != Vector2.ZERO:
			velocity = -from_dir.normalized() * knockback_on_hurt
		if sfx and snd_hurt:
			sfx.stream = snd_hurt
			sfx.pitch_scale = randf_range(0.95, 1.05)
			sfx.play()
	else:
		if sfx and snd_die:
			sfx.stream = snd_die
			sfx.play()
		_die()

func _die() -> void:
	is_dead = true
	hitbox.monitoring = false
	set_process_input(false)
	sprite.play("die")
	# отключаем коллизии тела и хёртбокса
	var body_shape := $CollisionShape2D
	if body_shape: body_shape.disabled = true
	var hurt_shape := $Hurtbox/CollisionShape2D
	if hurt_shape: hurt_shape.disabled = true
	# через конец анимации можно удалить или сообщить о смерти
	sprite.animation_finished.connect(func():
		emit_signal("player_died")
		queue_free()
	, CONNECT_ONE_SHOT)

# Подпишись в инспекторе:
# AttackActive (Timer) → timeout → _on_AttackActive_timeout
