extends Node2D

@export var max_hp: int = 300

var hp: int


func _ready():
	add_to_group("sovraznik")
	hp = max_hp
	if has_node("HPLabel"):
		$HPLabel.text = str(hp)


func take_damage(amount: int, _napadalec = null):
	hp -= amount
	if hp < 0:
		hp = 0
	if has_node("HPLabel"):
		$HPLabel.text = str(hp)
	print("Lutka HP: ", hp, "/", max_hp)
	if hp <= 0:
		print("Lutka uničena!")
		queue_free()
