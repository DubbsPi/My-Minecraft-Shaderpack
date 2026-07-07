#version 330 compatibility


uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;


void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

    normal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;
    
    vec3 blockViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(blockViewPos, 1)).xyz;
    vec3 worldPos = feetPlayerPos + cameraPosition;
    
    gl_Position = ftransform();
}