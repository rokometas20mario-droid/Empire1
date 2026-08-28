extends Area2D

enum ResourceType { WOOD, STONE, GOLD, FOOD }

@export var resource_type: ResourceType = ResourceType.WOOD
@export var resource_amount: int = 100
@export var interaction_range: float = 55.0

func harvest(amount: int) -> Dictionary:
	var harvested = min(amount, resource_amount)
	resource_amount -= harvested
	
	if resource_amount <= 0:
		queue_free() # Vir izgine, ko ga zmanjka
		
	return {"type": resource_type, "amount": harvested}
