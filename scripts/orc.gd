extends CharacterBody2D

signal orc_died(enemy: CharacterBody2D, points_awarded: int)

@export var max_hp: int = 2
@export var move_speed: float = 120.0
@export var attack_damage: int = 1
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 0.8
@export var attack_active_time: float = 0.15
@export var points: int = 1
@export var knockback_on_hurt: float = 180.0

var hp: int
var is_attacking: bool = false
var is_dead: bool = false
var facing: int = 1
var player: CharacterBody2D = null
var _hit_this_swing := {}
var snd_hurt := preload("res://assets/audio/orc_hurt.mp3")
var snd_die  := preload("res://assets/audio/orc_die.mp3")
var difficulty_index: int = 1


@onready var body_root: Node2D = $BodyRoot
@onready var sprite: AnimatedSprite2D = $BodyRoot/Sprite
@onready var hitbox: Area2D = $BodyRoot/Hitbox
@onready var attack_cd: Timer = $AttackCooldown
@onready var attack_active: Timer = $AttackActive
@onready var sfx: AudioStreamPlayer = $SFX


func _ready() -> void:
	hp = max_hp
	attack_cd.wait_time = attack_cooldown
	attack_active.wait_time = attack_active_time
	if hitbox: hitbox.monitoring = false

	# ФОЛБЭК: поиск игрока по группе, если спавнер не успел проставить
	if player == null:
		var n := get_tree().get_first_node_in_group("player")
		if n and n is CharacterBody2D:
			player = n
			print("[ORC] fallback got player")

	if hitbox and not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	if attack_active and not attack_active.timeout.is_connected(_on_AttackActive_timeout):
		attack_active.timeout.connect(_on_AttackActive_timeout)

	if sprite:
		sprite.play("idle")
		
	_apply_difficulty()


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	_update_movement()

	# анимации
	if sprite.animation == "hurt" and not is_attacking:
		pass
	elif is_attacking:
		if sprite.animation != "attack":
			sprite.play("attack")
	elif velocity.length() > 5.0:
		if sprite.animation != "walk":
			sprite.play("walk")
	else:
		if sprite.animation != "idle":
			sprite.play("idle")

	move_and_slide()

func _update_movement() -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	# Глобальные позиции (надёжно при любых поворотах родителей)
	var my_pos: Vector2 = global_position
	var pl_pos: Vector2 = player.global_position

	# Вектор к игроку и расстояние
	var vec_to_pl: Vector2 = pl_pos - my_pos
	var d: float = vec_to_pl.length()

	# Идём к игроку, пока не войдём в зону атаки
	if d > (attack_range - 4.0):
		var dir: Vector2 = (vec_to_pl / d) if d > 0.001 else Vector2.ZERO
		velocity = dir * move_speed

		# Разворот по X
		if abs(dir.x) > 0.05:
			facing = 1 if dir.x > 0.0 else -1
			$BodyRoot.scale.x = facing
	else:
		velocity = Vector2.ZERO
		_try_attack()


func _try_attack() -> void:
	if is_dead or is_attacking: return
	if attack_cd.time_left > 0.0: return
	is_attacking = true
	sprite.play("attack")
	_hit_this_swing.clear()
	if hitbox: hitbox.monitoring = true
	attack_active.start()
	attack_cd.start()

func _on_AttackActive_timeout() -> void:
	if hitbox: hitbox.monitoring = false
	is_attacking = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dead: return
	var target: Node = area
	while target and not (target is CharacterBody2D):
		target = target.get_parent()
	if target == null: return
	if _hit_this_swing.has(target): return
	if target.has_method("apply_damage"):
		_hit_this_swing[target] = true
		var dir := Vector2(facing, 0)
		(target as Node).apply_damage(attack_damage, dir)

func apply_damage(amount: int, from_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead: return
	hp = max(0, hp - amount)
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

func _apply_difficulty() -> void:
	match difficulty_index:
		0:
			attack_damage = 5
		1:
			attack_damage = 15
		2:
			attack_damage = 30

func _die() -> void:
	is_dead = true
	if hitbox:
		hitbox.monitoring = false
	set_physics_process(false)
	if sprite:
		sprite.play("die")
	var body_shape := $CollisionShape2D
	if body_shape:
		body_shape.disabled = true
	var hurt_shape := $BodyRoot/Hurtbox/CollisionShape2D
	if hurt_shape:
		hurt_shape.disabled = true
	
	print("[ORC] died, emitting signal")
	emit_signal("orc_died", self, points)

	get_tree().create_timer(4.0).timeout.connect(func(): queue_free(), CONNECT_ONE_SHOT)
