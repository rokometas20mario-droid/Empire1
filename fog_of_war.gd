extends Node2D

# Klasična megla vojne v treh stanjih:
# 0 = še neraziskano, 1 = raziskano, 2 = trenutno vidno.
# Maska je namenoma precej manjša od sveta in se linearno raztegne čez mapo.
# Tako so robovi mehki, posodobitev pa ostane lahka tudi na telefonu.
const WORLD_RECT := Rect2(0.0, 0.0, 12800.0, 6500.0)
const GRID_WIDTH := 256
const GRID_HEIGHT := 130
const UPDATE_INTERVAL := 0.18
const ALPHA_UNEXPLORED := 238
const ALPHA_EXPLORED := 148
const EDGE_FEATHER := 135.0
const EDGE_NOISE_AMOUNT := 52.0

var _explored := PackedByteArray()
var _visible_now := PackedByteArray()
var _visible_strength := PackedFloat32Array()
var _mask_pixels := PackedByteArray()
var _mask_image: Image
var _mask_texture: ImageTexture
var _mask_sprite: Sprite2D
var _update_timer := 0.0
var _has_updated := false


func _ready() -> void:
	name = "FogOfWar"
	z_index = 3000
	z_as_relative = false
	_explored.resize(GRID_WIDTH * GRID_HEIGHT)
	_visible_now.resize(GRID_WIDTH * GRID_HEIGHT)
	_visible_strength.resize(GRID_WIDTH * GRID_HEIGHT)
	_explored.fill(0)
	_visible_now.fill(0)
	_visible_strength.fill(0.0)
	_mask_pixels.resize(GRID_WIDTH * GRID_HEIGHT * 4)
	_mask_pixels.fill(0)

	_mask_image = Image.create(GRID_WIDTH, GRID_HEIGHT, false, Image.FORMAT_RGBA8)
	_mask_image.fill(Color(0.0, 0.0, 0.0, float(ALPHA_UNEXPLORED) / 255.0))
	_mask_texture = ImageTexture.create_from_image(_mask_image)

	_mask_sprite = Sprite2D.new()
	_mask_sprite.name = "Maska"
	_mask_sprite.centered = false
	_mask_sprite.position = WORLD_RECT.position
	_mask_sprite.scale = Vector2(
		WORLD_RECT.size.x / float(GRID_WIDTH),
		WORLD_RECT.size.y / float(GRID_HEIGHT)
	)
	_mask_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mask_sprite.texture = _mask_texture
	add_child(_mask_sprite)

	# Starš Main v svojem _ready() najprej naloži shranjeno igro. Odloženi
	# prvi izračun zato upošteva tudi obnovljene enote in raziskano območje.
	call_deferred("force_update")


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		force_update()


func force_update() -> void:
	if not is_inside_tree():
		return
	_visible_now.fill(0)
	_visible_strength.fill(0.0)
	for source in _vision_sources():
		_reveal_circle(source[0], source[1])
	_rebuild_mask()
	_update_enemy_visibility()
	_has_updated = true


func _vision_sources() -> Array:
	var sources: Array = []
	var already_added: Dictionary = {}

	var main_base = get_tree().get_first_node_in_group("glavna_hisa")
	if is_instance_valid(main_base):
		_add_source(sources, already_added, main_base, 700.0)

	for worker in get_tree().get_nodes_in_group("delavci"):
		_add_source(sources, already_added, worker, 430.0)

	for unit in get_tree().get_nodes_in_group("enote"):
		var radius := 490.0
		if "tip_animacije" in unit and str(unit.tip_animacije) == "poglavar":
			radius = 580.0
		_add_source(sources, already_added, unit, radius)

	for building in get_tree().get_nodes_in_group("zgradbe"):
		var radius := 380.0
		if "tip_zgradbe" in building:
			match str(building.tip_zgradbe):
				"stolp":
					radius = 800.0
				"obzidje", "vrata":
					radius = 220.0
				"polje":
					radius = 260.0
		_add_source(sources, already_added, building, radius)

	return sources


func _add_source(sources: Array, already_added: Dictionary, source, radius: float) -> void:
	if not is_instance_valid(source) or not source is Node2D:
		return
	var id: int = source.get_instance_id()
	if already_added.has(id):
		return
	already_added[id] = true
	sources.append([source.global_position, radius])


func _reveal_circle(world_position: Vector2, radius: float) -> void:
	var center := _world_to_cell(world_position)
	var outer_radius := radius + EDGE_FEATHER + EDGE_NOISE_AMOUNT
	var radius_x := ceili(outer_radius * GRID_WIDTH / WORLD_RECT.size.x) + 1
	var radius_y := ceili(outer_radius * GRID_HEIGHT / WORLD_RECT.size.y) + 1
	var min_x := maxi(0, center.x - radius_x)
	var max_x := mini(GRID_WIDTH - 1, center.x + radius_x)
	var min_y := maxi(0, center.y - radius_y)
	var max_y := mini(GRID_HEIGHT - 1, center.y + radius_y)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell_world := Vector2(
				WORLD_RECT.position.x + (float(x) + 0.5) * WORLD_RECT.size.x / GRID_WIDTH,
				WORLD_RECT.position.y + (float(y) + 0.5) * WORLD_RECT.size.y / GRID_HEIGHT
			)
			var distance := cell_world.distance_to(world_position)
			var organic_radius := radius + _organic_edge_noise(cell_world) * EDGE_NOISE_AMOUNT
			var strength := clampf(
				(organic_radius + EDGE_FEATHER - distance) / (EDGE_FEATHER * 2.0),
				0.0,
				1.0
			)
			# Gladek S-prehod odstrani vidne stopnice med celicami. Rahla
			# nepravilnost polmera prepreči popoln računalniški krog.
			strength = strength * strength * (3.0 - 2.0 * strength)
			if strength > 0.0:
				var index := y * GRID_WIDTH + x
				_visible_strength[index] = maxf(_visible_strength[index], strength)
				_explored[index] = maxi(int(_explored[index]), roundi(strength * 255.0))
			if distance <= organic_radius:
				var index := y * GRID_WIDTH + x
				_visible_now[index] = 1


