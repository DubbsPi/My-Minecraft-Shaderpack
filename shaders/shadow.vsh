#version 330 compatibility

#include "/lib/util.glsl"


uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;

in vec4 mc_Entity;

out vec2 texcoord;
out vec4 glcolor;
out vec3 worldPos;
flat out int blockId;


void main() {    
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    blockId = int(mc_Entity.x);

    vec3 shadowViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 feetPlayerPos = (shadowModelViewInverse * vec4(shadowViewPos, 1)).xyz;
    worldPos = feetPlayerPos + cameraPosition;

    gl_Position = ftransform();
    //gl_Position.xyz = distortShadowClip(gl_Position.xyz);
}