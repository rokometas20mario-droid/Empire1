extends "res://zgradba.gd"

const KMET_POLJA_SCENA = preload("res://KmetPolja.tscn")
const PRAZNO_POLJE_TEKSTURA = preload("res://sprite_polje.png")
const POLNO_POLJE_TEKSTURA = preload("res://sprite_polje_koruza.png")

# Vsako polje ima svojega stalnega kmeta in se samodejno ponavlja:
# prazna njiva -> zrela koruza -> žetev in spet prazna njiva.
@export var hrana_ob_zetvi: int = 50
@export var cas_zetve: float = 35.0
@export var cas_rasti: float = 22.0

var zetveni_napredek: float = 0.0
var zraslo: bool = false
var kmet = null


func _ready() -> void:
	super._ready()
	call_deferred("_ustvari_kmeta")


# Polje se postavi takoj kot prazna njiva in zato ne uporablja skupne
# lesene sličice gradbišča.
func _naj_prikaze_gradbisce_sprite() -> bool:
	return false


# Ko polje zraste, zamenjamo sličico prazne njive za polno njivo s koruzo.
func _ob_koncu_gradnje() -> void:
	if has_node("Sprite2D"):
		$Sprite2D.texture = POLNO_POLJE_TEKSTURA


func _process(delta: float) -> void:
	super._process(delta)

	if cas_zetve <= 0.0:
		return

	zetveni_napredek += delta

	if not zraslo and zetveni_napredek >= min(cas_rasti, cas_zetve):
		zraslo = true
		_ob_koncu_gradnje()
		_prikazi_zrelo_polje()
		print("Polje je zraslo - kmet nadaljuje žetev")

	if zetveni_napredek >= cas_zetve:
		_zakljuci_zetev()


func _ustvari_kmeta() -> void:
	if kmet != null or not is_inside_tree():
		return

	var stars = get_parent()
	if stars == null:
		return

	kmet = KMET_POLJA_SCENA.instantiate()
	stars.add_child(kmet)
	kmet.dodeli_polje(self)
	if je_ai:
		kmet.modulate = Color(1.0, 0.6, 0.6, 1.0)


func preostali_cas_zetve() -> float:
	return max(0.0, cas_zetve - zetveni_napredek)


func _zakljuci_zetev() -> void:
	zetveni_napredek = 0.0
	zraslo = false
	if has_node("Sprite2D"):
		$Sprite2D.texture = PRAZNO_POLJE_TEKSTURA
	if je_ai:
		get_tree().call_group("ai_controller", "add_ai_resource", "FOOD", hrana_ob_zetvi)
	else:
		get_tree().call_group("main_script", "polje_pobrano", self, hrana_ob_zetvi)


func _prikazi_zrelo_polje() -> void:
	var oznaka = Label.new()
	oznaka.text = "Koruza je zrela"
	oznaka.add_theme_font_size_override("font_size", 16)
	oznaka.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25, 1.0))
	oznaka.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	oznaka.add_theme_constant_override("outline_size", 4)
	oznaka.position = Vector2(-58, -90)
	oznaka.z_index = 20
	add_child(oznaka)

	var animacija = create_tween()
	animacija.tween_property(oznaka, "position:y", oznaka.position.y - 25, 1.2)
	animacija.parallel().tween_property(oznaka, "modulate:a", 0.0, 1.2).set_delay(0.25)
	animacija.tween_callback(oznaka.queue_free)


func _exit_tree() -> void:
	if is_instance_valid(kmet):
		kmet.queue_free()
	kmet = null
