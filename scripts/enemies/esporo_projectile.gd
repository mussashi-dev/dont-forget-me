class_name EsporoProjectile
extends Area2D
## Projétil de esporo disparado pela Flor de Poeira em direção à Pablita.
## Possui QTE de reflexo para rebater o esporo usando o "Som" do Pipop.

signal reflex_qte_started(minigame: MinigameCombat)
signal spore_reflected(projectile: EsporoProjectile)

@export var speed: float = 110.0
@export var reflected_speed: float = 240.0
@export var damage: int = 10
@export var reflected_damage: int = 45
@export var lifetime: float = 3.5
@export var reflex_trigger_distance: float = 92.0

var direction: Vector2 = Vector2.LEFT
var source_enemy: Node2D = null
var is_reflected: bool = false
var _age: float = 0.0
var _qte_triggered: bool = false
var active_minigame: MinigameCombat = null

@onready var visual: Polygon2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 3 | 16 # Player (1), Mundo (2) e SonicHitbox (16) para rebatida
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	call_deferred("_bind_pipop_reflex")

func _bind_pipop_reflex() -> void:
	if get_tree() == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Pablita
	if player != null and player.pipop != null and not player.pipop.sonic_attack_started.is_connected(_on_pipop_sonic_started):
		player.pipop.sonic_attack_started.connect(_on_pipop_sonic_started)

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	_age += delta
	if not is_reflected and not _qte_triggered:
		_check_reflex_proximity()
	if _age >= lifetime:
		_cleanup_qte()
		queue_free()

func _check_reflex_proximity() -> void:
	if get_tree() == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= reflex_trigger_distance:
			start_reflex_qte()

func start_reflex_qte() -> MinigameCombat:
	if _qte_triggered and is_instance_valid(active_minigame):
		return active_minigame
	_qte_triggered = true

	var mg := MinigameCombat.new()
	mg.name = "SonicReflexQTE_%d" % get_instance_id()
	mg.reflex_duration = maxf(0.85, reflex_trigger_distance / maxf(speed, 40.0) + 0.15)
	active_minigame = mg
	var host: Node = get_tree().current_scene if (get_tree() != null and get_tree().current_scene != null) else get_parent()
	if host != null:
		host.add_child(mg)
	else:
		add_child(mg)

	mg.deflect_succeeded.connect(_on_qte_deflect_succeeded)
	mg.minigame_completed.connect(_on_qte_completed)
	mg.start_minigame(MinigameCombat.MinigameType.SONIC_REFLEX, &"attack_sonic", "ESPORO! Use o SOM do Pipop para rebater!")
	reflex_qte_started.emit(mg)
	return mg

func _on_pipop_sonic_started() -> void:
	if is_reflected:
		return
	if is_instance_valid(active_minigame) and active_minigame.is_active:
		active_minigame.trigger_player_input()
	elif get_tree() != null:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and global_position.distance_to(player.global_position) <= reflex_trigger_distance + 20.0:
			deflect_back()

func _on_qte_deflect_succeeded() -> void:
	deflect_back()

func _on_qte_completed(_success: bool, _data: Dictionary) -> void:
	active_minigame = null

func deflect_back() -> void:
	if is_reflected:
		return
	is_reflected = true
	_age = 0.0
	speed = reflected_speed
	damage = reflected_damage
	collision_mask = 6 # Enemies (4) e Mundo (2)
	if is_instance_valid(source_enemy):
		direction = global_position.direction_to(source_enemy.global_position + Vector2(0, -10))
	if direction == Vector2.ZERO:
		direction = -direction if direction != Vector2.ZERO else Vector2.RIGHT
	elif not is_instance_valid(source_enemy):
		direction = -direction.normalized()
	if visual != null:
		visual.color = Color(0.95, 0.38, 0.94, 1.0)
	if is_instance_valid(active_minigame) and not active_minigame.is_resolved:
		active_minigame.set_marker_position((active_minigame.reflex_window_start + active_minigame.reflex_window_end) * 0.5)
		active_minigame.trigger_player_input()
	spore_reflected.emit(self)

func _on_body_entered(body: Node2D) -> void:
	if is_reflected:
		if body.is_in_group("enemies"):
			var hc: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
			if hc != null:
				hc.take_damage(damage)
			_cleanup_qte()
			queue_free()
		elif not body.is_in_group("player"):
			_cleanup_qte()
			queue_free()
		return

	if body.is_in_group("player"):
		var hurtbox: Hurtbox = body.get_node_or_null("Hurtbox") as Hurtbox
		if hurtbox != null:
			hurtbox.receive_hit(damage, 0, direction.normalized() * 120.0, 0.15)
	_cleanup_qte()
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not is_reflected and area is Hitbox and (area as Hitbox).damage_type == Hitbox.DamageType.SONIC:
		deflect_back()
		return

	if is_reflected:
		if area is Hurtbox and area.get_parent() != null and area.get_parent().is_in_group("enemies"):
			(area as Hurtbox).receive_hit(damage, Hitbox.DamageType.SONIC, direction.normalized() * 160.0, 0.25)
			_cleanup_qte()
			queue_free()
		return

	if area is Hurtbox and area.get_parent() != null and area.get_parent().is_in_group("player"):
		(area as Hurtbox).receive_hit(damage, 0, direction.normalized() * 120.0, 0.15)
		_cleanup_qte()
		queue_free()

func _cleanup_qte() -> void:
	if is_instance_valid(active_minigame) and not active_minigame.is_resolved:
		active_minigame.queue_free()
	active_minigame = null
