#version 430 compatibility

#include "/lib/util.glsl"

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);


layout(std430, binding = 5) buffer Histogram {
    uint histogram[256];
    uint offsets[256];
    uint scatterCount[256];
};

shared uint temp[256];


void main() {
    uint tid = gl_LocalInvocationID.x;
    temp[tid] = histogram[tid];
    barrier();

    for (uint stride = 1u; stride < 256u; stride *= 2u) {
        uint val = 0u;
        if (tid >= stride) val = temp[tid - stride];
        barrier();
        temp[tid] += val;
        barrier();
    }

    offsets[tid] = tid == 0u? 0u : temp[tid - 1u];
    histogram[tid] = 0u;
}