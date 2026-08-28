extends CharacterBody2D

const SULICAR_ANIMACIJE = preload("res://enota_animacije.gd")
const SEKIRAS_ANIMACIJE = preload("res://sekiras_animacije.gd")
const KIJAC_ANIMACIJE = preload("res://kijac_animacije.gd")
const POGLAVAR_ANIMACIJE = preload("res://poglavar_animacije.gd")

@export var enota_ime: String = "Bojevnik"
@export var max_hp: int = 50
@export var damage: int = 8
@export var attack_range: float = 30.0
@export var speed: float = 150.0
@export var populacija_cena: int = 1
@export var je_ai: bool = false
@export var doseg_zaznave: float = 180.0
@export_enum("sulicar", "sekiras", "kijac", "poglavar") var tip_animacije: String = "sulicar"
var osnovna_skoda: int
var osnovna_hitrost: float

var hp: int
var is_selected: bool = false
var target_position: Vector2
var state: String = "IDLE"

var attack_target = null
var attack_timer: float = 0.0
var attack_cooldown: float = 1.0
var napad_offset: Vector2 = Vector2.ZERO

var auto_scan_timer: float = 0.0
var auto_scan_interval: float = 0.5
## Ročni ukaz za umik ima prednost pred samodejnim zaznavanjem. Po odpoklicu
## vojak mirno odide na cilj in se ne vrača k isti tarči, četudi je še v
## dosegu. Ponovno se vključi šele z novim izrecnim ukazom za napad.
var avtomatski_napad_omogocen: bool = true
var nav_agent: NavigationAgent2D = null
var smer_animacije: String = "jug"
var prehojena_razdalja_animacije: float = 0.0
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
var animacije = SULICAR_ANIMACIJE
var izbirna_puscica: Polygon2D = null


func _ready():
	nav_agent = NavigationAgent2D.new()
	nav_agent.name = "NavAgent"
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = 8.0
	nav_agent.avoidance_enabled = false
	add_child(nav_agent)

	if je_ai:
		add_to_group("ai_enote")
		add_to_group("sovraznik")
		modulate = Color(1.0, 0.4, 0.4, 1.0)
		# Enote se med seboj ne blokirajo fizično; razmik ureja mehko odmikanje.
		collision_mask = 1 | 32
	else:
		add_to_group("enote")
		collision_mask = 1
	if has_node("VisionLight"):
		$VisionLight.enabled = false
	hp = max_hp
	osnovna_skoda = damage
	osnovna_hitrost = speed
	target_position = global_position
	animacije = SEKIRAS_ANIMACIJE if tip_animacije == "sekiras" else (KIJAC_ANIMACIJE if tip_animacije == "kijac" else (POGLAVAR_ANIMACIJE if tip_animacije == "poglavar" else SULICAR_ANIMACIJE))
	if anim_sprite != null:
		animacije.pripravi(anim_sprite)
	_ustvari_izbirno_puscico()
	call_deferred("_prevzemi_nadgradnje")

func _ustvari_izbirno_puscico() -> void:
	izbirna_puscica = Polygon2D.new()
	izbirna_puscica.name = "IzbirnaPuscica"
	izbirna_puscica.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(0, 3)])
	izbirna_puscica.color = Color(1.0, 0.86, 0.12, 1.0)
	izbirna_puscica.position = Vector2(0, -105)
	izbirna_puscica.z_index = 20
	izbirna_puscica.visible = false
	add_child(izbirna_puscica)

func uporabi_nadgradnje(nivo_baze: int, nivo_vojasnice: int) -> void:
	damage = maxi(1, roundi(osnovna_skoda * (1.0 + 0.10 * (nivo_baze - 1) + 0.15 * (nivo_vojasnice - 1))))
	speed = osnovna_hitrost * (1.0 + 0.05 * (nivo_baze - 1) + 0.08 * (nivo_vojasnice - 1))

func _prevzemi_nadgradnje() -> void:
	if je_ai:
		var ai = get_tree().get_first_node_in_group("ai_controller")
		if is_instance_valid(ai) and ai.has_method("ai_nivo_baze") and ai.has_method("ai_nivo_vojasnice"):
			uporabi_nadgradnje(ai.ai_nivo_baze(), ai.ai_nivo_vojasnice())
		return
	var main = get_tree().get_first_node_in_group("main_script")
	if is_instance_valid(main): uporabi_nadgradnje(main.glavna_stavba_level, main.vojasnica_level)


func set_selected(value: bool):
	is_selected = value
	if has_node("Oznaka"):
		$Oznaka.visible = false
	if is_instance_valid(izbirna_puscica):
		izbirna_puscica.visible = value


