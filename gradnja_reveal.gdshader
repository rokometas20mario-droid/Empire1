shader_type canvas_item;

uniform float napredek : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float prag = 1.0 - napredek;
	if (UV.y < prag) {
		tex.a = 0.0;
	}
	COLOR = tex;
}
