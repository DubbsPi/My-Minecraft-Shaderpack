#version 330 compatibility

uniform mat4 gbufferModelViewInverse;

uniform int worldTime;

attribute vec4 mc_Entity;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
flat out float blockType;


void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy * 1.066666667 - 0.03125;
	glcolor = gl_Color;
	blockType = int(mc_Entity.x);
	normal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;
}