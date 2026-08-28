shader_type canvas_item;

// Vsak pravokotnik je v UV koordinatah sličice: x, y, širina, višina.
// Negativna širina pomeni, da mesto ni uporabljeno. Do osem prekrivanj je
// dovolj tudi, ko je pod veliko krošnjo več manjših enot ali stavb.
uniform vec4 prekrivanje_0 = vec4(-2.0, -2.0, -1.0, -1.0);
uniform vec4 prekrivanje_1 = vec4(-2.0, -2.0, -1.0, -1.0);
uniform vec4 prekrivanje_2 = vec4(-2.0, -2.0, -1.0, -1.0);
uniform vec4 prekrivanje_3 = vec4(-2.0, -2.0, -1.0, -1.0);
uniform vec4 prekrivanje_4 = vec4(-2.0, -2.0, -1.0, -1.0);
uniform vec4 prekrivanje_5 = vec4(-2.0, -2.0, -1.0, -1.0);
uniform vec4 prekrivanje_6 = vec4(-2.0, -2.0, -1.0, -1.0);
uniform vec4 prekrivanje_7 = vec4(-2.0, -2.0, -1.0, -1.0);
uniform float alfa_pod_objektom : hint_range(0.0, 1.0) = 0.38;
uniform float mehak_rob : hint_range(0.01, 0.5) = 0.30;

// Namesto ostro odrezanega pravokotnika uporabimo mehko ovalno okno.
// Krošnja zato nikjer nenadoma ne "izgine": na sredini ostane 38 % vidna,
// proti robu prekrivanja pa se nežno zlije nazaj v popolnoma vidno drevo.
float maska_mehke_elipse(vec2 uv, vec4 r) {
	if (r.z <= 0.0 || r.w <= 0.0) {
		return 0.0;
	}
	vec2 polmer = max(r.zw * 0.5, vec2(0.001));
	vec2 sredina = r.xy + polmer;
	float razdalja = length((uv - sredina) / polmer);
	return 1.0 - smoothstep(1.0 - mehak_rob, 1.0, razdalja);
}

void fragment() {
	vec4 barva = texture(TEXTURE, UV);
	float maska = 0.0;
	maska = max(maska, maska_mehke_elipse(UV, prekrivanje_0));
	maska = max(maska, maska_mehke_elipse(UV, prekrivanje_1));
	maska = max(maska, maska_mehke_elipse(UV, prekrivanje_2));
	maska = max(maska, maska_mehke_elipse(UV, prekrivanje_3));
	maska = max(maska, maska_mehke_elipse(UV, prekrivanje_4));
	maska = max(maska, maska_mehke_elipse(UV, prekrivanje_5));
	maska = max(maska, maska_mehke_elipse(UV, prekrivanje_6));
	maska = max(maska, maska_mehke_elipse(UV, prekrivanje_7));
	barva.a *= mix(1.0, alfa_pod_objektom, maska);
	COLOR = barva;
}
