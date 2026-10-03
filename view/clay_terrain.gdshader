shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terrain_mask : filter_nearest, repeat_disable;
uniform vec2 mask_size = vec2(640.0, 200.0);
uniform int material_kind = 0;
uniform vec4 base_color : source_color = vec4(0.5, 0.22, 0.09, 1.0);
uniform vec4 impacts[8];
varying vec3 world_point;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float clay_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = UV;
	float broad = clay_noise(p * 0.85);
	float fine = clay_noise(p * 15.0);
	vec3 color = mix(base_color.rgb, texture(color_map, p * 0.35).rgb, 0.08);
	color *= 0.88 + broad * 0.23 + fine * 0.07;
	vec3 n = world_normal;
	vec3 bump = texture(normal_map, p * 0.48).xyz * 2.0 - 1.0;
	if (abs(n.z) > 0.25) {
		n += vec3(bump.x, -bump.y, 0.0) * 0.18;
	} else {
		n += vec3(bump.x, 0.0, -bump.y) * 0.10;
	}
	float pores = 0.0;
	if (material_kind == 0 || material_kind == 3) {
		vec2 cell = floor(p * 7.0);
		vec2 local = fract(p * 7.0) - vec2(0.2 + hash(cell) * 0.6,
			0.2 + hash(cell + 23.0) * 0.6);
		pores = (1.0 - smoothstep(0.035, 0.15, length(local))) * step(0.6, hash(cell + 4.0));
		color *= 1.0 - pores * 0.12;
		n.xy += local * pores * 0.25;
		float fold = sin(p.y * 11.0 + clay_noise(p * 2.0) * 8.0 + p.x * 2.0);
		color *= 1.0 - smoothstep(0.85, 1.0, fold) * 0.025;
	}
	if (world_normal.z > 0.1 && material_kind != 2) {
		for (int i = 0; i < 8; i++) {
			vec2 d = world_point.xy - impacts[i].xy;
			float influence = exp(-dot(d, d) / 0.22) * impacts[i].z;
			n.xy += d * influence * 3.0;
			color *= 1.0 - influence * 0.14;
		}
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n), 0.0)).xyz);
	ALBEDO = color;
	ROUGHNESS = material_kind == 2 ? 0.57 : 0.92;
	METALLIC = material_kind == 2 ? 0.55 : 0.0;
	AO = 1.0 - pores * 0.1;
	SPECULAR = 0.25;
}
