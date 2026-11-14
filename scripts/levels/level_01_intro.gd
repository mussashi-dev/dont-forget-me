class_name Level01Intro
extends CampaignLevel
## Fase 1 da campanha: herda toda a construção e fluxo de CampaignLevel (level_number = 1).

func _ready() -> void:
	level_number = 1
	super._ready()

