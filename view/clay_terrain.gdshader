shader_type spatial;
render_mode cull_back;

uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terrain_mask : filter_nearest, repeat_disable;
uniform vec2 mask_size = vec2(640.0, 200.0);
uniform int material_kind = 0;
uniform vec4 base_color : source_color = vec4(0.62, 0.29, 0.13, 1.0);
uniform vec4 impacts[8];
varying vec3 world_point;
varying vec3 world_normal;

float solid(vec2 cell) {
	if (any(lessThan(cell, vec2(0.0))) || any(greaterThanEqual(cell, mask_size))) {
		return 0.0;
	}
	return texture(terrain_mask, cell / mask_size).r;
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 color = mix(base_color.rgb, texture(color_map, UV * 0.6).rgb, 0.35);
	vec3 orm = texture(orm_map, UV).rgb;
	vec3 bump = texture(normal_map, UV * 0.6).xyz * 2.0 - 1.0;
	vec3 n = world_normal;
	if (abs(n.z) > 0.5) {
		n += vec3(bump.x, -bump.y, 0.0) * 0.24;
	} else if (abs(n.y) > 0.5) {
		n += vec3(bump.x, 0.0, -bump.y) * 0.24;
	} else {
		n += vec3(0.0, -bump.y, -bump.x) * 0.24;
	}
	if (world_normal.z > 0.9) {
		vec2 p = vec2(world_point.x, -world_point.y) * 10.0;
		vec2 edge = vec2(0.0);
		for (int i = 1; i <= 3; i++) {
			float r = float(i) * 0.6;
			edge += vec2(solid(p - vec2(r, 0)) - solid(p + vec2(r, 0)),
				solid(p + vec2(0, r)) - solid(p - vec2(0, r))) / float(i);
		}
		n += vec3(edge * 0.65, 0.0);
		if (material_kind != 2) {
			for (int i = 0; i < 8; i++) {
				vec2 d = world_point.xy - impacts[i].xy;
				float influence = exp(-dot(d, d) / 0.22) * impacts[i].z;
				n.xy += d * influence * 3.0;
				color *= 1.0 - influence * 0.10;
			}
		}
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n), 0.0)).xyz);
	ALBEDO = color;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	AO = orm.r;
}
