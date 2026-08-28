extends Node2D
class_name Zgradba

const GRADBISCE_TEKSTURA = preload("res://sprite_gradbisce.png")
const VRATA_ODPIRANJE_SHADER = preload("res://vrata_odpiranje.gdshader")

@export var max_hp: int = 200
@export var je_ai: bool = false
@export var tip_zgradbe: String = "zgradba"
@export var potrebuje_gradnjo: bool = true
@export var cas_gradnje: float = 10.0

# Slike zgradbe za posamezno smer (izometrična umetnina se NE sme kar
# zavrteti - to jo popači - zato ima vsaka smer svojo pravo sliko namesto
# ene same zavrtene). Prazna vrednost = ta smer (še) ni na voljo za to
# zgradbo; nastavi_smer() v tem primeru pusti trenutno sliko nespremenjeno.
@export var tekstura_jug: Texture2D
@export var tekstura_sever: Texture2D
@export var tekstura_vzhod: Texture2D
@export var tekstura_zahod: Texture2D
@export var tekstura_nivo2_jug: Texture2D
@export var tekstura_nivo2_sever: Texture2D
@export var tekstura_nivo3_jug: Texture2D
@export var tekstura_nivo3_sever: Texture2D

var smer_zgradbe: String = "jug"

var hp: int
var v_gradnji: bool = true
var gradnja_timer: float = 0.0
var rally_point: Vector2 = Vector2.ZERO
var ima_rally_tocko: bool = false
var rally_spawn_index: int = 0
var rally_zastavica: Node2D = null
## Nivo pripada tej konkretni stavbi. Nikoli se ne bere iz skupnega nivoja
## vseh stavb iste vrste, zato nova stavba vedno začne na nivoju 1.
var nivo_zgradbe: int = 1
var nivo_zastavica: Node2D = null
var gradbeniki: Array = []
var v_nadgradnji: bool = false
var nadgradnja_ciljni_nivo: int = 0
var nadgradnja_timer: float = 0.0
var nadgradnja_cas: float = 0.0
var nadgradnja_oznaka: Label = null

var vizualni_otroci: Array = []
var gradbisce_sprite: Sprite2D = null

# --- Vrata: samodejno odpiranje/zapiranje, ko se enota približa/odmakne ---
const VRATA_ZAZNAVA_DOSEG: float = 190.0
const VRATA_ZAZNAVA_INTERVAL: float = 0.2
var _vrata_odprta: bool = false
var _vrata_rocno_odprta: bool = false
var _vrata_scan_timer: float = 0.0
var _vrata_material: ShaderMaterial = null
var _vrata_tween: Tween = null


func prikazi_nivo(nivo: int):
	nivo_zgradbe = clampi(nivo, 1, 3)
	_posodobi_teksturo_nivoja()

	# Glavna stavba, vojašnica in stolp imajo sedaj pravo posebno sliko za
	# vsak nivo. Številčna zastavica je zato potrebna samo še pri objektih,
	# ki nimajo namenske slike (npr. obzidje in vrata).
	if _ima_namensko_teksturo_za_nivo(nivo_zgradbe):
		_odstrani_nivo_zastavico()
		return

	if nivo_zgradbe <= 1:
		_odstrani_nivo_zastavico()
		return

	if nivo_zastavica == null or not is_instance_valid(nivo_zastavica):

		nivo_zastavica = Node2D.new()
		nivo_zastavica.name = "NivoZastavica"
		# Zaprti obrambni stolp je visok približno 304 px. Zastavica mora biti
		# na strehi, ne sredi njegove stene. Druge stavbe obdržijo nižjo lego.
		var vrh_y := -326.0 if tip_zgradbe == "stolp" else -80.0
		nivo_zastavica.z_index = 50

		var drog = ColorRect.new()
		drog.name = "Drog"
		drog.color = Color(0.4, 0.3, 0.15, 1)
		drog.size = Vector2(3, 30)
		drog.position = Vector2(-1, vrh_y)
		nivo_zastavica.add_child(drog)

		var zastava = ColorRect.new()
		zastava.name = "Zastava"
		zastava.color = Color(0.8, 0.15, 0.15, 1)
		zastava.size = Vector2(22, 16)
		zastava.position = Vector2(2, vrh_y)
		nivo_zastavica.add_child(zastava)

		var stevilka = Label.new()
		stevilka.name = "StNivoja"
		stevilka.size = Vector2(22, 16)
		stevilka.position = Vector2(2, vrh_y - 1.0)
		stevilka.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stevilka.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stevilka.add_theme_font_size_override("font_size", 13)
		stevilka.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		nivo_zastavica.add_child(stevilka)

		add_child(nivo_zastavica)

	nivo_zastavica.get_node("StNivoja").text = str(nivo_zgradbe)


