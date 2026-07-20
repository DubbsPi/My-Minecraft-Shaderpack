#version 430 compatibility

#include "/lib/util.glsl"

layout(local_size_x = 256) in;
const ivec3 workGroups = ivec3(NUM_WORKGROUPS, 1, 1);


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
shared uint shared_digits[256];

void main() {
    const int bitShift = 16;

    uint li = gl_LocalInvocationID.x;
    uint gi = gl_GlobalInvocationID.x;
    uint i  = gl_WorkGroupID.x;
    const uint workGroupCount = NUM_WORKGROUPS;

    localHist[li] = 0u;
    shared_digits[li] = 256u;
    barrier();

    bool valid = gi < blocks.triCount;
    uint key = valid? codes[gi].mortonCodesA : 0u;
    uint id  = valid? codes[gi].triIdsA : 0u;
    uint digit = (key >> bitShift) & 0xFFu;

    if (valid) {
        atomicAdd(localHist[digit], 1u);
        shared_digits[li] = digit;
    }
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

    uint rank = 0;
    if (valid) {
        for (uint t = 0; t < li; t++) {
            if (shared_digits[t] == digit) {
                rank++;
            }
        }
    }

    if (valid) {
        uint globalOffset = digitTotals[digit] + histogram[digit * workGroupCount + i];
        uint destination = globalOffset + rank;

        codes[destination].mortonCodesB = key;
        codes[destination].triIdsB = id;
    }
}