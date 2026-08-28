extends CharacterBody2D

const ANIMACIJE = preload("res://zival_animacije.gd")
const PODATKI: Dictionary = {
	"jelen": {
		"ime": "Jelen", "max_hp": 40, "hrana": 60, "speed": 105.0,
		"damage": 0, "attack_range": 35.0, "attack_cooldown": 1.2,
		"kolizija": 0.80, "senca": Vector2(0.95, 0.75),
	},
	"divji_prasic": {
		"ime": "Divji prašič", "max_hp": 80, "hrana": 90, "speed": 78.0,
		"damage": 6, "attack_range": 40.0, "attack_cooldown": 1.3,
		"kolizija": 0.95, "senca": Vector2(1.05, 0.75),
	},
	"pragovedo": {
		"ime": "Pragovedo", "max_hp": 150, "hrana": 160, "speed": 58.0,
		"damage": 12, "attack_range": 50.0, "attack_cooldown": 1.6,
		"kolizija": 1.25, "senca": Vector2(1.40, 0.95),
	},
}

@export_enum("jelen", "divji_prasic", "pragovedo") var vrsta_zivali: String = "jelen"
@export var max_hp: int = 40
@export var damage: int = 0
@export var attack_range: float = 35.0
@export var attack_cooldown: float = 1.2
@export var hrana_ob_smrti: int = 60
@export var speed: float = 105.0
@export var zival_ime: String = "Jelen"

var hp: int
var wander_target: Vector2
var wander_timer: float = 0.0
var attack_target = null
var attack_timer: float = 0.0
var lovec = null
var smer_animacije: String = "jug"
var _zadnji_nav_cilj: Vector2 = Vector2(INF, INF)
var skrita_pod_krosnjo: bool = false
var _krosnja_timer: float = 0.0
var mrtva: bool = false
# Mrtva zival postane pravi vir hrane, vendar obdrzi svojo sliko telesa.
# Vrednost 3 je ResourceType.FOOD iz resource_node.gd.
var resource_type: int = 3
var resource_amount: int = 0
var interaction_range: float = 48.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var senca: Polygon2D = $Senca
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var nav_agent: NavigationAgent2D = $NavAgent


func _ready() -> void:
	add_to_group("zivali")
	add_to_group("sovraznik")
	_uporabi_podatke_vrste()
	hp = max_hp
	wander_target = global_position
	ANIMACIJE.pripravi(anim_sprite, vrsta_zivali)
	input_pickable = true
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = 12.0
	nav_agent.avoidance_enabled = false


func nastavi_vrsto(nova_vrsta: String) -> void:
	vrsta_zivali = nova_vrsta if nova_vrsta in PODATKI else "jelen"
	_uporabi_podatke_vrste()
	hp = max_hp
	if is_node_ready():
		ANIMACIJE.pripravi(anim_sprite, vrsta_zivali)


func _uporabi_podatke_vrste() -> void:
	if not vrsta_zivali in PODATKI:
		vrsta_zivali = "jelen"
	var podatki: Dictionary = PODATKI[vrsta_zivali]
	zival_ime = String(podatki["ime"])
	max_hp = int(podatki["max_hp"])
	hrana_ob_smrti = int(podatki["hrana"])
	speed = float(podatki["speed"])
	damage = int(podatki["damage"])
	attack_range = float(podatki["attack_range"])
	attack_cooldown = float(podatki["attack_cooldown"])
	if is_node_ready():
		collision_shape.scale = Vector2.ONE * float(podatki["kolizija"])
		var merilo_sence: Vector2 = podatki["senca"]
		senca.scale = merilo_sence


func _physics_process(delta: float) -> void:
	if mrtva:
		velocity = Vector2.ZERO
		return
	_krosnja_timer -= delta
	if _krosnja_timer <= 0.0:
		_krosnja_timer = 0.12
		_posodobi_skrivanje_pod_krosnjo()

	if damage > 0 and _preveri_napad(delta):
		_posodobi_animacijo()
		return

	if vrsta_zivali == "jelen" and _preveri_beg():
		_posodobi_animacijo()
		return

	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(3.0, 6.0)
		wander_target = global_position + Vector2(
			randf_range(-190.0, 190.0), randf_range(-190.0, 190.0)
		)

	if global_position.distance_to(wander_target) > 12.0:
		_premakni_proti(wander_target, speed * 0.48)
	else:
		velocity = Vector2.ZERO
	_posodobi_animacijo()


func _preveri_beg() -> bool:
	var nevarnost = lovec if is_instance_valid(lovec) else null
	var najblizje := 135.0
	for delavec in get_tree().get_nodes_in_group("delavci"):
		if not is_instance_valid(delavec):
			continue
		var razdalja := global_position.distance_to(delavec.global_position)
		if razdalja < najblizje:
			najblizje = razdalja
			nevarnost = delavec

	if not is_instance_valid(nevarnost):
		return false
	var razdalja_do_nevarnosti := global_position.distance_to(nevarnost.global_position)
	if razdalja_do_nevarnosti > 230.0:
		lovec = null
		return false
	var stran: Vector2 = global_position - nevarnost.global_position
	if stran.length_squared() < 0.01:
		stran = Vector2.RIGHT
	wander_target = global_position + stran.normalized() * 220.0
	_premakni_proti(wander_target, speed)
	return true


