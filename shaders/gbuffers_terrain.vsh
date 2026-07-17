#version 430 compatibility

#include "/lib/util.glsl"

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform int frameCounter;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;


layout(std430, binding = 2) buffer Vertices {
    BlockVertex data[];
} verts;
layout(std430, binding = 3) buffer TerrainBuffer {
    uint triCount;
    uint vertexCount;
} blocks;


void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

    normal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;
    
    vec3 blockViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(blockViewPos, 1)).xyz;
    
    uint vertexIndex = atomicAdd(blocks.vertexCount, 1u);
    verts.data[vertexIndex] = BlockVertex(feetPlayerPos, texcoord, glcolor);
    if ((vertexIndex & 3u) == 2u) atomicAdd(blocks.triCount, 2u);

    gl_Position = ftransform();
}