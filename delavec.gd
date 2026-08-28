extends CharacterBody2D

const ANIMACIJE = preload("res://delavec_animacije.gd")

@export var speed: float = 125.0
var osnovna_hitrost: float = 125.0
var nosilnost: int = 10
@export var max_hp: int = 30
@export var je_ai: bool = false

var hp: int
var target_position: Vector2 = Vector2.ZERO
var target_resource = null
var is_selected: bool = false

var state: String = "IDLE"

var mining_timer: float = 0.0
var max_mining_time: float = 2.0

var carried_amount: int = 0
var carried_type: String = "WOOD"

var cilj_oddaje: Node2D = null
var nav_agent: NavigationAgent2D

var repair_target = null
var repair_timer: float = 0.0
var repair_cooldown: float = 1.0
var repair_amount: int = 10
var repair_range: float = 40.0

var gradnja_target = null
var gradnja_timer_delavec: float = 0.0
var gradnja_cooldown: float = 1.0
var gradnja_kolicina: float = 1.0
var gradnja_range: float = 40.0
var _gradi_napis: Label = null

var hunt_target = null
var hunt_timer: float = 0.0
var hunt_cooldown: float = 1.0
var hunt_damage: int = 8
var hunt_range: float = 40.0
var hunt_animating: bool = false

var smer_animacije: String = "jug"
var izbirna_puscica: Polygon2D = null
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var kosara_sprite: Sprite2D = $Kosara


func ukazi_lov(tarca):
	hunt_target = tarca
	state = "HUNTING"
	hunt_timer = 0.0
	hunt_animating = false


func ukazi_popravilo(tarca):
	repair_target = tarca
	state = "REPAIRING"
	repair_timer = 0.0


func ukazi_gradnja(tarca):
	gradnja_target = tarca
	state = "GRADI"
	gradnja_timer_delavec = 0.0


func _oddaj_surovino():
	if je_ai:
		get_tree().call_group("ai_controller", "add_ai_resource", carried_type, carried_amount)
	else:
		get_tree().call_group("main_script", "add_resource", carried_type, carried_amount)


func _ready():
	osnovna_hitrost = speed
	ANIMACIJE.pripravi(anim_sprite)
	kosara_sprite.visible = false
	kosara_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_posodobi_kosaro(smer_animacije, false)

	nav_agent = NavigationAgent2D.new()
	nav_agent.name = "NavAgent"
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = 6.0
	nav_agent.avoidance_enabled = false
	add_child(nav_agent)

	if je_ai:
		add_to_group("ai_delavci")
		add_to_group("sovraznik")
		modulate = Color(1.0, 0.55, 0.55, 1.0)
		collision_mask = 1 | 32
	else:
		add_to_group("delavci")
		collision_mask = 1
	if has_node("VisionLight"):
		$VisionLight.enabled = false
	target_position = global_position
	input_pickable = true
	hp = max_hp
	_ustvari_izbirno_puscico()
	call_deferred("_prevzemi_nadgradnje")


func _ustvari_izbirno_puscico() -> void:
	izbirna_puscica = Polygon2D.new()
	izbirna_puscica.name = "IzbirnaPuscica"
	izbirna_puscica.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(0, 3)])
	izbirna_puscica.color = Color(1.0, 0.86, 0.12, 1.0)
	izbirna_puscica.position = Vector2(0, -104)
	izbirna_puscica.z_index = 20
	izbirna_puscica.visible = false
	add_child(izbirna_puscica)

func uporabi_nadgradnjo_baze(nivo: int) -> void:
	speed = osnovna_hitrost * (1.0 + 0.12 * (nivo - 1))
	nosilnost = 10 + 5 * (nivo - 1)

func _prevzemi_nadgradnje() -> void:
	if je_ai:
		var ai = get_tree().get_first_node_in_group("ai_controller")
		if is_instance_valid(ai) and ai.has_method("ai_nivo_baze"):
			uporabi_nadgradnjo_baze(ai.ai_nivo_baze())
		return
	var main = get_tree().get_first_node_in_group("main_script")
	if is_instance_valid(main): uporabi_nadgradnjo_baze(main.glavna_stavba_level)


func take_damage(amount: int, _napadalec = null):
	hp -= amount
	if hp < 0:
		hp = 0
	print(name, " (delavec) HP: ", hp, "/", max_hp)
	if hp <= 0:
		if not je_ai:
			get_tree().call_group("main_script", "delavec_umrl")
		queue_free()


