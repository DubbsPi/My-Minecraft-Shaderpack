#version 430 compatibility

#include "/lib/util.glsl"

layout(local_size_x = BVH_WORKGROUPS, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(MAX_ENTITY_TRIANGLES / BVH_WORKGROUPS, 1, 1);


layout(std430, binding = 4) buffer BakedSlots {
    uint triCount;
    uint freeSlots[1024];
};
layout(std430, binding = 3) buffer Triangles {
    Triangle triangles[MAX_ENTITY_TRIANGLES];
};
layout(std430, binding = 6) buffer SortCodes {
    uint mortonCodesA[MAX_ENTITY_TRIANGLES];
    uint sortIndicesA[MAX_ENTITY_TRIANGLES];
    uint mortonCodesB[MAX_ENTITY_TRIANGLES];
    uint sortIndicesB[MAX_ENTITY_TRIANGLES];
};


void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i >= triCount) return;

    Triangle tri = triangles[i];
    vec3 c = (tri.v0 + tri.v1 + tri.v2) * 0.33333333;
    vec3 n = normalizeScenePos(c, -vec3(MAX_ENTITY_DISTANCE), vec3(MAX_ENTITY_DISTANCE));

    mortonCodesA[i] = mortonCode3d(n);
    sortIndicesA[i] = i;
}