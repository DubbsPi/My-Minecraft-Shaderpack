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
layout(std430, binding = 6) coherent buffer Bvh {
    BvhNode nodes[];
};
layout(std430, binding = 7) coherent buffer Flags {
    uint rootIndex;
    uint nodeCounters[];
};


int delta(in int i, in int j, in int triCount) {
    if (j < 0 || j >= triCount) return -1;

    // 🍎
    uint iKey = codes[i].mortonCodesA;
    uint jKey = codes[j].mortonCodesA;

    if (iKey != jKey)
        return 31 - findMSB(iKey ^ jKey);
    return 32 + (31 - findMSB(uint(i ^ j)));
}


void main() {
    int i = int(gl_GlobalInvocationID.x);
    int triCount = int(blocks.triCount);

    if (i >= triCount - 1) return;

    int d = sign(delta(i, i + 1, triCount) - delta(i, i - 1, triCount));
    if (d == 0) d = 1;

    int deltaMin = delta(i, i - d, triCount);
    int lMax = 2;
    while (delta(i, i + lMax * d, triCount) > deltaMin)
        lMax *= 2;
    
    int l = 0;
    for (int div = lMax >> 1; div > 0; div >>= 1) {
        if (delta(i, i + (l + div) * d, triCount) > deltaMin)
            l += div;
    }

    int j = i + l * d;

    if (min(i, j) == 0 && max(i, j) == triCount - 1)
        rootIndex = i;

    int deltaNode = delta(i, j, triCount);
    int s = 0;

    int div = l;
    do {
        div = (div + 1) >> 1;
        if (delta(i, i + (s + div) * d, triCount) > deltaNode)
            s += div;
    } while (div > 1);

    int split = i + s * d + min(d, 0);

    int left = split;
    int right = split + 1;

    int leafOffset = triCount - 1;

    int finalLeft  = min(i, j) == left? left + leafOffset : left;
    int finalRight = max(i, j) == right? right + leafOffset : right;

    nodes[i].leftChild  = finalLeft;
    nodes[i].rightChild = finalRight;

    nodes[finalLeft].parent = i;
    nodes[finalRight].parent = i;
}