func _odstrani_nivo_zastavico() -> void:
	if nivo_zastavica != null and is_instance_valid(nivo_zastavica):
		nivo_zastavica.queue_free()
	nivo_zastavica = null


func _glavni_sprite() -> Sprite2D:
	var kot_node: Node = self
	if kot_node is Sprite2D:
		return kot_node as Sprite2D
	for otrok in get_children():
		if otrok is Sprite2D and otrok != gradbisce_sprite:
			return otrok as Sprite2D
	return null


func _ima_namensko_teksturo_za_nivo(nivo: int) -> bool:
	if nivo == 2:
		return tekstura_nivo2_jug != null or tekstura_nivo2_sever != null
	if nivo == 3:
		return tekstura_nivo3_jug != null or tekstura_nivo3_sever != null
	# Če obstajajo višji nivoji, je tudi nivo 1 del istega slikovnega kompleta.
	return tekstura_nivo2_jug != null or tekstura_nivo3_jug != null


func _posodobi_teksturo_nivoja() -> void:
	var sprite := _glavni_sprite()
	if sprite == null:
		return
	var nova_tekstura := _tekstura_za_smer(smer_zgradbe)
	if nova_tekstura != null:
		sprite.texture = nova_tekstura


# Nastavi, katero stran zgradba "gleda" - zamenja sličico Sprite2D z ustrezno
# smerno različico (glej tekstura_jug/sever/vzhod/zahod). Če za to smer ta
# zgradba (še) nima svoje slike, ostane trenutna sličica nespremenjena -
# tako lahko funkcijo varno kličeš tudi na zgradbah, ki imajo zaenkrat samo
# eno (privzeto, "jug") sliko.
func nastavi_smer(smer: String) -> void:
	smer_zgradbe = smer

	var nova_tekstura = _tekstura_za_smer(smer)
	if nova_tekstura != null:
		var sprite := _glavni_sprite()
		if sprite != null:
			sprite.texture = nova_tekstura

	# Obzidje in vrata uporabljajo pravo 2:1 izometrično mrežo. Njuna ozka
	# pravokotna kolizija mora zato slediti isti diagonali kot vidna slika.
	# Omejeno je samo na ta dva tipa, da se kolizij drugih zgradb ne vrti.
	if tip_zgradbe == "obzidje" or tip_zgradbe == "vrata":
		var kolizija = get_node_or_null("CollisionShape2D")
		if kolizija != null and kolizija.shape is RectangleShape2D:
			kolizija.rotation = kot_stene_za_smer(smer)

	if tip_zgradbe == "vrata" and _vrata_material != null:
		var negativna_os = smer == "jug" or smer == "sever"
		_vrata_material.set_shader_parameter("naklon", 0.572 if negativna_os else -0.572)
		_vrata_material.set_shader_parameter("zamik_q", 0.0 if negativna_os else 0.572)


# Natančna kota obeh robov 2:1 izometrične mreže: atan(1/2) = 26.565°.
static func kot_stene_za_smer(smer: String) -> float:
	match smer:
		"jug":
			return deg_to_rad(-26.565051)
		"sever":
			return deg_to_rad(-26.565051)
		"vzhod":
			return deg_to_rad(26.565051)
		"zahod":
			return deg_to_rad(26.565051)
	return 0.0


func _tekstura_za_smer(smer: String) -> Texture2D:
	if nivo_zgradbe >= 3:
		if smer == "jug" and tekstura_nivo3_jug != null:
			return tekstura_nivo3_jug
		if smer == "sever" and tekstura_nivo3_sever != null:
			return tekstura_nivo3_sever
	elif nivo_zgradbe >= 2:
		if smer == "jug" and tekstura_nivo2_jug != null:
			return tekstura_nivo2_jug
		if smer == "sever" and tekstura_nivo2_sever != null:
			return tekstura_nivo2_sever
	match smer:
		"jug":
			return tekstura_jug
		"sever":
			return tekstura_sever
		"vzhod":
			return tekstura_vzhod
		"zahod":
			return tekstura_zahod
	return null


