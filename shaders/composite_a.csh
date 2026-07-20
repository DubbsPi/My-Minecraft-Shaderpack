#version 430 compatibility

#include "/lib/util.glsl"

layout(local_size_x = 256) in;
const ivec3 workGroups = ivec3(NUM_WORKGROUPS, 1, 1);

uniform float far;

layout(std430, binding = 2) buffer BlockVertices {
    Vertex data[];
} blockVerts;
layout(std430, binding = 3) buffer TerrainBuffer {
    uint triCount;
    uint vertexCount;
} blocks;

layout(std430, binding = 4) buffer MortonCode {
    MortonCodes codes[];
};


vec3 getBlockTriCentroid(in uint id) {
    uint quadID = id >> 1;
    uint triInQuad = id & 1u;
    uint baseVert = quadID * 4u;

    uint i0 = baseVert;
    uint i1 = (triInQuad == 0u)? (baseVert + 1u) : (baseVert + 2u);
    uint i2 = (triInQuad == 0u)? (baseVert + 2u) : (baseVert + 3u);

    vec3 v0 = blockVerts.data[i0].pos;
    vec3 v1 = blockVerts.data[i1].pos;
    vec3 v2 = blockVerts.data[i2].pos;

    return (v0 + v1 + v2) * 0.333333333;
}


void main() {
    uint i = gl_GlobalInvocationID.x;

    if (i >= blocks.triCount) return;

    vec3 c = getBlockTriCentroid(i);

    c = clamp(c / far * 0.5, 0.0, 1.0);

    codes[i].mortonCodesA = mortonCode3d(c);
    codes[i].triIdsA = i;
}