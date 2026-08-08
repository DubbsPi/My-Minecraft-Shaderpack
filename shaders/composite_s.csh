#version 430 compatibility

#include "/lib/util.glsl"

layout(local_size_x = 256) in;
const ivec3 workGroups = ivec3(NUM_WORKGROUPS, 1, 1);


layout(std430, binding = 3) buffer TerrainBuffer {
    uint triCount;
    uint vertexCount;
} blocks;
layout(std430, binding = 2) buffer BlockVertices {
    Vertex data[];
} blockVerts;

layout(std430, binding = 4) buffer MortonCode {
    MortonCodes codes[];
};
layout(std430, binding = 6) coherent buffer Bvh {
    BvhNode nodes[];
};
layout(std430, binding = 7) coherent buffer Flags {
    uint rootIndex;
    uint nodeCounters[];
};


mat3 getTriVerts(in uint id) {
    uint quadID = id >> 1;
    uint triInQuad = id & 1u;
    uint baseVert = quadID * 4u;

    uint i0 = baseVert;
    uint i1 = (triInQuad == 0u)? (baseVert + 1u) : (baseVert + 2u);
    uint i2 = (triInQuad == 0u)? (baseVert + 2u) : (baseVert + 3u);

    vec3 pos0 = blockVerts.data[i0].pos;
    vec3 pos1 = blockVerts.data[i1].pos;
    vec3 pos2 = blockVerts.data[i2].pos;

    return mat3(pos0, pos1, pos2);
}


void main() {
    uint i = gl_GlobalInvocationID.x;
    uint triCount = blocks.triCount;
    
    if (i >= triCount) return;

    int leafOffset = int(triCount) - 1;
    int currentLeafId = int(i) + leafOffset;

    uint triId = codes[i].triIdsA;
    mat3 tri = getTriVerts(triId);

    vec3 bMin = min(tri[0], min(tri[1], tri[2]));
    vec3 bMax = max(tri[0], max(tri[1], tri[2]));

    nodes[currentLeafId].minBounds = bMin;
    nodes[currentLeafId].maxBounds = bMax;

    int current = nodes[currentLeafId].parent;

    int iterations = 0;
    while (current != -1 && iterations < 64) {
        memoryBarrierBuffer();

        uint arrivingThreadId = atomicAdd(nodeCounters[current], 1u);
        if (arrivingThreadId == 0u) return;

        int left  = nodes[current].leftChild;
        int right = nodes[current].rightChild;

        vec3 mergedMin = min(nodes[left].minBounds, nodes[right].minBounds);
        vec3 mergedMax = max(nodes[left].maxBounds, nodes[right].maxBounds);

        nodes[current].minBounds = mergedMin;
        nodes[current].maxBounds = mergedMax;

        if (current == int(rootIndex) || current == -1) return;
        current = nodes[current].parent;

        iterations++;
    }
}