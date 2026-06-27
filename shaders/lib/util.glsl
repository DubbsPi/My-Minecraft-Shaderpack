#include "/lib/settings.glsl"

#define PI  3.14159265359
#define TAU 6.28318530718

#define VOXEL_RADIUS 128
#define DOUBLE_VOXEL_RADIUS VOXEL_RADIUS * 2


vec3 distortShadowClip(in vec3 shadowClipPos) {
    float distortFactor = sqrt(dot(shadowClipPos.xy, shadowClipPos.xy)) + 0.1;

    shadowClipPos.xy /= distortFactor;
    shadowClipPos.z  *= 0.5;
    
    return shadowClipPos;
}

vec3 projectAndDivide(in mat4 projectionMatrix, in vec3 position) {
	vec4 homePos = projectionMatrix * vec4(position, 1);
	return homePos.xyz / homePos.w;
}

vec2 worldPosToVoxelUv(in vec3 worldPos, in vec3 cameraPosition) {
    ivec3 offset = ivec3(floor(worldPos)) - ivec3(floor(cameraPosition)) + ivec3(VOXEL_RADIUS);

    if (any(lessThan(offset, ivec3(0))) || any(greaterThanEqual(offset, ivec3(DOUBLE_VOXEL_RADIUS))))
        return vec2(-1);
    
    int tileX = offset.y % 16;
    int tileY = offset.y / 16;

    return (vec2(tileX * DOUBLE_VOXEL_RADIUS + offset.x, tileY * DOUBLE_VOXEL_RADIUS + offset.z) + 0.5) / float(shadowMapResolution);
}

ivec2 worldPosToVoxelTexel(in vec3 worldPos, in vec3 cameraPosition) {
    ivec3 offset = ivec3(floor(worldPos)) - ivec3(floor(cameraPosition)) + ivec3(VOXEL_RADIUS);

    if (any(lessThan(offset, ivec3(0))) || any(greaterThanEqual(offset, ivec3(DOUBLE_VOXEL_RADIUS))))
        return ivec2(-1);
    
    int tileX = offset.y % 16;
    int tileY = offset.y / 16;

    return ivec2(tileX * DOUBLE_VOXEL_RADIUS + offset.x, tileY * DOUBLE_VOXEL_RADIUS + offset.z);
}