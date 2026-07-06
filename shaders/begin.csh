#version 430 compatibility


layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);


layout(std430, binding = 4) buffer BakedSlots {
    uint triCount;
    uint freeSlots[1024];
};


void main() {
    triCount = 0u;
}
