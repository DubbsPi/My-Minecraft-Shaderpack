#define PI  3.14159265359
#define TAU 6.28318530718


vec3 distortShadowClip(in vec3 shadowClipPos) {
    float distortFactor = min(sqrt(dot(shadowClipPos.xy, shadowClipPos.xy)) + 0.05, 0.5);

    shadowClipPos.xy /= distortFactor;
    shadowClipPos.z  *= 0.5;

    return shadowClipPos;
}

vec3 projectAndDivide(in mat4 projectionMatrix, in vec3 position) {
	vec4 homePos = projectionMatrix * vec4(position, 1);
	return homePos.xyz / homePos.w;
}