func _preveri_napad(delta: float) -> bool:
	if is_instance_valid(attack_target):
		var razdalja := global_position.distance_to(attack_target.global_position)
		if razdalja > 270.0:
			attack_target = null
		else:
			if razdalja <= attack_range:
				velocity = Vector2.ZERO
				smer_animacije = ANIMACIJE.smer_iz_vektorja(
					attack_target.global_position - global_position, smer_animacije
				)
				attack_timer += delta
				if attack_timer >= attack_cooldown:
					attack_timer = 0.0
					if attack_target.has_method("take_damage"):
						attack_target.take_damage(damage, self)
			else:
				_premakni_proti(attack_target.global_position, speed)
			return true

	attack_target = null
	for delavec in get_tree().get_nodes_in_group("delavci"):
		if not is_instance_valid(delavec):
			continue
		if global_position.distance_to(delavec.global_position) < 78.0:
			attack_target = delavec
			break
	return attack_target != null


func _premakni_proti(cilj: Vector2, hitrost: float) -> void:
	if _zadnji_nav_cilj.distance_to(cilj) > 8.0:
		nav_agent.target_position = cilj
		_zadnji_nav_cilj = cilj
	var smer := cilj - global_position
	if not nav_agent.is_navigation_finished():
		var naslednja := nav_agent.get_next_path_position()
		if naslednja.distance_squared_to(global_position) > 1.0:
			smer = naslednja - global_position
	velocity = smer.normalized() * hitrost if smer.length_squared() > 1.0 else Vector2.ZERO
	move_and_slide()


func _posodobi_animacijo() -> void:
	smer_animacije = ANIMACIJE.predvajaj(anim_sprite, velocity, smer_animacije)


func _posodobi_skrivanje_pod_krosnjo() -> void:
	var nova_skrita := false
	for drevo in get_tree().get_nodes_in_group("trees"):
		if not is_instance_valid(drevo) or not ("resource_type" in drevo):
			continue
		if int(drevo.resource_type) != 0:
			continue
		# Drevo je zasidrano pri deblu, njegova krošnja pa sega predvsem navzgor.
		# Mehka elipsa približno sledi dejanski 225 x 457 px veliki krošnji.
		var lokalno: Vector2 = drevo.to_local(global_position)
		var normirano := Vector2(lokalno.x / 112.0, (lokalno.y + 165.0) / 225.0)
		if lokalno.y < 45.0 and normirano.length_squared() <= 1.0:
			nova_skrita = true
			break

	if nova_skrita == skrita_pod_krosnjo:
		return
	skrita_pod_krosnjo = nova_skrita
	anim_sprite.visible = not skrita_pod_krosnjo
	senca.visible = not skrita_pod_krosnjo
	input_pickable = not skrita_pod_krosnjo


func je_skrita_pod_krosnjo() -> bool:
	return skrita_pod_krosnjo


func razdalja_do_klika(svetovna_tocka: Vector2) -> float:
	# Žival je narisana nad talno točko. Merimo do vidnega trupa, ne samo do
	# majhnega kroga pri nogah, zato klik na glavo ali hrbet bizona velja.
	var sredina_y := -48.0 if vrsta_zivali == "pragovedo" else -40.0
	var polmer_x := 88.0 if vrsta_zivali == "pragovedo" else 68.0
	var polmer_y := 62.0 if vrsta_zivali == "pragovedo" else 52.0
	var lokalno := to_local(svetovna_tocka) - Vector2(0.0, sredina_y)
	var normirano := Vector2(lokalno.x / polmer_x, lokalno.y / polmer_y)
	if normirano.length_squared() <= 1.0:
		return 0.0
	return global_position.distance_to(svetovna_tocka)


func bojni_polmer() -> float:
	if vrsta_zivali == "pragovedo":
		return 38.0
	if vrsta_zivali == "divji_prasic":
		return 28.0
	return 24.0


func take_damage(amount: int, napadalec = null) -> void:
	if mrtva:
		return
	hp = maxi(0, hp - amount)
	if is_instance_valid(napadalec):
		lovec = napadalec
		if damage > 0:
			attack_target = napadalec
	if hp <= 0:
		_umri()


func _umri() -> void:
	if mrtva:
		return
	mrtva = true
	resource_amount = hrana_ob_smrti
	hp = 0
	velocity = Vector2.ZERO
	attack_target = null
	set_physics_process(false)
	remove_from_group("zivali")
	remove_from_group("sovraznik")
	add_to_group("trees")
	add_to_group("viri")
	# Vsaka vrsta dobi pravo ležeče telo. Ne vrtimo več stoječe slike, ki je
	# delovala kot ravna nalepka.
	ANIMACIJE.pokazi_mrtvo(anim_sprite, vrsta_zivali)
	senca.visible = true
	senca.position.y = 1.0
	senca.scale *= Vector2(1.30, 0.78)
	collision_layer = 0
	collision_mask = 0
	input_pickable = true
	# Delavec, ki je zival ubil, takoj preide iz lova v pobiranje mesa.
	if is_instance_valid(lovec) and lovec.has_method("start_mining"):
		lovec.call_deferred("start_mining", self)


func harvest(amount: int) -> Dictionary:
	if not mrtva:
		return {"type": resource_type, "amount": 0}
	var pobrano := mini(amount, resource_amount)
	resource_amount -= pobrano
	if resource_amount <= 0:
		queue_free()
	return {"type": resource_type, "amount": pobrano}
