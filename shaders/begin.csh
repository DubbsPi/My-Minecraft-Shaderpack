#version 430 compatibility

#include "/lib/util.glsl"


layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);


layout(std430, binding = 1) buffer EntityBuffer {
    uint triCount;
    uint vertexCount;
    uint textureHashes[1024];
    ivec2 texSize[1024];
};


void main() {
    triCount = 0u;
    vertexCount = 0u;

    for (int i = 0; i < 1024; i++)
        textureHashes[i] = 0u;
}
