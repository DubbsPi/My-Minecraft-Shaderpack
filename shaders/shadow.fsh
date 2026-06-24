#version 330 compatibility


uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 color;


const int shadowMapResolution = 2048;
const float shadowDistanceRenderMul = 1.0;


void main() {
  color = texture(gtexture, texcoord) * glcolor;
  if(color.a < alphaTestRef){
    discard;
  }
}