func _ready():
	if je_ai:
		add_to_group("ai_zgradbe")
		add_to_group("sovraznik")
		modulate = Color(1.0, 0.6, 0.6, 1.0)
	else:
		add_to_group("zgradbe")

	if has_node("VisionLight"):
		$VisionLight.enabled = false

	hp = max_hp

	for otrok in get_children():
		if otrok is Sprite2D or otrok is ColorRect:
			vizualni_otroci.append(otrok)

	if tip_zgradbe == "vrata":
		for viz in vizualni_otroci:
			if viz is Sprite2D:
				_vrata_material = ShaderMaterial.new()
				_vrata_material.shader = VRATA_ODPIRANJE_SHADER
				_vrata_material.set_shader_parameter("odprtost", 0.0)
				var negativna_os = smer_zgradbe == "jug" or smer_zgradbe == "sever"
				_vrata_material.set_shader_parameter("naklon", 0.572 if negativna_os else -0.572)
				_vrata_material.set_shader_parameter("zamik_q", 0.0 if negativna_os else 0.572)
				viz.material = _vrata_material
				break

	if potrebuje_gradnjo:
		v_gradnji = true
		gradnja_timer = 0.0
		modulate.a = 1.0

		# Zgradba je med gradnjo POPOLNOMA skrita - NE se več postopoma
		# "razkriva" (prejšnji shader-based učinek je bil uporabniku
		# zavajajoč/nedokončano videti). Namesto tega igralec vidi samo
		# gradbišče (glej spodaj) + delavca, ki tam dela in ima nad sabo
		# odštevalnik (glej delavec.gd, "_pokazi_gradi_label"). Ko je
		# gradnja končana, se zgradba pokaže TAKOJ V CELOTI (glej gradi()
		# spodaj) - izrecna želja uporabnika.
		var velikost_zgradbe = _velikost_glavne_slicice()

		for viz in vizualni_otroci:
			if is_instance_valid(viz):
				viz.visible = false

		if _naj_prikaze_gradbisce_sprite():
			gradbisce_sprite = Sprite2D.new()
			gradbisce_sprite.texture = GRADBISCE_TEKSTURA
			gradbisce_sprite.z_index = 5
			# Gradbišče naj bo v velikosti DEJANSKE zgradbe, ki se gradi -
			# prej je bila sličica gradbišča vedno enake generične
			# velikosti, kar je bilo za večje zgradbe premajhno/ni
			# ustrezalo dejanski površini, ki jo bo zgradba zavzela.
			if velikost_zgradbe.x > 0.0 and velikost_zgradbe.y > 0.0 and gradbisce_sprite.texture != null:
				var native_velikost = gradbisce_sprite.texture.get_size()
				if native_velikost.x > 0.0 and native_velikost.y > 0.0:
					# Merilo mora biti ENAKO po obeh oseh. Prejsnja delitev Vector2
					# je pri visokem ozkem stolpu gradbisce raztegnila iz 220 x 150
					# v 150 x 304, zato je izgledalo mocno popaceno. Sirina sledi
					# zgradbi, naravno razmerje stranic odra pa vedno ostane enako.
					var enotno_merilo: float = velikost_zgradbe.x / native_velikost.x
					gradbisce_sprite.scale = Vector2.ONE * enotno_merilo
			add_child(gradbisce_sprite)
	else:
		v_gradnji = false


# Vidna velikost (širina, višina) GLAVNE sličice zgradbe (prva Sprite2D med
# vizualnimi otroki, z dejansko trenutno umetnino/skalo) - uporabljeno za
# velikost gradbišča med gradnjo.
func _velikost_glavne_slicice() -> Vector2:
	for viz in vizualni_otroci:
		if viz is Sprite2D and viz.texture != null:
			return viz.texture.get_size() * viz.scale
	return Vector2.ZERO


# Override v podrazredu (npr. polje.gd), če zgradba med gradnjo NE sme
# prikazovati skupne lesene "gradbišče" sličice čez sebe (npr. polje, ki naj
# med gradnjo kaže samo prazno njivo, brez lesenega odra).
func _naj_prikaze_gradbisce_sprite() -> bool:
	return true