func set_selected(value: bool):
	is_selected = value
	# Puščica je jasnejša od zelenega barvanja celotnega delavca in ne spremeni
	# barv njegove grafike ali napolnjene košare.
	modulate = Color(1.0, 0.55, 0.55, 1.0) if je_ai else Color.WHITE
	if is_instance_valid(izbirna_puscica):
		izbirna_puscica.visible = value and not je_ai


func start_mining(res_node):
	print("UKAZ ZA PREMIK:", res_node.name)

	target_resource = res_node
	target_position = res_node.global_position
	state = "WALKING_TO_RES"


func najdi_cilj_oddaje():

	var najblizji = null
	var najkrajsa = INF

	var objekti = []

	if je_ai:
		var iskani_tip = {
			"WOOD": "drvarnica",
			"STONE": "kamnolom",
			"GOLD": "rudnik",
			"FOOD": "kmetija"
		}.get(carried_type, "")
		for stavba in get_tree().get_nodes_in_group("ai_zgradbe"):
			if not is_instance_valid(stavba) or not ("tip_zgradbe" in stavba):
				continue
			if str(stavba.tip_zgradbe) != iskani_tip:
				continue
			if "v_gradnji" in stavba and bool(stavba.v_gradnji):
				continue
			objekti.append(stavba)
		objekti += get_tree().get_nodes_in_group("ai_baza")

	else:

		var skupina_za_tip = {
			"WOOD": "drvarnica",
			"STONE": "kamnolom",
			"GOLD": "rudnik",
			"FOOD": "kmetija"
		}

		if carried_type in skupina_za_tip:
			objekti += get_tree().get_nodes_in_group(skupina_za_tip[carried_type])

		objekti += get_tree().get_nodes_in_group("glavna_hisa")


	for o in objekti:

		if "v_gradnji" in o and o.v_gradnji:
			continue

		var razdalja = global_position.distance_to(o.global_position)

		if razdalja < najkrajsa:
			najkrajsa = razdalja
			najblizji = o


	return najblizji


func _doseg_vira() -> float:
	if is_instance_valid(target_resource) and "interaction_range" in target_resource:
		return float(target_resource.interaction_range)
	return 55.0


func _doseg_oddaje(stavba: Node2D) -> float:
	if stavba == null:
		return 30.0
	if stavba.is_in_group("glavna_hisa") or stavba.is_in_group("ai_baza"):
		return 40.0
	return 26.0


# Najbližja točka na robu kolizijske oblike stavbe (namesto njenega središča),
# gledano iz pozicije "iz_pozicije". Podpira CircleShape2D (npr. glavna stavba)
# in RectangleShape2D (drvarnica, kamnolom, rudnik, kmetija).
func _rob_stavbe(stavba: Node2D, iz_pozicije: Vector2) -> Vector2:
	if stavba == null:
		return iz_pozicije

	var oblika := _najdi_kolizijsko_obliko(stavba)
	if oblika == null or oblika.shape == null:
		return stavba.global_position

	var sredina: Vector2 = oblika.global_position
	var lokalno: Vector2 = iz_pozicije - sredina
	var shape = oblika.shape

	# POMEMBNO: shape.radius/size je LOKALNA vrednost oblike - če ima kateri od
	# staršev (npr. GlavnaHisa/AIBaza Sprite2D, scale=1.6) neenotsko skalo, je
	# DEJANSKA (globalna) kolizija ustrezno večja. Brez upoštevanja global_scale
	# smo cilj oddaje postavili globoko ZNOTRAJ prave ovire (npr. polmer 90
	# namesto dejanskih 144), kar je bilo nedosegljivo prek navigacijske mreže
	# in je delavce (predvsem AI) trajno "zataknilo" tik pred bazo.
	var globalna_skala: Vector2 = oblika.global_scale

	if shape is CircleShape2D:
		var polmer_globalno: float = shape.radius * globalna_skala.x
		if lokalno.length() < 0.001:
			return sredina
		return sredina + lokalno.normalized() * polmer_globalno

	if shape is RectangleShape2D:
		var pol: Vector2 = shape.size * 0.5 * globalna_skala
		var priklenjeno := Vector2(
			clamp(lokalno.x, -pol.x, pol.x),
			clamp(lokalno.y, -pol.y, pol.y)
		)
		if abs(lokalno.x) <= pol.x and abs(lokalno.y) <= pol.y:
			# Delavec je (redko) znotraj oboda - potisnemo ga na najbližji rob.
			var do_desno = pol.x - lokalno.x
			var do_levo = pol.x + lokalno.x
			var do_spodaj = pol.y - lokalno.y
			var do_zgoraj = pol.y + lokalno.y
			var najmanjsi = min(do_desno, min(do_levo, min(do_spodaj, do_zgoraj)))
			if najmanjsi == do_desno:
				priklenjeno.x = pol.x
			elif najmanjsi == do_levo:
				priklenjeno.x = -pol.x
			elif najmanjsi == do_spodaj:
				priklenjeno.y = pol.y
			else:
				priklenjeno.y = -pol.y
		return sredina + priklenjeno

	return sredina


