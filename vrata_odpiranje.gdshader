shader_type canvas_item;

// 0 = zaprta vrata, 1 = odprta vrata. Zunanji del slike ostane vedno
// popolnoma nespremenjen; skrčita se samo dve sredinski vratni krili proti
// njunima tečajema, kar v izometričnem pogledu deluje kot odpiranje navzven.
uniform float odprtost : hint_range(0.0, 1.0) = 0.0;
uniform float naklon = 0.572;
uniform float zamik_q = 0.0;

void fragment() {
	vec2 uv = UV;
	vec4 barva = texture(TEXTURE, uv);

	// Koordinata vzdolž poševnega roba. Za drugo izometrično os main.gd
	// spremeni predznak parametra naklon.
	float q = uv.y + naklon * uv.x + zamik_q;
	const float LEVI_TECaj = 0.325;
	const float DESNI_TECaj = 0.695;
	const float SREDINA = 0.510;
	const float VRH_KRIL = 0.735;
	const float DNO_KRIL = 1.005;

	if (odprtost > 0.001 && uv.x > LEVI_TECaj && uv.x < DESNI_TECaj && q > VRH_KRIL && q < DNO_KRIL) {
		float faktor = mix(1.0, 0.20, smoothstep(0.0, 1.0, odprtost));
		float izvorni_x = uv.x;
		bool narisi_krilo = true;

		if (uv.x < SREDINA) {
			float odprta_sirina = (SREDINA - LEVI_TECaj) * faktor;
			if (uv.x > LEVI_TECaj + odprta_sirina) {
				narisi_krilo = false;
			} else {
				izvorni_x = LEVI_TECaj + (uv.x - LEVI_TECaj) / faktor;
			}
		} else {
			float odprta_sirina = (DESNI_TECaj - SREDINA) * faktor;
			if (uv.x < DESNI_TECaj - odprta_sirina) {
				narisi_krilo = false;
			} else {
				izvorni_x = DESNI_TECaj - (DESNI_TECaj - uv.x) / faktor;
			}
		}

		if (narisi_krilo) {
			vec2 izvorni_uv = vec2(izvorni_x, q - zamik_q - naklon * izvorni_x);
			barva = texture(TEXTURE, izvorni_uv);
		} else {
			barva.a = 0.0;
		}
	}

	COLOR = barva;
}
