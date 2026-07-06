#version 430 compatibility

#include "/lib/util.glsl"

layout(local_size_x = BVH_WORKGROUPS, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(MAX_ENTITY_TRIANGLES / BVH_WORKGROUPS, 1, 1);


const int digitShift = 8;


layout(std430, binding = 4) buffer BakedSlots {
    uint triCount;
    uint freeSlots[1024];
};
layout(std430, binding = 6) buffer SortCodes {
    uint mortonCodesA[MAX_ENTITY_TRIANGLES];
    uint sortIndicesA[MAX_ENTITY_TRIANGLES];
    uint mortonCodesB[MAX_ENTITY_TRIANGLES];
    uint sortIndicesB[MAX_ENTITY_TRIANGLES];
};
layout(std430, binding = 5) buffer Histogram {
    uint histogram[256];
    uint offsets[256];
    uint scatterCount[256];
};


void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i >= triCount) return;

    uint code = mortonCodesB[i];
    uint digit = (code >> digitShift) & 0xFFu;

    uint destination = offsets[digit] + atomicAdd(scatterCount[digit], 1u);
    mortonCodesA[destination] = code;
    sortIndicesA[destination] = sortIndicesB[i];
}