func _najdi_kolizijsko_obliko(stavba: Node2D) -> CollisionShape2D:
	if stavba.has_node("Ovira/OviraShape"):
		return stavba.get_node("Ovira/OviraShape")
	if stavba.has_node("CollisionShape2D"):
		return stavba.get_node("CollisionShape2D")
	return null


# Premik po pravi poti prek NavigationAgent2D (namesto ravne črte + obračanja
# ob trku), ki jo NavigationServer izračuna okoli vseh statičnih ovir na mapi.
func _premakni_proti(cilj: Vector2, delta: float):
	var do_cilja = cilj - global_position
	if do_cilja.length_squared() < 1.0:
		velocity = Vector2.ZERO
		return

	if nav_agent.target_position.distance_to(cilj) > 1.0:
		# OPOMBA: cilja NE lepimo ročno na navigacijsko mrežo (poskusili smo z
		# NavigationServer2D.map_get_closest_point, a se je izkazalo za slabo -
		# cilji tik ob robu stavbe (glej _rob_stavbe) so vedno znotraj varnostnega
		# pasu ovire (agent_radius), zato je "najbližja" točka na mreži znala biti
		# daleč stran za vogalom, delavec pa se je tam trajno zataknil).
		# NavigationAgent2D sam že dovolj dobro obravnava cilj tik ob robu ovire.
		nav_agent.target_position = cilj

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var naslednja_tocka = nav_agent.get_next_path_position()
	var smer = naslednja_tocka - global_position
	if smer.length_squared() < 0.01:
		velocity = Vector2.ZERO
		return

	velocity = smer.normalized() * speed
	move_and_slide()