func _organic_edge_noise(world_position: Vector2) -> float:
	# Tri zelo počasni valovi ustvarijo miren, naraven rob. Vrednost je
	# popolnoma določljiva iz položaja, zato megla med posodobitvami ne trepeta.
	return (
		sin(world_position.x * 0.0077 + sin(world_position.y * 0.0034) * 1.35) * 0.46
		+ sin(world_position.y * 0.0091 - world_position.x * 0.0042) * 0.34
		+ sin((world_position.x + world_position.y) * 0.0165) * 0.20
	)


func _rebuild_mask() -> void:
	for index in range(GRID_WIDTH * GRID_HEIGHT):
		var explored_amount := float(_explored[index]) / 255.0
		var base_alpha := lerpf(float(ALPHA_UNEXPLORED), float(ALPHA_EXPLORED), explored_amount)
		var alpha := roundi(base_alpha * (1.0 - _visible_strength[index]))
		var pixel_index := index * 4
		_mask_pixels[pixel_index] = 0
		_mask_pixels[pixel_index + 1] = 0
		_mask_pixels[pixel_index + 2] = 0
		_mask_pixels[pixel_index + 3] = alpha

	_mask_image.set_data(GRID_WIDTH, GRID_HEIGHT, false, Image.FORMAT_RGBA8, _mask_pixels)
	_mask_texture.update(_mask_image)


func _update_enemy_visibility() -> void:
	for enemy in get_tree().get_nodes_in_group("sovraznik"):
		if not is_instance_valid(enemy) or not enemy is CanvasItem or not enemy is Node2D:
			continue
		# Nepremične AI-stavbe ostanejo kot zadnja znana lokacija na že
		# raziskanem terenu. Enote, delavci in živali izginejo takoj, ko jih
		# nobena igralčeva enota ali stavba več ne vidi.
		var is_building := enemy.is_in_group("ai_zgradbe") or enemy.is_in_group("ai_baza")
		enemy.visible = is_explored(enemy.global_position) if is_building else is_visible_now(enemy.global_position)


func _world_to_cell(world_position: Vector2) -> Vector2i:
	var relative := world_position - WORLD_RECT.position
	return Vector2i(
		clampi(floori(relative.x / WORLD_RECT.size.x * GRID_WIDTH), 0, GRID_WIDTH - 1),
		clampi(floori(relative.y / WORLD_RECT.size.y * GRID_HEIGHT), 0, GRID_HEIGHT - 1)
	)


func is_visible_now(world_position: Vector2) -> bool:
	if not WORLD_RECT.has_point(world_position):
		return false
	var cell := _world_to_cell(world_position)
	return _visible_now[cell.y * GRID_WIDTH + cell.x] != 0


func is_explored(world_position: Vector2) -> bool:
	if not WORLD_RECT.has_point(world_position):
		return false
	var cell := _world_to_cell(world_position)
	return _explored[cell.y * GRID_WIDTH + cell.x] >= 32


func visibility_strength_at(world_position: Vector2) -> float:
	if not WORLD_RECT.has_point(world_position):
		return 0.0
	var cell := _world_to_cell(world_position)
	return _visible_strength[cell.y * GRID_WIDTH + cell.x]


func explored_strength_at(world_position: Vector2) -> float:
	if not WORLD_RECT.has_point(world_position):
		return 0.0
	var cell := _world_to_cell(world_position)
	return float(_explored[cell.y * GRID_WIDTH + cell.x]) / 255.0


func state_at(world_position: Vector2) -> int:
	if is_visible_now(world_position):
		return 2
	if is_explored(world_position):
		return 1
	return 0


func export_explored_base64() -> String:
	return Marshalls.raw_to_base64(_explored)


func restore_explored_base64(encoded: String) -> void:
	if encoded.is_empty():
		return
	var restored := Marshalls.base64_to_raw(encoded)
	if restored.size() != GRID_WIDTH * GRID_HEIGHT:
		push_warning("Shranjena megla vojne ima napačno velikost in je ne bom uporabil.")
		return
	# Prva različica megle je shranjevala samo 0/1. Pretvorba ohrani stare
	# shranjene igre in jim dodeli polno raziskano vrednost.
	var old_binary_format := true
	for value in restored:
		if int(value) > 1:
			old_binary_format = false
			break
	if old_binary_format:
		for index in range(restored.size()):
			if restored[index] != 0:
				restored[index] = 255
	_explored = restored
	force_update()


func has_updated() -> bool:
	return _has_updated
