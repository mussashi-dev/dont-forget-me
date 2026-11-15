class_name MobFlorPoeira
extends CharacterBody2D
## Flor de Poeira: estacionária, dispara projéteis (esporos) na direção da Pablita a cada 2s.

@export var projectile_scene: PackedScene = preload("res://scenes/enemies/esporo_projectile.tscn")
@export var fire_interval: float = 2.0
@export var frame_fps: float = 5.0

var _frames: Array[Texture2D] = []
var _anim_timer: float = 0.0
var _frame_index: int = 0
var shots_fired: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var shoot_timer: Timer = $ShootTimer
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	add_to_group("enemies")
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i: int in 4:
		var path: String = "res://assets/characters/enemies/mob_flor_poeira_%d.png" % i
		if ResourceLoader.exists(path):
			_frames.append(load(path))
	if not _frames.is_empty():
		sprite.texture = _frames[0]

	if shoot_timer != null:
		shoot_timer.wait_time = fire_interval
		shoot_timer.one_shot = false
		if not shoot_timer.timeout.is_connected(_on_shoot_timer_timeout):
			shoot_timer.timeout.connect(_on_shoot_timer_timeout)
		shoot_timer.start()

	if health_component != null and not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)

func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_anim_timer += delta
	var step: float = 1.0 / maxf(1.0, frame_fps)
	if _anim_timer >= step:
		_anim_timer -= step
		_frame_index = (_frame_index + 1) % _frames.size()
		sprite.texture = _frames[_frame_index]

func _on_shoot_timer_timeout() -> void:
	fire_spore_at_player()

func fire_spore_at_player() -> Area2D:
	if projectile_scene == null:
		return null
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var dir: Vector2 = Vector2.LEFT
	if player != null and is_instance_valid(player):
		dir = global_position.direction_to(player.global_position)
		if dir == Vector2.ZERO:
			dir = Vector2.LEFT
		sprite.flip_h = dir.x < 0.0

	var spore: Area2D = projectile_scene.instantiate() as Area2D
	spore.global_position = global_position + Vector2(0, -10)
	spore.set("direction", dir)
	spore.set("source_enemy", self)
	var target_parent: Node = get_parent() if get_parent() != null else self
	target_parent.add_child(spore)
	shots_fired += 1
	return spore

func _on_died() -> void:
	queue_free()
