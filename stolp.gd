extends "res://zgradba.gd"

const PUSCICA_SCENA: PackedScene = preload("res://puscica_izstrelek.tscn")

# Izhodisca so v treh dejanskih temnih odprtinah zaprtega zgornjega dela.
# Nivo doloci tudi stevilo puscic, ki zapustijo stolp v istem trenutku.
const ODPRTINE_PO_NIVOJU: Dictionary = {
	1: [Vector2(-12.0, -220.0)],
	2: [Vector2(-25.0, -225.0), Vector2(17.0, -219.0)],
	3: [Vector2(-25.0, -225.0), Vector2(-12.0, -220.0), Vector2(17.0, -219.0)],
}

@export var attack_range: float = 200.0
@export var damage: int = 15
@export var attack_cooldown: float = 1.5

var attack_timer: float = 0.0
var nivo_stolpa: int = 1


func prikazi_nivo(nivo: int) -> void:
	nivo_stolpa = clampi(nivo, 1, 3)
	super.prikazi_nivo(nivo_stolpa)


func _process(delta: float) -> void:
	super._process(delta)
	if v_gradnji:
		return

	attack_timer += delta
	if attack_timer < attack_cooldown:
		return

	var tarca = _najdi_tarco()
	if tarca != null:
		attack_timer = 0.0
		_izstreli_salvo(tarca)
	else:
		attack_timer = attack_cooldown


func _najdi_tarco():
	var tarca = null
	var najkrajsa := attack_range
	var kandidati: Array = []
	if je_ai:
		kandidati += get_tree().get_nodes_in_group("delavci")
		kandidati += get_tree().get_nodes_in_group("enote")
		kandidati += get_tree().get_nodes_in_group("zgradbe")
		var glavna = get_tree().get_first_node_in_group("glavna_hisa")
		if glavna:
			kandidati.append(glavna)
	else:
		kandidati = get_tree().get_nodes_in_group("sovraznik")

	for kandidat in kandidati:
		if not is_instance_valid(kandidat) or kandidat == self:
			continue
		# Nevtralnih zivali obrambni stolp ne lovi samodejno.
		if kandidat.is_in_group("zivali"):
			continue
		if not je_ai:
			var main = get_tree().get_first_node_in_group("main_script")
			if is_instance_valid(main) and main.has_method("je_tarca_vidna_v_megli") and not main.je_tarca_vidna_v_megli(kandidat):
				continue
		var razdalja := global_position.distance_to(kandidat.global_position)
		if razdalja < najkrajsa:
			najkrajsa = razdalja
			tarca = kandidat
	return tarca


func _izstreli_salvo(tarca) -> void:
	if not is_instance_valid(tarca) or v_gradnji:
		return
	var odprtine: Array = ODPRTINE_PO_NIVOJU[nivo_stolpa]
	var stevilo := odprtine.size()
	var osnovna_skoda := int(damage / stevilo)
	var ostanek := damage % stevilo
	var stars := get_parent()
	if stars == null:
		return

	# Vse puscice nastanejo v isti slikovni fazi; razlikujejo se samo po
	# odprtini in delezu skupne skode stolpa.
	for i in range(stevilo):
		var puscica = PUSCICA_SCENA.instantiate()
		stars.add_child(puscica)
		puscica.global_position = to_global(odprtine[i])
		var skoda_puscice := osnovna_skoda + (1 if i < ostanek else 0)
		puscica.izstreli(tarca, skoda_puscice, self)


func stevilo_puscic_v_salvi() -> int:
	return int(ODPRTINE_PO_NIVOJU[nivo_stolpa].size())
