class_name EncarteData
extends Resource
## Recurso de dados para Encartes (sistema de progressão por capacidade compartilhada).

enum Category {
	PHYSICAL,
	SONIC,
	DEFENSE,
	MOBILITY,
	UTILITY
}

@export var id: String = ""
@export var title: String = ""
@export var category: Category = Category.PHYSICAL
@export var capacity_cost: int = 1
@export var benefit_text: String = ""
@export var limitation_text: String = ""
@export_multiline var description: String = ""

# Modificadores multiplicativos (1.0 = neutro) e aditivos (0 = neutro)
@export var physical_damage_mult: float = 1.0
@export var physical_cooldown_mult: float = 1.0
@export var physical_reach_mult: float = 1.0

@export var sonic_damage_mult: float = 1.0
@export var sonic_cooldown_mult: float = 1.0
@export var sonic_range_mult: float = 1.0
@export var sonic_area_mult: float = 1.0
@export var sonic_spread_degrees: float = 0.0 # Precisão (0 = reto, >0 = desvio angular)

@export var move_speed_mult: float = 1.0
@export var dash_cooldown_mult: float = 1.0
@export var max_health_bonus: int = 0
@export var damage_taken_mult: float = 1.0
@export var enemy_detection_mult: float = 1.0
@export var interact_radius_mult: float = 1.0

static func category_to_string(cat: Category) -> String:
	match cat:
		Category.PHYSICAL: return "Físico"
		Category.SONIC: return "Sônico"
		Category.DEFENSE: return "Defesa"
		Category.MOBILITY: return "Mobilidade"
		Category.UTILITY: return "Utilidade"
	return "Desconhecido"
