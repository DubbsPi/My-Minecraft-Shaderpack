#version 330 compatibility

#include "/lib/util.glsl"


uniform sampler2D colortex0;

in vec2 texcoord;


/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 bloom;

/*
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;
*/


void main() {
    bloom = texture(colortex0, texcoord);
    
    if (rgbToLuma(bloom.rgb) <= BLOOM_THREASHOLD)
        bloom = vec4(0);
}