extends "res://enota.gd"

@export var aura_range: float = 150.0
@export var aura_damage_bonus: int = 5


func _ready():
	super._ready()
	add_to_group("poveljniki")
