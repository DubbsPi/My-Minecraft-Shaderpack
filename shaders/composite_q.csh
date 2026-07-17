#version 430 compatibility

#include "/lib/util.glsl"

layout(local_size_x = 256) in;
const ivec3 workGroups = ivec3(MAX_TERRAIN_TRIANGLES >> 8, 1, 1);


layout(std430, binding = 3) buffer TerrainBuffer {
    uint triCount;
    uint vertexCount;
} blocks;
layout(std430, binding = 4) buffer MortonCode {
    MortonCodes codes[];
};
layout(std430, binding = 5) buffer Histogram {
    uint digitTotals[256];
    uint histogram[];
};


shared uint localHist[256];
shared uint localOffsets[256];

void main() {
    const int bitShift = 24;

    uint li = gl_LocalInvocationID.x;
    uint gi = gl_GlobalInvocationID.x;
    uint i  = gl_WorkGroupID.x;
    uint numWorkGroups = gl_NumWorkGroups.x;

    localHist[li] = 0u;
    barrier();

    bool valid = gi < blocks.triCount;
    uint key = valid? codes[gi].mortonCodesB : 0u;
    uint id  = valid? codes[gi].triIdsB : 0u;
    uint digit = (key >> bitShift) & 0xFFu;

    if (valid) atomicAdd(localHist[digit], 1u);
    barrier();

    if (li < 256) localOffsets[li] = localHist[li];
    barrier();
    for (uint offset = 1u; offset < 256; offset <<= 1u) {
        uint temp = 0u;
        if (li >= offset && li < 256) temp = localOffsets[li - offset];
        barrier();
        if (li < 256) localOffsets[li] += temp;
        barrier();
    }

    if (li < 256) localOffsets[li] -= localHist[li];
    barrier();

    localHist[li] = localOffsets[li];
    barrier();

    uint rank;
    if (valid)
        rank = atomicAdd(localHist[digit], 1u) - localOffsets[digit];
    barrier();

    if (valid) {
        uint globalOffset = digitTotals[digit] + histogram[digit * numWorkGroups + i];
        uint destination = globalOffset + rank;

        codes[destination].mortonCodesA = key;
        codes[destination].triIdsA = id;
    }
}