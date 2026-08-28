extends Area2D

@export var resource_amount: int = 100

func harvest(amount: int) -> int:
	var harvested = min(amount, resource_amount)
	resource_amount -= harvested
	if resource_amount <= 0:
		queue_free() # Drevo izgine, ko ponestane lesa
	return harvested
