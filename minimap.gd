extends Control

@export var world_rect: Rect2 = Rect2(0, 0, 12800, 6500)

const FOG_TEXTURE_SIZE := 180
const REDRAW_INTERVAL := 0.12
const FOG_REFRESH_INTERVAL := 0.30
const MAP_CENTER := Vector2(6400.0, 3200.0)
const MAP_HALF_WIDTH := 6400.0
const MAP_HALF_HEIGHT := 3200.0
const LAND_HALF_WIDTH := 5888.0
const LAND_HALF_HEIGHT := 2944.0

var _redraw_timer := 0.0
var _fog_refresh_timer := 0.0
var _fog_texture: ImageTexture = null


func _ready() -> void:
	# Mini mapa mora ostati nad ostalimi elementi v spodnjem desnem kotu.
	z_index = 100
	_refresh_fog_texture()


func _process(delta: float) -> void:
	_redraw_timer += delta
	_fog_refresh_timer += delta
	if _fog_refresh_timer >= FOG_REFRESH_INTERVAL:
		_fog_refresh_timer = 0.0
		_refresh_fog_texture()
	if _redraw_timer >= REDRAW_INTERVAL:
		_redraw_timer = 0.0
		queue_redraw()


func _fog():
	# Minimap je otrok CanvasLayerja, zato lahko Main najdemo takoj tudi med
	# začetnim _ready(), še preden je dodan v skupino main_script.
	var main = get_parent().get_parent() if get_parent() != null else null
	if not is_instance_valid(main) or not main.has_node("FogOfWar"):
		main = get_tree().get_first_node_in_group("main_script")
	return main.get_node_or_null("FogOfWar") if is_instance_valid(main) else null


func _inside_diamond(world_position: Vector2, half_width: float, half_height: float) -> bool:
	return (
		absf(world_position.x - MAP_CENTER.x) / half_width
		+ absf(world_position.y - MAP_CENTER.y) / half_height
	) <= 1.0


