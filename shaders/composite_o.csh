#version 430 compatibility

#include "/lib/util.glsl"

#define numWorkGroups MAX_TERRAIN_TRIANGLES >> 8

layout(local_size_x = 256) in;
const ivec3 workGroups = ivec3(256, 1, 1);


layout(std430, binding = 5) buffer Histogram {
    uint digitTotals[256];
    uint histogram[];
};


shared uint scratch[numWorkGroups];
shared uint chunkSums[256];

void main() {
    const uint elementsPerThread = numWorkGroups >> 8;

    uint digit = gl_WorkGroupID.x;
    uint li = gl_LocalInvocationID.x;

    for (uint i = 0u; i < elementsPerThread; i++) {
        uint localIdx = i * 256u + li;
        uint globalIdx = digit * numWorkGroups + localIdx;
        scratch[localIdx] = (localIdx < numWorkGroups) ? histogram[globalIdx] : 0u;
    }
    barrier();

    uint threadSum = 0u;
    uint chunkStart = li * elementsPerThread;
    for (uint i = 0u; i < elementsPerThread; i++)
        threadSum += scratch[chunkStart + i];
    
    chunkSums[li] = threadSum;
    barrier();

    uint value = chunkSums[li];
    for (uint offset = 1u; offset < 256u; offset <<= 1u) {
        uint temp = 0u;
        if (li >= offset) temp = chunkSums[li - offset];
        barrier();
        chunkSums[li] += temp;
        barrier();
    }
    uint exclusiveChunkSum = chunkSums[li] - value;

    uint runningSum = exclusiveChunkSum;
    for (uint j = 0u; j < elementsPerThread; j++) {
        uint idx = chunkStart + j;
        uint originalVal = scratch[idx];
        scratch[idx] = runningSum;
        runningSum += originalVal;
    }
    barrier();

    for (uint j = 0u; j < elementsPerThread; j++) {
        uint idx = chunkStart + j;
        if (idx < numWorkGroups) {
            uint globalIdx = digit * numWorkGroups + idx;
            histogram[globalIdx] = scratch[idx];
        }
    }

    if (li == 255u)
        digitTotals[digit] = exclusiveChunkSum + value;
}