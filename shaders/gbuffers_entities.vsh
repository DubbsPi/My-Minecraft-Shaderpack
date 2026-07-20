#version 430 compatibility

#include "/lib/util.glsl"


uniform sampler2D gtexture;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;

uniform int entityId;


out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
flat out int entity;


layout(std430, binding = 2) buffer Vertices {
    Vertex data[];
} verts;
layout(std430, binding = 1) buffer EntityBuffer {
    uint textureHashes[1024];
    ivec2 texSize[1024];
} entities;
layout(std430, binding = 3) buffer TerrainBuffer {
    uint triCount;
    uint vertexCount;
};

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

uint fastMod3(uint x) {
    uint div3 = (x * 0xAAABu) >> 17; 
    return x - (div3 * 3u);
}


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
    normal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;
    entity = entityId;
    
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

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1)).xyz;

    uint vertexIndex = atomicAdd(vertexCount, 1u);
    verts.data[vertexIndex] = Vertex(feetPlayerPos, texcoord, glcolor, int(assignedSlot));
    if (fastMod3(vertexIndex) == 2u) atomicAdd(triCount, 2u);

    gl_Position = ftransform();
}