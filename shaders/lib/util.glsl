#include "/lib/settings.glsl"

#define PI  3.14159265359
#define TAU 6.28318530718


struct Vertex {
    vec3 pos;
    vec2 uv;
    vec4 glcolor;
    int id;
};

struct Triangle {
    vec3 v0;
    vec3 v1;
    vec3 v2;
    vec2 uv0;
    vec2 uv1;
    vec2 uv2;
    vec4 glcolor0;
    vec4 glcolor1;
    vec4 glcolor2;
    int id;
    ivec2 texSize;
};

struct MortonCodes {
    uint mortonCodesA;
    uint triIdsA;
    uint mortonCodesB;
    uint triIdsB;
};

struct BvhNode {
    vec3 minBounds;
    vec3 maxBounds;
    int leftChild;
    int rightChild;
    int parent;
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

vec3 projectAndDivide(in mat4 projectionMatrix, in vec3 position) {
	vec4 homePos = projectionMatrix * vec4(position, 1);
	return homePos.xyz / homePos.w;
}

ivec2 slotToTexel(in uint slot) {
    const int slotsPerRow = ENTITY_ATLAS_SIZE / ENTITY_ATLAS_SLOT_SIZE;
    ivec2 slotCoord = ivec2(int(slot) % slotsPerRow, int(slot) / slotsPerRow);
    return slotCoord * ENTITY_ATLAS_SLOT_SIZE;
}

uint expandBits(in uint v) {
    v = (v * 0x00010001u) & 0xFF0000FFu;
    v = (v * 0x00000101u) & 0x0F00F00Fu;
    v = (v * 0x00000011u) & 0xC30C30C3u;
    v = (v * 0x00000005u) & 0x49249249u;
    return v;
}

uint mortonCode3d(in vec3 p) {
    float x = clamp(p.x * 1024.0, 0.0, 1023.0);
    float y = clamp(p.y * 1024.0, 0.0, 1023.0);
    float z = clamp(p.z * 1024.0, 0.0, 1023.0);
    uint xx = expandBits(uint(x));
    uint yy = expandBits(uint(y));
    uint zz = expandBits(uint(z));
    return xx * 4u + yy * 2u + zz;
}

float rgbToLuma(in vec3 c){
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}