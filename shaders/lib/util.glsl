#include "/lib/settings.glsl"

#define PI  3.14159265359
#define TAU 6.28318530718

#define VOXEL_RADIUS 128
#define DOUBLE_VOXEL_RADIUS VOXEL_RADIUS * 2
#define WSR_STEPS VOXEL_RADIUS

const int shadowMapResolution = 4096;


struct Triangle {
    vec3 v0;
    vec3 v1;
    vec3 v2;
    vec2 uv0;
    vec2 uv1;
    vec2 uv2;
    uint id;
    ivec2 texSize;
};

struct InternalNode {
    int left;
    int right;
    int isLeftLeaf;
    int isRightLeaf;
    int parent;
    vec3 bboxMin;
    vec3 bboxMax;
};


uint nextPowTwo(in uint n) {
    if (n <= 1u) return 1u;

    n--;
    n |= n >> 1u;
    n |= n >> 2u;
    n |= n >> 4u;
    n |= n >> 8u;
    n |= n >> 16u;
    n++;

    return n;
}

vec3 distortShadowClip(in vec3 shadowClipPos) {
    float distortFactor = length(shadowClipPos.xy) + 0.1;

    shadowClipPos.xy /= distortFactor;
    shadowClipPos.z  *= 0.5;
    
    return shadowClipPos;
}

vec3 projectAndDivide(in mat4 projectionMatrix, in vec3 position) {
	vec4 homePos = projectionMatrix * vec4(position, 1);
	return homePos.xyz / homePos.w;
}

uint getVoxelIndex(in ivec3 worldPos) {
    ivec3 wrapped = worldPos % ivec3(DOUBLE_VOXEL_RADIUS);

    if (wrapped.x < 0) wrapped.x += DOUBLE_VOXEL_RADIUS;
    if (wrapped.y < 0) wrapped.y += DOUBLE_VOXEL_RADIUS;
    if (wrapped.z < 0) wrapped.z += DOUBLE_VOXEL_RADIUS;

    return uint(wrapped.x + wrapped.y * DOUBLE_VOXEL_RADIUS + wrapped.z * DOUBLE_VOXEL_RADIUS * DOUBLE_VOXEL_RADIUS);
}

int getFaceIndex(in vec3 normal) {
    vec3 absN = abs(normal);
    if (absN.x > absN.y && absN.x > absN.z) return normal.x > 0.0? 0:1;
    else if (absN.y > absN.z) return normal.y > 0.0? 2:3;
    else return normal.z > 0.0? 4:5;
}

vec2 getFaceUv(in vec3 hitPoint, in int face) {
    vec3 p = fract(hitPoint);
    if (face == 0) return vec2(1.0 - p.z, 1.0 - p.y);
    if (face == 1) return vec2(p.z, 1.0 - p.y);
    if (face == 2) return vec2(p.x, p.z);
    if (face == 3) return vec2(p.x, 1.0 - p.z);
    if (face == 4) return vec2(p.x, 1.0 - p.y);
    if (face == 5) return vec2(1.0 - p.x, 1.0 - p.y);
    return vec2(-1);
}

bool isVoxelizable(in int blockId) {
    return (blockId >= 10000 && blockId <= 10430);
}

bool isTransparent(in int blockId) {
    return (blockId >= 11030 && blockId <= 11104);
}

vec3 normalizeScenePos(in vec3 pos, in vec3 sceneMin, in vec3 sceneMax) {
    return clamp((pos - sceneMin) / (sceneMax - sceneMin), 0.0, 1.0);
}

ivec2 slotToTexel(in uint slot) {
    const int slotsPerRow = ENTITY_ATLAS_SIZE / ENTITY_ATLAS_SLOT_SIZE;
    ivec2 slotCoord = ivec2(int(slot) % slotsPerRow, int(slot) / slotsPerRow);
    return slotCoord * ENTITY_ATLAS_SLOT_SIZE;
}

uint expandBits(uint v) {
    v = (v * 0x00010001u) & 0xFF0000FFu;
    v = (v * 0x00000101u) & 0x0F00F00Fu;
    v = (v * 0x00000011u) & 0xC30C30C3u;
    v = (v * 0x00000005u) & 0x49249249u;
    return v;
}

uint mortonCode3d(vec3 n) {
    uint x = uint(clamp(n.x * 1024.0, 0.0, 1023.0));
    uint y = uint(clamp(n.y * 1024.0, 0.0, 1023.0));
    uint z = uint(clamp(n.z * 1024.0, 0.0, 1023.0));

    uint xx = expandBits(x);
    uint yy = expandBits(y);
    uint zz = expandBits(z);

    return xx | (yy << 1) | (zz << 2);
}

float rgbToLuma(in vec3 c){
    return sqrt(dot(c, vec3(0.299, 0.587, 0.114)));
}