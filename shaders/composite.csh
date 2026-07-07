#version 430 compatibility

#include "/lib/util.glsl"

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(MAX_ENTITY_TRIANGLES / 256, 1, 1);


layout(std430, binding = 0) readonly buffer Vertices {
    RawVertex data[];
} verts;
layout(std430, binding = 1) buffer EntityBuffer {
    uint triCount;
    uint vertexCount;
    uint textureHashes[1024];
    ivec2 texSize[1024];
} entities;
layout(std430, binding = 2) buffer EntityTris {
    Triangle triangles[MAX_ENTITY_TRIANGLES];
} tris;


Triangle getTri(in uint id) {
    uint quadID = id >> 1;
    uint triInQuad = id & 1u;
    uint baseVert = quadID * 4u;

    uint i0 = baseVert;
    uint i1 = (triInQuad == 0u)? (baseVert + 1u) : (baseVert + 2u);
    uint i2 = (triInQuad == 0u)? (baseVert + 2u) : (baseVert + 3u);

    RawVertex v0 = verts.data[i0];
    RawVertex v1 = verts.data[i1];
    RawVertex v2 = verts.data[i2];

    return Triangle(v0.pos, v1.pos, v2.pos, v0.uv, v1.uv, v2.uv, v0.id, entities.texSize[v0.id]);
}

bool isValidTri(in Triangle tri) {
    if (tri.id >= MAX_ENTITY_TRIANGLES) return false;
    if (tri.texSize == ivec2(0)) return false;
    if (any(greaterThan(max(tri.v0, max(tri.v1, tri.v2)), vec3(MAX_ENTITY_DISTANCE)))) return false;
    if (any(lessThan(min(tri.uv0, min(tri.uv1, tri.uv2)), vec2(0)))) return false;
    if (any(greaterThan(min(tri.uv0, min(tri.uv1, tri.uv2)), vec2(1)))) return false;
    return true;
}


void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i >= entities.triCount) return;

    Triangle tri = getTri(i);
    if (isValidTri(tri)) {
        tris.triangles[i] = tri;
    }
}