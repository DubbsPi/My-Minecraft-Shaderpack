#version 330 compatibility

#include "/lib/util.glsl"


uniform sampler2D colortex6;
uniform float viewWidth;
uniform float viewHeight;


/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 bloom;


void main() {
    bloom = vec4(0, 0, 0, 1);

    const float reduction = float[](0.25, 0.5, 0.75, 1.0)[BLOOM_QUALITY];

    for (int y = -BLOOM_RADIUS; y <= BLOOM_RADIUS; y += BLOOM_STEP_SIZE) {
        ivec2 texel = ivec2(gl_FragCoord.xy) + ivec2(0, float(y) * reduction);
        bloom.rgb += texelFetch(colortex6, clamp(texel, ivec2(0), ivec2(viewWidth, viewHeight)), 0).rgb;
    }
    
    const float div = BLOOM_INTENSITY / float(2 * BLOOM_RADIUS / BLOOM_STEP_SIZE);
    bloom.rgb *= div;
}