func take_damage(amount: int, napadalec = null):
	hp -= amount
	if hp <= 0:
		if je_ai:
			get_tree().call_group("ai_controller", "ai_enota_umrla", populacija_cena)
		else:
			get_tree().call_group("main_script", "enota_umrla", populacija_cena)
		queue_free()
		return

	if avtomatski_napad_omogocen and napadalec != null and is_instance_valid(napadalec) and state != "ATTACKING":
		ukazi_napad(napadalec)


func ukazi_napad(tarca):
	ukazi_napad_z_odmikom(tarca, Vector2(randf_range(-18, 18), randf_range(-18, 18)))


func ukazi_napad_z_odmikom(tarca, dolocen_odmik: Vector2) -> void:
	avtomatski_napad_omogocen = true
	attack_target = tarca
	state = "ATTACKING"
	attack_timer = 0.0
	napad_offset = dolocen_odmik
	# Večji dovoljen odmik je še vedno znotraj dosega, omogoči pa drugi obroč
	# večje skupine brez podvajanja istega mesta.
	var najvecji_odmik := maxf(6.0, attack_range * 0.75)
	if napad_offset.length() > najvecji_odmik:
		napad_offset = napad_offset.normalized() * najvecji_odmik


func _razdalja_do_tarce(tarca) -> float:
	var razdalja := global_position.distance_to(tarca.global_position)
	if tarca.has_method("bojni_polmer"):
		razdalja -= float(tarca.bojni_polmer())
	elif je_ai:
		# AI je prej prišel do stavbe in obstal na njeni fizični oviri, ker je
		# meril razdaljo do nedosegljivega središča. Pri AI napadu zato odštejemo
		# dejanski polmer kolizije stavbe in napad se začne na njenem robu.
		var oblika = tarca.get_node_or_null("Ovira/OviraShape")
		if oblika == null:
			oblika = tarca.get_node_or_null("CollisionShape2D")
		if oblika != null and oblika.shape != null:
			var globalna_skala: Vector2 = oblika.global_scale
			if oblika.shape is CircleShape2D:
				razdalja -= float(oblika.shape.radius) * maxf(globalna_skala.x, globalna_skala.y)
			elif oblika.shape is RectangleShape2D:
				var velikost: Vector2 = oblika.shape.size * globalna_skala
				razdalja -= maxf(velikost.x, velikost.y) * 0.5
	return maxf(0.0, razdalja)


func ukazi_premik(cilj: Vector2) -> void:
	# To je tudi ukaz za odpoklic: takoj prekine trenutni napad in blokira
	# samodejno ponovno izbiro tarče do naslednjega ukaza ukazi_napad().
	attack_target = null
	attack_timer = 0.0
	avtomatski_napad_omogocen = false
	target_position = cilj
	state = "WALKING"
	if nav_agent != null:
		nav_agent.target_position = cilj


# Vojaki so prej hodili naravnost proti kliku. Če je bila med njimi in
# ciljem stena, so zadeli njen rob in se zatikali tudi tik ob odprtih vratih.
# Zdaj pri običajnem premiku sledijo isti navigacijski mreži kot delavci.
func _nastavi_navigacijski_premik(cilj: Vector2) -> void:
	if nav_agent == null:
		velocity = (cilj - global_position).normalized() * speed
		return

	if nav_agent.target_position.distance_to(cilj) > 1.0:
		nav_agent.target_position = cilj
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var naslednja = nav_agent.get_next_path_position()
	var smer = naslednja - global_position
	if smer.length_squared() < 0.01:
		velocity = Vector2.ZERO
		return
	velocity = smer.normalized() * speed
	_dodaj_mehko_odmikanje()

func _dodaj_mehko_odmikanje() -> void:
	var odmik := Vector2.ZERO
	var skupina := "ai_enote" if je_ai else "enote"
	for druga in get_tree().get_nodes_in_group(skupina):
		if druga == self or not is_instance_valid(druga): continue
		var razlika: Vector2 = global_position - druga.global_position
		var d2: float = razlika.length_squared()
		if d2 > 1.0 and d2 < 34.0 * 34.0:
			odmik += razlika.normalized() * (1.0 - sqrt(d2) / 34.0)
	if odmik.length_squared() > 0.001:
		velocity = (velocity.normalized() + odmik.normalized() * 0.32).normalized() * speed


