#version 330 compatibility

#include "/lib/util.glsl"


uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;


out vec2 texcoord;
out vec4 glcolor;
out float depth;


void main() {
    vec4 worldPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    vec4 lightSpacePos = shadowProjection * shadowModelView * worldPos;

    depth = lightSpacePos.z / lightSpacePos.w * 0.5 + 0.5;
    
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    gl_Position = ftransform();
    gl_Position.xyz = distortShadowClip(gl_Position.xyz);
}