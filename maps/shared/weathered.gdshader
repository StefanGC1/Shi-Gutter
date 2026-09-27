shader_type spatial;
render_mode diffuse_lambert;

uniform vec4 base_color : source_color = vec4(0.45, 0.45, 0.35, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.08, 0.06, 0.025, 1.0);
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.5;
uniform float pattern_scale = 2.0;
uniform float tile_size = 0.0;
varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
		mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
		mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 p = world_pos * pattern_scale;
	float grime = noise3(p) * 0.7 + noise3(p * 4.0) * 0.3;
	float flecks = noise3(p * 22.0);
	vec3 color = mix(base_color.rgb, dirt_color.rgb, smoothstep(0.25, 0.8, grime) * dirt_amount);
	color *= 0.85 + flecks * 0.25;
	if (tile_size > 0.0) {
		vec2 grid = abs(fract(world_pos.xz / tile_size) - 0.5);
		float seam = smoothstep(0.465, 0.495, max(grid.x, grid.y));
		color = mix(color, dirt_color.rgb, seam * 0.65);
	}
	ALBEDO = color;
	ROUGHNESS = 0.92;
}
