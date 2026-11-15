class_name MobTufoMeias
extends CharacterBody2D
## Tufo de Meias: detecta a Pablita via Area2D e move-se lentamente na direção dela.

@export var chase_speed: float = 42.0
@export var frame_fps: float = 6.0

var target_player: Node2D = null
var _frames: Array[Texture2D] = []
var _anim_timer: float = 0.0
var _frame_index: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	add_to_group("enemies")
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i: int in 4:
		var path: String = "res://assets/characters/enemies/mob_tufo_meias_%d.png" % i
		if ResourceLoader.exists(path):
			_frames.append(load(path))
	if not _frames.is_empty():
		sprite.texture = _frames[0]

	if detection_area != null:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	if health_component != null and not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)

func _physics_process(_delta: float) -> void:
	if target_player != null and is_instance_valid(target_player):
		var dir: Vector2 = global_position.direction_to(target_player.global_position)
		velocity = dir * chase_speed
		if not is_zero_approx(dir.x):
			sprite.flip_h = dir.x < 0.0
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_anim_timer += delta
	var step: float = 1.0 / maxf(1.0, frame_fps)
	if _anim_timer >= step:
		_anim_timer -= step
		_frame_index = (_frame_index + 1) % _frames.size()
		sprite.texture = _frames[_frame_index]

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body is Pablita:
		target_player = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null

func _on_died() -> void:
	queue_free()
