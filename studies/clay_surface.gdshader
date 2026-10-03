shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 clay_color : source_color = vec4(0.72, 0.43, 0.19, 1.0);
uniform float relief = 0.022;
uniform float surface_roughness = 0.88;
varying vec3 clay_point;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(.17, .31, .57));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i+vec3(1,0,0)), f.x),
		mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x),
		mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	clay_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = clay_point;
	float broad = noise(p * 3.5);
	float fold = noise(p * vec3(17.0, 12.0, 24.0) + vec3(broad * 6.0));
	float detail = noise(p * 59.0);
	float relief_height = (fold * .8 + detail * .22) * relief;
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 rx = cross(sy, NORMAL);
	vec3 ry = cross(NORMAL, sx);
	float det = dot(sx, rx);
	vec3 gradient = rx * dFdx(relief_height) + ry * dFdy(relief_height);
	NORMAL = normalize(abs(det) * NORMAL - sign(det) * gradient);
	ALBEDO = clay_color.rgb * COLOR.rgb * (0.85 + broad * .25 + detail * .04);
	ROUGHNESS = surface_roughness;
	SPECULAR = .28;
	AO = .82 + fold * .18;
}
