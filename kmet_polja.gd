extends CharacterBody2D

const ANIMACIJE = preload("res://delavec_animacije.gd")

# Kmet polja je namenski delavec. Ni v skupini "delavci", zato ga igralec
# ne more izbrati, premakniti ali poslati po druge surovine. Njegovo edino
# delo je hoja po vrstah njive, ki ga je ustvarila.
@export var hitrost: float = 58.0

const DELOVNE_TOCKE: Array[Vector2] = [
	Vector2(-72, 30),
	Vector2(72, 30),
	Vector2(72, 8),
	Vector2(-72, 8),
	Vector2(-72, -14),
	Vector2(72, -14),
]

var polje = null
var indeks_tocke: int = 0
var smer_animacije: String = "jug"
var cas_dela: float = 0.0
var dela: bool = false
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var napis: Label = $Napis


func _ready() -> void:
	ANIMACIJE.pripravi(sprite)
	add_to_group("kmetje_polja")
	input_pickable = false
	collision_layer = 0
	collision_mask = 0


func dodeli_polje(novo_polje) -> void:
	polje = novo_polje
	# Kmet se pojavi na zacetku prve vrste in se takoj odpravi proti njenemu
	# drugemu koncu. Sele ob prihodu se ustavi ter za kratek cas okopava.
	indeks_tocke = 1
	dela = false
	cas_dela = 0.0
	global_position = polje.global_position + DELOVNE_TOCKE[0]


func _physics_process(delta: float) -> void:
	if not is_instance_valid(polje):
		queue_free()
		return

	if dela:
		velocity = Vector2.ZERO
		cas_dela -= delta
		ANIMACIJE.predvajaj(sprite, "kmet", smer_animacije)
		if cas_dela <= 0.0:
			dela = false
			indeks_tocke = (indeks_tocke + 1) % DELOVNE_TOCKE.size()
		_posodobi_napis()
		return

	var cilj: Vector2 = polje.global_position + DELOVNE_TOCKE[indeks_tocke]
	var smer: Vector2 = cilj - global_position

	if smer.length() <= 4.0:
		velocity = Vector2.ZERO
		dela = true
		cas_dela = 0.8
		# Pogled je usmerjen proti naslednji vrsti, zato kmet pri okopavanju ni
		# vedno obrnjen v isto smer.
		var naslednja := (indeks_tocke + 1) % DELOVNE_TOCKE.size()
		var pogled: Vector2 = DELOVNE_TOCKE[naslednja] - DELOVNE_TOCKE[indeks_tocke]
		smer_animacije = ANIMACIJE.smer_iz_vektorja(pogled, smer_animacije)
		ANIMACIJE.predvajaj(sprite, "kmet", smer_animacije)
		_posodobi_napis()
		return

	if smer.length_squared() > 0.01:
		velocity = smer.normalized() * hitrost
		smer_animacije = ANIMACIJE.smer_iz_vektorja(velocity, smer_animacije)
		ANIMACIJE.predvajaj(sprite, "walk", smer_animacije)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		ANIMACIJE.predvajaj(sprite, "idle", smer_animacije)

	_posodobi_napis()


func _posodobi_napis() -> void:
	if polje.has_method("preostali_cas_zetve"):
		var preostalo: int = int(ceil(polje.preostali_cas_zetve()))
		napis.text = "Kmet: %ds" % preostalo
