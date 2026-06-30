#version 330 compatibility


uniform sampler2D gdepthtex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;

uniform float frameTimeCounter;

in vec4 mc_Entity;


out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 worldPos;
flat out int blockId;


void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy * 1.066666667 - 0.03125;
	glcolor = gl_Color;
	normal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;
	blockId = int(mc_Entity.x);

	vec3 blockViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(blockViewPos, 1)).xyz;
    worldPos = feetPlayerPos + cameraPosition;

    vec4 vertexPos = gl_Vertex;
    gl_Position = gl_ModelViewProjectionMatrix * vertexPos;
}