class_name MobBrinquedoCorda
extends CharacterBody2D
## Brinquedo de Corda: patrulha em linha reta, inverte ao colidir e usa QTE de timing (Heartbound).

signal qte_started(minigame: MinigameCombat)
signal qte_resolved(was_critical: bool, final_damage: int)

@export var patrol_speed: float = 55.0
@export var patrol_direction: Vector2 = Vector2.RIGHT
@export var frame_fps: float = 8.0
@export var critical_multiplier: float = 2.0

var _frames: Array[Texture2D] = []
var _anim_timer: float = 0.0
var _frame_index: int = 0
var _qte_active: bool = false
var _pending_damage: int = 0
var active_minigame: MinigameCombat = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox

func _ready() -> void:
	add_to_group("enemies")
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i: int in 4:
		var path: String = "res://assets/characters/enemies/mob_brinquedo_corda_%d.png" % i
		if ResourceLoader.exists(path):
			_frames.append(load(path))
	if not _frames.is_empty():
		sprite.texture = _frames[0]
	if hurtbox != null:
		# Aplica o dano apenas após a resolução do Minigame de timing
		hurtbox.health_component = null
		if not hurtbox.hit_received.is_connected(_on_hurtbox_hit_received):
			hurtbox.hit_received.connect(_on_hurtbox_hit_received)
	if health_component != null and not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if _qte_active:
		velocity = Vector2.ZERO
		return
	var dir: Vector2 = patrol_direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	velocity = dir * patrol_speed
	move_and_slide()

	if is_on_wall() or get_slide_collision_count() > 0:
		patrol_direction = -dir
		sprite.flip_h = patrol_direction.x < 0.0

func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_anim_timer += delta
	var step: float = 1.0 / maxf(1.0, frame_fps)
	if _anim_timer >= step:
		_anim_timer -= step
		_frame_index = (_frame_index + 1) % _frames.size()
		sprite.texture = _frames[_frame_index]

func _on_hurtbox_hit_received(damage: int, _damage_type: int, _knockback: Vector2, _stun: float) -> void:
	if _qte_active:
		return
	start_timing_qte(maxi(1, damage))

func start_timing_qte(base_damage: int = 20) -> MinigameCombat:
	if _qte_active and is_instance_valid(active_minigame):
		return active_minigame
	_qte_active = true
	_pending_damage = maxi(1, base_damage)

	var mg := MinigameCombat.new()
	mg.name = "TimingQTE_%d" % get_instance_id()
	active_minigame = mg
	var host: Node = get_tree().current_scene if (get_tree() != null and get_tree().current_scene != null) else get_parent()
	if host != null:
		host.add_child(mg)
	else:
		add_child(mg)

	mg.minigame_completed.connect(_on_qte_completed)
	mg.start_minigame(MinigameCombat.MinigameType.TIMING_BAR, &"attack_physical", "BRINQUEDO DE CORDA! Acerte a zona verde")
	qte_started.emit(mg)
	return mg

func _on_qte_completed(success: bool, _result_data: Dictionary) -> void:
	var mult: float = critical_multiplier if success else 1.0
	var final_damage: int = maxi(1, int(round(float(_pending_damage) * mult)))
	_qte_active = false
	active_minigame = null
	if sprite != null:
		sprite.modulate = Color(1.4, 1.15, 0.45, 1.0) if success else Color(1.2, 0.85, 0.85, 1.0)
	if health_component != null:
		health_component.take_damage(final_damage)
	qte_resolved.emit(success, final_damage)

func _on_died() -> void:
	if is_instance_valid(active_minigame):
		active_minigame.queue_free()
	queue_free()
