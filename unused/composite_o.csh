#version 430 compatibility

#include "/lib/util.glsl"


layout(std430, binding = 4) buffer BakedSlots {
    uint triCount;
    uint freeSlots[1024];
};
layout(std430, binding = 6) buffer SortCodes {
    uint sortedCodes[MAX_ENTITY_TRIANGLES];
    uint sortIndicesA[MAX_ENTITY_TRIANGLES];
    uint mortonCodesB[MAX_ENTITY_TRIANGLES];
    uint sortIndicesB[MAX_ENTITY_TRIANGLES];
};
layout(std430, binding = 7) buffer InternalNodes {
    InternalNode internalNodes[MAX_ENTITY_TRIANGLES];
    int leafParent[MAX_ENTITY_TRIANGLES];
};


struct NodeRange {
    int start;
    int end;
    int split;
};


int commonPrefixLen(uint codeA, uint codeB) {
    if (codeA == codeB) return 32;
    return findMSB(codeA ^ codeB) >= 0 ? (31 - findMSB(codeA ^ codeB)) : 32;
}

NodeRange determineRange(int i, int numLeaves) {
    int d = (commonPrefixLen(i, i+1) > commonPrefixLen(i, i-1))? 1 : -1;

    int minPrefix = commonPrefixLen(i, i - d);

    int lmax = 2;
    while (i + lmax * d >= 0 && i + lmax * d < numLeaves && commonPrefixLen(i, i + lmax * d) > minPrefix)
        lmax *= 2;

    int l = 0;
    for (int t = lmax / 2; t >= 1; t /= 2) {
        if (i + (l + t) * d >= 0 && i + (l + t) * d < numLeaves && commonPrefixLen(i, i + (l + t) * d) > minPrefix)
            l += t;
    }
    int j = i + l * d;

    int start = min(i, j);
    int end = max(i, j);
    return NodeRange(start, end, 0);
}

int findSplit(int start, int end) {
    uint firstCode = sortedCodes[start];
    uint lastCode = sortedCodes[end];

    if (firstCode == lastCode) return (start + end) / 2;

    int commonPrefix = commonPrefixLen(start, end);

    int split = start;
    int step = end - start;
    do {
        step = (step + 1) / 2;
        int newSplit = split + step;
        if (newSplit < end) {
            int splitPrefix = commonPrefixLen(start, newSplit);
            if (splitPrefix > commonPrefix) {
                split = newSplit;
            }
        }
    } while (step > 1);

    return split;
}


void main() {
    int i = int(gl_GlobalInvocationID.x);
    int numLeaves = int(triCount);
    if (i >= numLeaves - 1) return;

    NodeRange range = determineRange(i, numLeaves);
    int split = findSplit(range.start, range.end);

    int leftChild, rightChild;
    if (split == range.start) {
        leftChild = split;
    } else {
        leftChild = split;
    }
    if (split + 1 == range.end) {
        rightChild = split + 1;
    } else {
        rightChild = split + 1;
    }

    internalNodes[i].left = leftChild;
    internalNodes[i].right = rightChild;
    internalNodes[i].isLeftLeaf = (split == range.start) ? 1 : 0;
    internalNodes[i].isRightLeaf = (split + 1 == range.end) ? 1 : 0;

    if (internalNodes[i].isLeftLeaf == 1) leafParent[split] = i;
    else internalNodes[split].parent = i;

    if (internalNodes[i].isRightLeaf == 1) leafParent[split + 1] = i;
    else internalNodes[split + 1].parent = i;
}