func _refresh_fog_texture() -> void:
	var fog = _fog()
	var image := Image.create(FOG_TEXTURE_SIZE, FOG_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(FOG_TEXTURE_SIZE):
		for x in range(FOG_TEXTURE_SIZE):
			var world_position := Vector2(
				world_rect.position.x + (float(x) + 0.5) / FOG_TEXTURE_SIZE * world_rect.size.x,
				world_rect.position.y + (float(y) + 0.5) / FOG_TEXTURE_SIZE * world_rect.size.y
			)
			if not _inside_diamond(world_position, MAP_HALF_WIDTH, MAP_HALF_HEIGHT):
				continue

			var is_land := _inside_diamond(world_position, LAND_HALF_WIDTH, LAND_HALF_HEIGHT)
			var unexplored_color := Color(0.018, 0.022, 0.018, 1.0) if is_land else Color(0.012, 0.025, 0.036, 1.0)
			var explored_color := Color(0.12, 0.19, 0.09, 1.0) if is_land else Color(0.045, 0.12, 0.18, 1.0)
			var visible_color := Color(0.34, 0.57, 0.22, 1.0) if is_land else Color(0.08, 0.34, 0.50, 1.0)
			var color := unexplored_color

			# Tudi če se minimapa pripravi eno sličico pred meglo, se temna oblika
			# zemljevida vseeno izriše. Ko je megla na voljo, se razkriti deli
			# zanesljivo obarvajo v dve jasno ločeni svetlosti.
			if fog != null and fog.has_method("state_at"):
				var explored: float = float(fog.explored_strength_at(world_position)) if fog.has_method("explored_strength_at") else (1.0 if fog.is_explored(world_position) else 0.0)
				var visible: float = float(fog.visibility_strength_at(world_position)) if fog.has_method("visibility_strength_at") else (1.0 if fog.is_visible_now(world_position) else 0.0)
				color = unexplored_color.lerp(explored_color, clampf(explored, 0.0, 1.0))
				color = color.lerp(visible_color, clampf(visible, 0.0, 1.0))

			image.set_pixel(x, y, color)

	# Ustvarimo svežo teksturo, da je rezultat zanesljiv tudi po prvem
	# črnem okvirju med nalaganjem projekta. Prejšnja tekstura se na nekaterih
	# napravah ni vidno osvežila in minimapa je ostala prazna.
	_fog_texture = ImageTexture.create_from_image(image)
	queue_redraw()


func _svet_v_minimap(world_pos: Vector2) -> Vector2:
	var rel_x = (world_pos.x - world_rect.position.x) / world_rect.size.x
	var rel_y = (world_pos.y - world_rect.position.y) / world_rect.size.y
	return Vector2(rel_x * size.x, rel_y * size.y)


func _enemy_is_shown(enemy, fog) -> bool:
	if not is_instance_valid(enemy) or fog == null:
		return false
	var is_building: bool = enemy.is_in_group("ai_zgradbe") or enemy.is_in_group("ai_baza")
	return fog.is_explored(enemy.global_position) if is_building else fog.is_visible_now(enemy.global_position)


func _draw_marker(world_position: Vector2, radius: float, color: Color) -> void:
	var minimap_position := _svet_v_minimap(world_position)
	if not Rect2(Vector2.ZERO, size).has_point(minimap_position):
		return
	draw_circle(minimap_position, radius + 1.1, Color(0.0, 0.0, 0.0, 0.92))
	draw_circle(minimap_position, radius, color)


func _draw_building_marker(world_position: Vector2, half_size: float, color: Color) -> void:
	var minimap_position := _svet_v_minimap(world_position)
	if not Rect2(Vector2.ZERO, size).has_point(minimap_position):
		return
	var marker_rect := Rect2(minimap_position - Vector2.ONE * half_size, Vector2.ONE * half_size * 2.0)
	draw_rect(marker_rect.grow(1.2), Color(0.0, 0.0, 0.0, 0.94), true)
	draw_rect(marker_rect, color, true)


func _resource_color(resource) -> Color:
	# Vsi člani skupine "viri" imajo resource_type. Neposreden dostop je
	# varnejši za izris kot preverjanje lastnosti z operatorjem "in".
	var resource_type := int(resource.resource_type)
	match resource_type:
		1:
			return Color(0.78, 0.80, 0.83, 1.0)
		2:
			return Color(1.0, 0.78, 0.12, 1.0)
		3:
			return Color(1.0, 0.48, 0.18, 1.0)
	return Color(0.13, 0.58, 0.16, 1.0)


func _draw() -> void:
	var center := size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0
	draw_circle(center, radius, Color(0.01, 0.012, 0.01, 0.99))
	if _fog_texture != null:
		draw_texture_rect(_fog_texture, Rect2(Vector2.ZERO, size), false)

	# Nežen rob prave izometrične oblike mape ostane viden tudi na povsem
	# neraziskanem območju, zato minimapa nikoli ne izgleda prazna.
	var map_outline := PackedVector2Array([
		_svet_v_minimap(Vector2(MAP_CENTER.x, MAP_CENTER.y - MAP_HALF_HEIGHT)),
		_svet_v_minimap(Vector2(MAP_CENTER.x + MAP_HALF_WIDTH, MAP_CENTER.y)),
		_svet_v_minimap(Vector2(MAP_CENTER.x, MAP_CENTER.y + MAP_HALF_HEIGHT)),
		_svet_v_minimap(Vector2(MAP_CENTER.x - MAP_HALF_WIDTH, MAP_CENTER.y)),
		_svet_v_minimap(Vector2(MAP_CENTER.x, MAP_CENTER.y - MAP_HALF_HEIGHT))
	])
	draw_polyline(map_outline, Color(0.42, 0.48, 0.42, 0.72), 1.2, true)

	var fog = _fog()
	# Znani viri ostanejo na minimapi, kot v klasičnih RTS igrah. Tako karta
	# ni več prazna, ko ni enot neposredno ob robu trenutnega pogleda.
	if fog != null:
		for resource in get_tree().get_nodes_in_group("viri"):
			if is_instance_valid(resource) and resource is Node2D and fog.is_explored(resource.global_position):
				_draw_marker(resource.global_position, 1.7, _resource_color(resource))

	for building in get_tree().get_nodes_in_group("zgradbe"):
		if is_instance_valid(building):
			_draw_building_marker(building.global_position, 3.2, Color(0.22, 0.72, 1.0, 1.0))

	var main_base = get_tree().get_first_node_in_group("glavna_hisa")
	if is_instance_valid(main_base):
		_draw_building_marker(main_base.global_position, 5.0, Color(0.12, 0.82, 1.0, 1.0))

	for worker in get_tree().get_nodes_in_group("delavci"):
		if is_instance_valid(worker):
			_draw_marker(worker.global_position, 2.8, Color(0.32, 1.0, 0.32, 1.0))

	for unit in get_tree().get_nodes_in_group("enote"):
		if is_instance_valid(unit):
			_draw_marker(unit.global_position, 2.9, Color(0.90, 0.96, 1.0, 1.0))

	for enemy in get_tree().get_nodes_in_group("sovraznik"):
		if _enemy_is_shown(enemy, fog):
			var is_enemy_building: bool = enemy.is_in_group("ai_zgradbe") or enemy.is_in_group("ai_baza")
			if is_enemy_building:
				_draw_building_marker(enemy.global_position, 3.5, Color(1.0, 0.14, 0.10, 1.0))
			else:
				_draw_marker(enemy.global_position, 3.0, Color(1.0, 0.16, 0.12, 1.0))

	# Bel okvir pokaže, kateri del zemljevida trenutno gleda kamera.
	var camera := get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		var half_view := get_viewport_rect().size * 0.5 / camera.zoom
		var view_min := _svet_v_minimap(camera.global_position - half_view)
		var view_max := _svet_v_minimap(camera.global_position + half_view)
		draw_rect(Rect2(view_min, view_max - view_min), Color(1.0, 1.0, 1.0, 0.78), false, 1.4)

	draw_arc(center, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.6), 2.0)
