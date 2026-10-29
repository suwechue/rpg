// M20: the Upside-Down look. A palette shift toward the week's signature
// colour, a slight wobble, a vignette and a darkened, inverted shadow tone.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 tint : source_color = vec4(0.5, 0.3, 0.8, 1.0);
uniform float tint_strength = 0.25;
uniform float wobble = 0.002;
uniform float vignette = 0.45;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 40.0 + TIME * 1.5) * wobble;
	uv.y += cos(uv.x * 30.0 + TIME * 1.1) * wobble;
	vec4 c = texture(screen_tex, uv);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// Shadows lean toward the inverted tint; lights toward the tint itself.
	vec3 shadow = mix(c.rgb, vec3(1.0) - tint.rgb, 0.2 * (1.0 - lum));
	vec3 col = mix(shadow, shadow * tint.rgb * 1.6, tint_strength);
	float d = distance(SCREEN_UV, vec2(0.5));
	col *= 1.0 - smoothstep(0.35, 0.85, d) * vignette;
	COLOR = vec4(col, 1.0);
}
