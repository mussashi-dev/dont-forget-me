class_name BossProjectile
extends Area2D
## Projétil geométrico utilizado pelos Chefes (fios rastejantes, pulsos mecânicos, fragmentos de memória).

@export var speed: float = 165.0
@export var lifetime: float = 2.2
@export var damage: int = 16
@export var radius: float = 7.0
@export var projectile_color: Color = Color(0.95, 0.35, 0.55, 1.0)
@export var leaves_web_on_expire: bool = false

var direction: Vector2 = Vector2.DOWN
var _timer: float = 0.0
var _hitbox: Hitbox

func _ready() -> void:
	_timer = lifetime
	collision_layer = 0
	collision_mask = 2 # Paredes sólidas (2)

	body_entered.connect(_on_body_entered)

	var body_cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius * 0.8
	body_cs.shape = c
	add_child(body_cs)

	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2 # Hurtbox de Pablita (layer 2)
	_hitbox.damage = damage
	_hitbox.damage_type = Hitbox.DamageType.PHYSICAL
	_hitbox.knockback_force = 190.0
	_hitbox.stun_time = 0.2
	var h_cs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = radius
	h_cs.shape = hc
	_hitbox.add_child(h_cs)
	_hitbox.area_entered.connect(_on_hitbox_area_entered)
	add_child(_hitbox)
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_timer -= delta
	if _timer <= 0.0:
		_expire()

func _on_body_entered(_body: Node2D) -> void:
	_expire()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.owner is Pablita:
		_expire()

func _expire() -> void:
	if leaves_web_on_expire and get_tree() and get_tree().current_scene:
		var web := Area2D.new()
		web.global_position = global_position
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 22.0
		cs.shape = c
		web.add_child(cs)
		web.set_script(load("res://scripts/objects/web_slow_zone.gd"))
		get_tree().current_scene.add_child(web)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, projectile_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 14, Color.WHITE, 1.4)