func _physics_process(delta):

	# Če je bil delavcu medtem ukazano kaj drugega (npr. igralec ga je
	# preusmeril na rudarjenje, medtem ko je še gradil), se stanje spremeni
	# stran od "GRADI" NEPOSREDNO prek ukazi_*/start_mining, ne skozi GRADI
	# vejo spodaj - brez tega bi napis "dela" ostal viden v nedogled.
	if state != "GRADI" and _gradi_napis != null and is_instance_valid(_gradi_napis) and _gradi_napis.visible:
		_skrij_gradi_napis()

	if is_instance_valid(target_resource) and state == "WALKING_TO_RES":
		target_position = target_resource.global_position


	var dist = global_position.distance_to(target_position)


	if state == "WALKING_TO_RES":

		if dist > _doseg_vira():

			_premakni_proti(target_position, delta)

		else:

			velocity = Vector2.ZERO

			if is_instance_valid(target_resource):
				state = "MINING"
				mining_timer = 0
			else:
				state = "IDLE"


	elif state == "MINING":

		velocity = Vector2.ZERO
		mining_timer += delta


		if mining_timer >= max_mining_time:

			mining_timer = 0


			if is_instance_valid(target_resource):

				var harvested = target_resource.harvest(nosilnost)

				carried_type = _resource_type_to_string(harvested["type"])
				carried_amount = harvested["amount"]


			cilj_oddaje = najdi_cilj_oddaje()


			if cilj_oddaje:

				target_position = _rob_stavbe(cilj_oddaje, global_position)
				state = "WALKING_TO_BASE"


			else:

				_oddaj_surovino()
				carried_amount = 0



	elif state == "WALKING_TO_BASE":

		if is_instance_valid(cilj_oddaje):
			target_position = _rob_stavbe(cilj_oddaje, global_position)


		dist = global_position.distance_to(target_position)


		if dist > _doseg_oddaje(cilj_oddaje):

			_premakni_proti(target_position, delta)


		else:

			velocity = Vector2.ZERO


			if carried_amount > 0:

				_oddaj_surovino()
				carried_amount = 0


			if is_instance_valid(target_resource):

				target_position = target_resource.global_position
				state = "WALKING_TO_RES"

			else:

				state = "IDLE"


	elif state == "REPAIRING":

		if not is_instance_valid(repair_target) or repair_target.hp >= repair_target.max_hp:

			velocity = Vector2.ZERO
			state = "IDLE"
			repair_target = null

		else:

			# POMEMBNO: cilj je rob kolizije zgradbe, ne njeno središče - odkar
			# imajo zgradbe pravo kolizijo (Ovira), bi bil center pri večjih
			# zgradbah (radij > repair_range) fizično nedosegljiv in bi se
			# delavec za vedno "zaletaval" vanjo, ne da bi kdaj začel popravljati.
			var tocka_r = _rob_stavbe(repair_target, global_position)
			var dist_r = global_position.distance_to(tocka_r)

			if dist_r > repair_range:
				_premakni_proti(tocka_r, delta)
			else:
				velocity = Vector2.ZERO
				repair_timer += delta
				if repair_timer >= repair_cooldown:
					repair_timer = 0.0
					repair_target.repair(repair_amount)

	elif state == "HUNTING":

		if not is_instance_valid(hunt_target):

			velocity = Vector2.ZERO
			state = "IDLE"
			hunt_target = null
			hunt_animating = false

		elif "mrtva" in hunt_target and bool(hunt_target.mrtva):
			var mrtvo_telo = hunt_target
			hunt_target = null
			hunt_animating = false
			start_mining(mrtvo_telo)

		else:

			var dist_h = global_position.distance_to(hunt_target.global_position)
			if hunt_target.has_method("bojni_polmer"):
				dist_h = maxf(0.0, dist_h - float(hunt_target.bojni_polmer()))

			if dist_h > hunt_range:
				hunt_animating = false
				_premakni_proti(hunt_target.global_position, delta)
			else:
				velocity = Vector2.ZERO
				hunt_timer += delta
				hunt_animating = hunt_timer >= maxf(0.0, hunt_cooldown - 0.5)
				if hunt_timer >= hunt_cooldown:
					hunt_timer = 0.0
					hunt_target.take_damage(hunt_damage, self)
					if is_instance_valid(hunt_target) and "mrtva" in hunt_target and bool(hunt_target.mrtva):
						var telo = hunt_target
						hunt_target = null
						hunt_animating = false
						start_mining(telo)

	elif state == "GRADI":

		if not is_instance_valid(gradnja_target) or not gradnja_target.v_gradnji:

			velocity = Vector2.ZERO
			state = "IDLE"
			gradnja_target = null
			_skrij_gradi_napis()

		else:

			# Glej opombo pri REPAIRING - isti razlog (rob kolizije, ne središče).
			var tocka_g = _rob_stavbe(gradnja_target, global_position)
			var dist_g = global_position.distance_to(tocka_g)

			if dist_g > gradnja_range:
				_premakni_proti(tocka_g, delta)
				_skrij_gradi_napis()
			else:
				velocity = Vector2.ZERO
				gradnja_timer_delavec += delta
				if gradnja_timer_delavec >= gradnja_cooldown:
					gradnja_timer_delavec = 0.0
					gradnja_target.gradi(gradnja_kolicina)
				_posodobi_gradi_napis()

	_posodobi_animacijo()
	if is_instance_valid(izbirna_puscica) and izbirna_puscica.visible:
		izbirna_puscica.position.y = -104.0 + sin(Time.get_ticks_msec() * 0.006) * 3.0


func _posodobi_animacijo() -> void:
	# Med hojo ima smer gibanja prednost. Ko delavec miruje in dela, se obrne
	# proti predmetu, na katerem trenutno dela.
	if velocity.length_squared() > 1.0:
		smer_animacije = ANIMACIJE.smer_iz_vektorja(velocity, smer_animacije)
	else:
		var pogled := Vector2.ZERO
		match state:
			"MINING":
				if is_instance_valid(target_resource):
					pogled = target_resource.global_position - global_position
			"GRADI":
				if is_instance_valid(gradnja_target):
					pogled = gradnja_target.global_position - global_position
			"REPAIRING":
				if is_instance_valid(repair_target):
					pogled = repair_target.global_position - global_position
			"HUNTING":
				if is_instance_valid(hunt_target):
					pogled = hunt_target.global_position - global_position
		if pogled.length_squared() > 0.01:
			smer_animacije = ANIMACIJE.smer_iz_vektorja(pogled, smer_animacije)

	var vrsta := "idle"
	if velocity.length_squared() > 1.0:
		vrsta = "nosi" if state == "WALKING_TO_BASE" and carried_amount > 0 else "walk"
	else:
		match state:
			"MINING":
				vrsta = "orodje"
			"HUNTING":
				vrsta = "lov" if hunt_animating else "idle"
			"GRADI", "REPAIRING":
				vrsta = "gradnja"

	ANIMACIJE.predvajaj(anim_sprite, vrsta, smer_animacije)
	_posodobi_kosaro(smer_animacije, carried_amount > 0)


