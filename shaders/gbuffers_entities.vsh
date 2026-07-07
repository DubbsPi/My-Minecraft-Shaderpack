#version 430 compatibility

#include "/lib/util.glsl"


uniform sampler2D gtexture;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;


layout(std430, binding = 0) buffer Vertices {
    RawVertex data[];
} verts;
layout(std430, binding = 1) buffer EntityBuffer {
    uint triCount;
    uint vertexCount;
    uint textureHashes[1024];
    ivec2 texSize[1024];
} entities;

layout(rgba8) uniform image2D entityatlas;


uint getTextureHash() {
    const vec2 taps[4] = vec2[4](vec2(0.15,0.15), vec2(0.85,0.15), vec2(0.15,0.85), vec2(0.85,0.85));
    uint h = 2166136261u;
    for (int i = 0; i < 4; i++) {
        uint c = packUnorm4x8(textureLod(gtexture, taps[i], 4.0));
        h = (h ^ c) * 16777619u;
    }
    return (h == 0u) ? 1u : h;
}

void bakeTexture(in int slot) {
    const int slotsPerRow = int(ENTITY_ATLAS_SIZE / ENTITY_ATLAS_SLOT_SIZE);
    ivec2 pos = ivec2(slot % slotsPerRow, slot / slotsPerRow) * ENTITY_ATLAS_SLOT_SIZE;
    ivec2 texSize = min(textureSize(gtexture, 0), ivec2(ENTITY_ATLAS_SLOT_SIZE));

    entities.texSize[slot] = texSize;
    for (int x = 0; x < texSize.x; x++) {
        for (int y = 0; y < texSize.y; y++) {
            imageStore(entityatlas, pos + ivec2(x, y), texelFetch(gtexture, ivec2(x, y), 0));
        }
    }
}


void main() {
    uint texHash = getTextureHash();
    uint assignedSlot = 0xffffffffu;
    uint initialPos = texHash % 1024u;

    for (uint i = 0u; i < 4u; i++) {
        uint checkSlot = (initialPos + i) % 1024u;
        
        uint existingHash = atomicCompSwap(entities.textureHashes[checkSlot], 0u, texHash);
        
        if (existingHash == 0u) {
            bakeTexture(int(checkSlot));
            assignedSlot = checkSlot;
            break;
        } 
        else if (existingHash == texHash) {
            assignedSlot = checkSlot;
            break;
        }
    }

    if (assignedSlot == 0xffffffffu) assignedSlot = 0u;

	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

    normal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;

    vec3 blockViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(blockViewPos, 1)).xyz;

    uint vertexIndex = atomicAdd(entities.vertexCount, 1u);
    verts.data[vertexIndex] = RawVertex(feetPlayerPos, normal, texcoord, assignedSlot);
    if ((vertexIndex & 3u) == 2u) atomicAdd(entities.triCount, 2u);
    
    gl_Position = ftransform();
}