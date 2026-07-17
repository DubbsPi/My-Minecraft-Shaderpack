#version 430 compatibility

#include "/lib/util.glsl"

layout (local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(128, 1, 1);

uniform int frameCounter;

layout(std430, binding = 1) buffer EntityBuffer {
    uint triCount;
    uint vertexCount;
    uint textureHashes[1024];
    ivec2 texSize[1024];
};
layout(std430, binding = 3) buffer TerrainBuffer {
    uint triCount;
    uint vertexCount;
} blocks;


void main() {
    if (gl_GlobalInvocationID.x == 0) {
        triCount = 0u;
        vertexCount = 0u;
        blocks.triCount = 0u;
        blocks.vertexCount = 0u;
    }

    textureHashes[gl_GlobalInvocationID.x] = 0u;
}
