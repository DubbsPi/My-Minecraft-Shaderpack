#version 430 compatibility

#include "/lib/util.glsl"

layout(local_size_x = 256) in;
const ivec3 workGroups = ivec3(1, 1, 1);


layout(std430, binding = 3) buffer TerrainBuffer {
    uint triCount;
    uint vertexCount;
} blocks;

layout(std430, binding = 5) buffer Histogram {
    uint digitTotals[256];
    uint histogram[];
};


shared uint scratch[256];

void main() {
    uint li = gl_LocalInvocationID.x;
    uint value = digitTotals[li];
    scratch[li] = value;
    barrier();

    for (uint offset = 1u; offset < 256u; offset <<= 1u) {
        uint temp = 0u;
        if (li >= offset) temp = scratch[li - offset];
        barrier();
        scratch[li] += temp;
        barrier();
    }

    digitTotals[li] = scratch[li] - value;
}