func _process(delta):
	if v_nadgradnji and not v_gradnji:
		_posodobi_nadgradnjo(delta)
	if tip_zgradbe == "vrata" and not v_gradnji:
		_posodobi_vrata(delta)


func zacni_nadgradnjo(ciljni_nivo: int, trajanje: float) -> bool:
	if v_gradnji or v_nadgradnji or ciljni_nivo != nivo_zgradbe + 1 or nivo_zgradbe >= 3:
		return false
	v_nadgradnji = true
	nadgradnja_ciljni_nivo = clampi(ciljni_nivo, 2, 3)
	nadgradnja_timer = 0.0
	nadgradnja_cas = maxf(0.1, trajanje)
	_posodobi_nadgradnja_oznako()
	return true


func obnovi_nadgradnjo(ciljni_nivo: int, pretecen_cas: float, trajanje: float) -> void:
	if ciljni_nivo <= nivo_zgradbe or ciljni_nivo > 3:
		return
	v_nadgradnji = true
	nadgradnja_ciljni_nivo = ciljni_nivo
	nadgradnja_timer = clampf(pretecen_cas, 0.0, maxf(0.1, trajanje))
	nadgradnja_cas = maxf(0.1, trajanje)
	_posodobi_nadgradnja_oznako()


func napredek_nadgradnje() -> float:
	if not v_nadgradnji or nadgradnja_cas <= 0.0:
		return 0.0
	return clampf(nadgradnja_timer / nadgradnja_cas, 0.0, 1.0)


func preostanek_nadgradnje() -> float:
	return maxf(0.0, nadgradnja_cas - nadgradnja_timer) if v_nadgradnji else 0.0


func _posodobi_nadgradnjo(delta: float) -> void:
	nadgradnja_timer += delta
	_posodobi_nadgradnja_oznako()
	if nadgradnja_timer >= nadgradnja_cas:
		_dokoncaj_nadgradnjo()


func _posodobi_nadgradnja_oznako() -> void:
	if not v_nadgradnji:
		if is_instance_valid(nadgradnja_oznaka):
			nadgradnja_oznaka.queue_free()
		nadgradnja_oznaka = null
		return
	if not is_instance_valid(nadgradnja_oznaka):
		nadgradnja_oznaka = Label.new()
		nadgradnja_oznaka.name = "NadgradnjaOznaka"
		nadgradnja_oznaka.z_index = 80
		nadgradnja_oznaka.position = Vector2(-70, -360 if tip_zgradbe == "stolp" else -125)
		nadgradnja_oznaka.size = Vector2(140, 30)
		nadgradnja_oznaka.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nadgradnja_oznaka.add_theme_font_size_override("font_size", 16)
		nadgradnja_oznaka.add_theme_color_override("font_color", Color(1.0, 0.83, 0.2))
		nadgradnja_oznaka.add_theme_color_override("font_outline_color", Color.BLACK)
		nadgradnja_oznaka.add_theme_constant_override("outline_size", 5)
		add_child(nadgradnja_oznaka)
	nadgradnja_oznaka.text = "Nivo %d  •  %ds" % [nadgradnja_ciljni_nivo, int(ceil(preostanek_nadgradnje()))]


func _dokoncaj_nadgradnjo() -> void:
	if not v_nadgradnji:
		return
	var stari_nivo := nivo_zgradbe
	var novi_nivo := nadgradnja_ciljni_nivo
	v_nadgradnji = false
	nadgradnja_timer = nadgradnja_cas
	nadgradnja_ciljni_nivo = 0
	_posodobi_nadgradnja_oznako()
	prikazi_nivo(novi_nivo)
	_prikazi_zakljucek_nadgradnje()
	if je_ai:
		get_tree().call_group("ai_controller", "ai_nadgradnja_zgradbe_dokoncana", self, stari_nivo, novi_nivo)
	else:
		get_tree().call_group("main_script", "nadgradnja_zgradbe_dokoncana", self, stari_nivo, novi_nivo)


