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

void main() {
    const int bitShift = 24;
    
    uint li = gl_LocalInvocationID.x;

    localHist[li] = 0u;
    barrier();

    uint gi = gl_GlobalInvocationID.x;
    
    if (gi < blocks.triCount) {
        uint digit = (codes[gi].mortonCodesB >> bitShift) & 0xFFu;
        atomicAdd(localHist[digit], 1u);
    }
    barrier();

    histogram[li * gl_NumWorkGroups.x + gl_WorkGroupID.x] = localHist[li];
}