#version 430 compatibility

#include "/lib/util.glsl"


uniform vec3 cameraPosition;
uniform sampler2D gtexture;
uniform int entityId;


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in vec2 lmcoord[];
in vec2 texcoord[];
in vec4 glcolor[];
in vec3 normal[];
in vec3 worldPos[];

out vec2 lmCoord;
out vec2 texCoord;
out vec4 glColor;
out vec3 Normal;


layout(std430, binding = 3) buffer Triangles {
    Triangle triangles[MAX_ENTITY_TRIANGLES];
};
layout(std430, binding = 4) buffer BakedSlots {
    uint triCount;
    uint freeSlots[1024];
};

layout(rgba8) uniform image2D entityatlas;


uint getId() {
    const vec2 taps[4] = vec2[4](vec2(0.15,0.15), vec2(0.85,0.15), vec2(0.15,0.85), vec2(0.85,0.85));
    uint h = 2166136261u;
    for (int i = 0; i < 4; i++) {
        uint c = packUnorm4x8(textureLod(gtexture, taps[i], 4.0));
        h = (h ^ c) * 16777619u;
    }
    return h % 1024u;
}

void emitTriangle(in vec3 v0, in vec3 v1, in vec3 v2, in vec2 uv0, in vec2 uv1, in vec2 uv2, in uint id) {
    uint slot = atomicAdd(triCount, 1u);
    if (slot >= MAX_ENTITY_TRIANGLES) return;

    if (any(greaterThan(abs(max(v0, max(v1, v2)) - cameraPosition), vec3(MAX_ENTITY_DISTANCE)))) return;

    Triangle t;
    t.v0 = v0 - cameraPosition;
    t.v1 = v1 - cameraPosition;
    t.v2 = v2 - cameraPosition;
    t.uv0 = uv0;
    t.uv1 = uv1;
    t.uv2 = uv2;
    t.id  = id;
    t.texSize = min(textureSize(gtexture, 0), ivec2(ENTITY_ATLAS_SLOT_SIZE));

    triangles[slot] = t;
}

void bakeTexture(in int slot) {
    const int slotsPerRow = int(floor(ENTITY_ATLAS_SIZE / ENTITY_ATLAS_SLOT_SIZE));
    ivec2 pos = ivec2(slot % slotsPerRow, slot / slotsPerRow) * ENTITY_ATLAS_SLOT_SIZE;
    ivec2 texSize = min(textureSize(gtexture, 0), ivec2(ENTITY_ATLAS_SLOT_SIZE));

    for (int x = 0; x < texSize.x; x++) {
        for (int y = 0; y < texSize.y; y++) {
            imageStore(entityatlas, pos + ivec2(x, y), texelFetch(gtexture, ivec2(x, y), 0));
        }
    }
}


void main() {
    uint id = getId();
    emitTriangle(worldPos[0], worldPos[1], worldPos[2], texcoord[0], texcoord[1], texcoord[2], id);
    
    if (freeSlots[id] == 0u) {
        if (atomicCompSwap(freeSlots[id], 0u, 1u) == 0u) {
            bakeTexture(int(id));
        }
    }

    for (int i = 0; i < 3; i++) {
        gl_Position = gl_in[i].gl_Position;
        texCoord = texcoord[i];
        lmCoord = lmcoord[i];
        glColor = glcolor[i];
        
        Normal = normal[i];
        EmitVertex();
    }
    EndPrimitive();
}