func _prikazi_zakljucek_nadgradnje() -> void:
	var sprite := _glavni_sprite()
	if sprite != null:
		var prvotna := sprite.modulate
		sprite.modulate = Color(1.55, 1.45, 0.9, prvotna.a)
		create_tween().tween_property(sprite, "modulate", prvotna, 0.55)
	var oznaka := Label.new()
	oznaka.text = "✓ Nivo %d" % nivo_zgradbe
	oznaka.position = Vector2(-50, -360 if tip_zgradbe == "stolp" else -125)
	oznaka.size = Vector2(100, 28)
	oznaka.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oznaka.z_index = 90
	oznaka.add_theme_font_size_override("font_size", 17)
	oznaka.add_theme_color_override("font_color", Color(0.45, 1.0, 0.4))
	oznaka.add_theme_color_override("font_outline_color", Color.BLACK)
	oznaka.add_theme_constant_override("outline_size", 5)
	add_child(oznaka)
	var tween := create_tween()
	tween.tween_property(oznaka, "position:y", oznaka.position.y - 30.0, 1.1)
	tween.parallel().tween_property(oznaka, "modulate:a", 0.0, 1.1).set_delay(0.2)
	tween.tween_callback(oznaka.queue_free)


# Vrata se samodejno odprejo samo v SREDINI - obe vratni krili se vizualno
# stisneta proti zunanjima tečajema in razkrijeta prehod. Zunanji zid,
# stebri, merilo in prosojnost celotne slike ostanejo pri miru. To nadomesti
# star učinek, ki je skrčil in zbledel CELOTNA vrata ter zato izgledal, kot
# da se obrača vsa zgradba. Odpiranje se sproži, ko se približa
# LASTNIKOVA enota (igralec svoje, AI svoje - glede na je_ai), in se spet
# "zaprejo", ko v bližini ni več nikogar. Fizične kolizije namenoma NE
# vklapljam/izklapljam: obstoječa collision_layer/mask ureditev (glej
# delavec.gd/enota.gd) že poskrbi, da lastnikove enote skozi svoja vrata
# hodijo prosto (njihova maska sploh ne vključuje vrat), sovražne AI enote
# pa jih fizično NE morejo prečkati (njihova maska jih vključuje) - ne
# glede na to, ali so vrata trenutno vizualno "odprta" ali ne.
func _posodobi_vrata(delta: float) -> void:
	_vrata_scan_timer += delta
	if _vrata_scan_timer < VRATA_ZAZNAVA_INTERVAL:
		return
	_vrata_scan_timer = 0.0

	var skupine = ["ai_delavci", "ai_enote"] if je_ai else ["delavci", "enote"]

	var kdo_zraven = _vrata_rocno_odprta
	for skupina in skupine:
		for enota in get_tree().get_nodes_in_group(skupina):
			if is_instance_valid(enota) and global_position.distance_to(enota.global_position) < VRATA_ZAZNAVA_DOSEG:
				kdo_zraven = true
				break
		if kdo_zraven:
			break

	if kdo_zraven and not _vrata_odprta:
		_odpri_vrata()
	elif not kdo_zraven and _vrata_odprta:
		_zapri_vrata()


