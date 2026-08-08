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

void main() {
    const int bitShift = 16;
    
    uint li = gl_LocalInvocationID.x;
    const uint workGroupCount = NUM_WORKGROUPS;

    localHist[li] = 0u;
    barrier();

    uint gi = gl_GlobalInvocationID.x;
    
    if (gi < blocks.triCount) {
        uint digit = (codes[gi].mortonCodesA >> bitShift) & 0xFFu;
        atomicAdd(localHist[digit], 1u);
    }
    barrier();

    histogram[li * workGroupCount + gl_WorkGroupID.x] = localHist[li];
}