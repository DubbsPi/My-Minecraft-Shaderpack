#version 430 compatibility


layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

layout(std430, binding = 5) buffer Histogram {
    uint histogram[256];
    uint offsets[256];
    uint scatterCount[256];
};


void main() {
    histogram[gl_GlobalInvocationID.x] = 0u;
}