func _odpri_vrata() -> void:
	_vrata_odprta = true
	if _vrata_material != null:
		if _vrata_tween != null and _vrata_tween.is_valid():
			_vrata_tween.kill()
		_vrata_tween = create_tween()
		_vrata_tween.tween_property(_vrata_material, "shader_parameter/odprtost", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _zapri_vrata() -> void:
	_vrata_odprta = false
	if _vrata_material != null:
		if _vrata_tween != null and _vrata_tween.is_valid():
			_vrata_tween.kill()
		_vrata_tween = create_tween()
		_vrata_tween.tween_property(_vrata_material, "shader_parameter/odprtost", 0.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


# Ročna možnost je namenoma trajna: vrata ostanejo odprta, dokler igralec
# znova ne pritisne gumba. Samodejno zaznavanje enot še vedno deluje, kadar
# ročni način ni vključen.
func preklopi_vrata_rocno() -> void:
	if tip_zgradbe != "vrata" or v_gradnji:
		return
	_vrata_rocno_odprta = not _vrata_rocno_odprta
	if _vrata_rocno_odprta:
		_odpri_vrata()
	else:
		_zapri_vrata()


func so_vrata_odprta() -> bool:
	return _vrata_odprta


func gradi(kolicina: float) -> void:

	if not v_gradnji:
		return

	gradnja_timer += kolicina

	if gradnja_timer >= cas_gradnje:
		v_gradnji = false

		for viz in vizualni_otroci:
			if is_instance_valid(viz):
				viz.visible = true
				viz.material = null

		if gradbisce_sprite != null and is_instance_valid(gradbisce_sprite):
			gradbisce_sprite.queue_free()
			gradbisce_sprite = null

		_ob_koncu_gradnje()
		_prikazi_zakljucek_gradnje()

		if je_ai:
			get_tree().call_group("ai_controller", "ai_zgradba_dokoncana", self)
		else:
			get_tree().call_group("main_script", "zgradba_dokoncana", self)


# Kratek, jasno viden znak, da je gradnja DEJANSKO končana - kratek svetel
# utrip po sličici + napis "✓ Zgrajeno", ki poplava navzgor in izgine. Brez
# tega je bilo (po uporabnikovi prijavi) edino vidno "konec gradnje" to, da
# je gradbiščni oder izginil - kar je bilo prelahko spregledati.
func _prikazi_zakljucek_gradnje() -> void:

	for viz in vizualni_otroci:
		if is_instance_valid(viz):
			var prvotna_barva: Color = viz.modulate
			viz.modulate = Color(1.7, 1.7, 1.3, 1.0)
			var t_utrip = create_tween()
			t_utrip.tween_property(viz, "modulate", prvotna_barva, 0.45)

	var oznaka = Label.new()
	oznaka.text = "✓ Zgrajeno"
	oznaka.add_theme_font_size_override("font_size", 16)
	oznaka.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35, 1.0))
	oznaka.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	oznaka.add_theme_constant_override("outline_size", 4)
	oznaka.position = Vector2(-40, -95)
	oznaka.z_index = 20
	add_child(oznaka)

	var t_napis = create_tween()
	t_napis.tween_property(oznaka, "position:y", oznaka.position.y - 35, 1.3)
	t_napis.parallel().tween_property(oznaka, "modulate:a", 0.0, 1.3).set_delay(0.3)
	t_napis.tween_callback(oznaka.queue_free)


# Override v podrazredu za dodatne spremembe, ko je gradnja te zgradbe
# dokončana (npr. polje.gd zamenja sličico praznega polja za sličico
# polnega polja s koruzo).
func _ob_koncu_gradnje() -> void:
	pass


func take_damage(amount: int, napadalec = null):
	hp -= amount
	if hp < 0:
		hp = 0

	print(name, " HP: ", hp, "/", max_hp)

	if hp <= 0:
		print(name, " uničena!")

		if is_in_group("glavna_hisa"):
			get_tree().call_group("main_script", "igra_konec", false)
		elif is_in_group("ai_baza"):
			get_tree().call_group("main_script", "igra_konec", true)

		# Enak vzorec kot zgoraj pri zgradba_dokoncana - obvesti main.gd, da
		# lahko posodobi svoje štetje (stevilo_vojasnic/stevilo_zidov/...) in
		# ostalo stanje, vezano na TO zgradbo. Klicano PRED queue_free(), da
		# main.gd še vidi veljaven tip_zgradbe/global_position. Prej se to ni
		# zgodilo NIKOLI za zgradbe, uničene v boju - njihovo štetje je ostalo
		# za vedno "zasedeno", kar je enak razlog, zakaj ga zdaj rabi tudi nov
		# gumb "Zruši" (glej main.gd:zgradba_unicena).
			if je_ai:
				get_tree().call_group("ai_controller", "ai_zgradba_unicena", self)
			else:
				get_tree().call_group("main_script", "zgradba_unicena", self)

		queue_free()
		return

	if napadalec != null and is_instance_valid(napadalec):
		_poklici_na_pomoc(napadalec)


func _poklici_na_pomoc(napadalec):

	var skupina_enot = "ai_enote" if je_ai else "enote"
	var doseg_klica = 350.0

	for u in get_tree().get_nodes_in_group(skupina_enot):
		if not is_instance_valid(u):
			continue
		if u.state == "ATTACKING":
			continue
		if global_position.distance_to(u.global_position) <= doseg_klica:
			u.ukazi_napad(napadalec)


func repair(amount: int):
	if hp >= max_hp:
		return

	hp += amount
	if hp > max_hp:
		hp = max_hp

	print(name, " popravljena: ", hp, "/", max_hp)