func _physics_process(delta):

	if avtomatski_napad_omogocen and (state == "IDLE" or state == "WALKING"):
		auto_scan_timer += delta
		if auto_scan_timer >= auto_scan_interval:
			auto_scan_timer = 0.0
			_poisci_in_napadi_blizu()

	if state == "WALKING":

		var dist = global_position.distance_to(target_position)

		if dist > 10:
			_nastavi_navigacijski_premik(target_position)
		else:
			velocity = Vector2.ZERO
			state = "IDLE"

	elif state == "ATTACKING":

		if not is_instance_valid(attack_target) or _tarca_je_mrtva(attack_target):
			attack_target = null
			state = "IDLE"
			velocity = Vector2.ZERO
		else:
			var dist = _razdalja_do_tarce(attack_target)

			if dist > attack_range:
				var cilj = attack_target.global_position + napad_offset
				_nastavi_navigacijski_premik(cilj)
			else:
				velocity = Vector2.ZERO
				smer_animacije = animacije.smer_iz_vektorja(
					attack_target.global_position - global_position,
					smer_animacije
				)
				attack_timer += delta
				if attack_timer >= attack_cooldown:
					attack_timer = 0.0
					if anim_sprite != null:
						animacije.napadi(anim_sprite, smer_animacije)
					if attack_target.has_method("take_damage"):
						var koncna_skoda = damage
						for p in get_tree().get_nodes_in_group("poveljniki"):
							if not is_in_group("poveljniki") and is_instance_valid(p) and p.je_ai == je_ai:
								koncna_skoda += p.aura_damage_bonus
								break
						attack_target.take_damage(koncna_skoda, self)
						if _tarca_je_mrtva(attack_target):
							attack_target = null
							state = "IDLE"
							velocity = Vector2.ZERO

	else:
		velocity = Vector2.ZERO

	move_and_slide()
	if is_instance_valid(izbirna_puscica) and izbirna_puscica.visible:
		izbirna_puscica.position.y = -105.0 + sin(Time.get_ticks_msec() * 0.006) * 3.0
	if velocity.length_squared() > 1.0:
		prehojena_razdalja_animacije += velocity.length() * delta
	_posodobi_animacijo()


func _tarca_je_mrtva(tarca) -> bool:
	return is_instance_valid(tarca) and "mrtva" in tarca and bool(tarca.mrtva)


func _posodobi_animacijo() -> void:
	if anim_sprite == null:
		return
	# Med približevanjem tarči mora biti vidna hoja. Prej je stari napad ostal
	# aktiven, zato je predvsem sekiraš drsel za bežečo živaljo.
	if velocity.length_squared() > 4.0:
		smer_animacije = animacije.posodobi_gibanje(
			anim_sprite, velocity, smer_animacije, prehojena_razdalja_animacije
		)
		return
	if (
		state == "ATTACKING"
		and is_instance_valid(attack_target)
		and _razdalja_do_tarce(attack_target) <= attack_range
	):
		smer_animacije = animacije.smer_iz_vektorja(
			attack_target.global_position - global_position,
			smer_animacije
		)
		if not animacije.napad_poteka(anim_sprite):
			animacije.miruj(anim_sprite, smer_animacije)
		return
	smer_animacije = animacije.posodobi_gibanje(
		anim_sprite,
		velocity,
		smer_animacije,
		prehojena_razdalja_animacije
	)


func _poisci_in_napadi_blizu():
	if not avtomatski_napad_omogocen:
		return

	var prioritetne_tarce = []
	var sekundarne_tarce = []

	if je_ai:
		prioritetne_tarce = get_tree().get_nodes_in_group("enote")
		sekundarne_tarce = get_tree().get_nodes_in_group("delavci") + get_tree().get_nodes_in_group("zgradbe")
	else:
		prioritetne_tarce = get_tree().get_nodes_in_group("ai_enote")
		sekundarne_tarce = get_tree().get_nodes_in_group("sovraznik")

	var najblizji = _najblizja_tarca(prioritetne_tarce)

	if najblizji == null:
		najblizji = _najblizja_tarca(sekundarne_tarce)

	if najblizji != null:
		ukazi_napad(najblizji)


func _najblizja_tarca(seznam):

	var najblizji = null
	var najkrajsa = doseg_zaznave
	var main = get_tree().get_first_node_in_group("main_script") if not je_ai else null

	for t in seznam:
		if not is_instance_valid(t):
			continue
		if not je_ai and is_instance_valid(main) and main.has_method("je_tarca_vidna_v_megli") and not main.je_tarca_vidna_v_megli(t):
			continue
		var d = global_position.distance_to(t.global_position)
		if d < najkrajsa:
			najkrajsa = d
			najblizji = t

	return najblizji
