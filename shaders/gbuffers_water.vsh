#version 330 compatibility

uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

uniform vec3 cameraPosition;


out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;


void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	gl_Position = ftransform();
}