func _posodobi_kosaro(smer: String, ima_tovor: bool) -> void:
	# Košare ni nikoli med mirovanjem, rudarjenjem ali gradnjo. Pokaže se
	# samo, ko ima delavec v rokah dejansko nabrano surovino za oddajo.
	kosara_sprite.visible = ima_tovor
	if not ima_tovor:
		return

	var nova_kosara: AtlasTexture = ANIMACIJE.tekstura_kosare(smer, carried_type)
	if kosara_sprite.texture != nova_kosara:
		kosara_sprite.texture = nova_kosara

	# Vsaka smer ima svoj že napolnjen koš. Pri pogledu od zadaj ga narišemo
	# pred telesom, pri sprednjem in bočnem pogledu pa za telesom. Ker je vsebina
	# del iste slike, ves koš med korakom ostane trdno pritrjen na ramena.
	var nastavitve := {
		"jug": {"polozaj": Vector2(0.0, -50.0), "z": 8},
		"sever": {"polozaj": Vector2(0.0, -50.0), "z": 12},
		"vzhod": {"polozaj": Vector2(-13.0, -49.0), "z": 8},
		"zahod": {"polozaj": Vector2(13.0, -49.0), "z": 8},
	}
	var nastavitev: Dictionary = nastavitve.get(smer, nastavitve["jug"])
	var korak_y: float = anim_sprite.position.y - ANIMACIJE.OSNOVNI_ODMIK_Y
	kosara_sprite.position = (nastavitev["polozaj"] as Vector2) + Vector2(0.0, korak_y)
	kosara_sprite.z_index = int(nastavitev["z"])
	kosara_sprite.scale = Vector2.ONE * 0.18



# Napis "🔨 dela (Xs)" nad delavčevo glavo, dokler dejansko gradi (v dosegu,
# ne samo na poti tja) - uporabnik je izrecno želel jasno, vidno povratno
# informacijo, KDO gradi in KOLIKO časa še traja, namesto prejšnjega
# postopnega "razkrivanja" same zgradbe.
func _posodobi_gradi_napis() -> void:
	if _gradi_napis == null or not is_instance_valid(_gradi_napis):
		_gradi_napis = Label.new()
		_gradi_napis.add_theme_font_size_override("font_size", 15)
		_gradi_napis.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		_gradi_napis.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_gradi_napis.add_theme_constant_override("outline_size", 4)
		_gradi_napis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_gradi_napis.position = Vector2(-55, -112)
		_gradi_napis.size = Vector2(110, 20)
		_gradi_napis.z_index = 20
		add_child(_gradi_napis)

	_gradi_napis.visible = true

	if is_instance_valid(gradnja_target) and "cas_gradnje" in gradnja_target and "gradnja_timer" in gradnja_target:
		var preostalo = int(ceil(max(0.0, gradnja_target.cas_gradnje - gradnja_target.gradnja_timer)))
		_gradi_napis.text = "🔨 dela (" + str(preostalo) + "s)"


func _skrij_gradi_napis() -> void:
	if _gradi_napis != null and is_instance_valid(_gradi_napis):
		_gradi_napis.visible = false


func _resource_type_to_string(type: int) -> String:
	match type:
		0:
			return "WOOD"
		1:
			return "STONE"
		2:
			return "GOLD"
		3:
			return "FOOD"
	return "WOOD"


func najdi_najblizje_drevo():

	var najblizje = null
	var razdalja = INF

	for drevo in get_tree().get_nodes_in_group("trees"):

		var d = global_position.distance_to(drevo.global_position)

		if d < razdalja:
			razdalja = d
			najblizje = drevo

	return najblizje
