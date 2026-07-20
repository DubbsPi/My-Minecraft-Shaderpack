#version 330 compatibility

#include "/lib/util.glsl"


uniform sampler2D colortex0;
uniform sampler2D colortex7;

uniform sampler2D noisetex;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

in vec2 texcoord;


void main() {
    vec2 finalUv = texcoord;
    #ifdef FXAA
    vec2 invScreenSize = 1.0 / vec2(viewWidth, viewHeight);

    vec3 colorCenter = texture(colortex0, texcoord).rgb;
    float lumaCenter = rgbToLuma(colorCenter);

    float lumaDown = rgbToLuma(textureOffset(colortex0, texcoord, ivec2(0, -1)).rgb);
    float lumaUp = rgbToLuma(textureOffset(colortex0, texcoord, ivec2(0, 1)).rgb);
    float lumaLeft = rgbToLuma(textureOffset(colortex0, texcoord, ivec2(-1, 0)).rgb);
    float lumaRight = rgbToLuma(textureOffset(colortex0, texcoord, ivec2(1, 0)).rgb);

    float lumaMin = min(lumaCenter, min(min(lumaDown, lumaUp), min(lumaLeft, lumaRight)));
    float lumaMax = max(lumaCenter, max(max(lumaDown, lumaUp), max(lumaLeft, lumaRight)));

    float lumaRange = lumaMax - lumaMin;

    if (lumaRange < max(EDGE_THRESHOLD_MIN, lumaMax * EDGE_THRESHOLD_MAX)){
        // Dithering
        vec3 noise = texture(noisetex, texcoord * vec2(135.126, 290.297) + vec2(628.672, 338.945) * frameTimeCounter).rgb;
        gl_FragColor = vec4(pow(colorCenter + texture(colortex7, texcoord).rgb, vec3(0.454545454545)) + (noise - 0.5) * 0.006, 1);
        return;
    }
    
    float lumaDownLeft = rgbToLuma(textureOffset(colortex0, texcoord, ivec2(-1, -1)).rgb);
    float lumaUpRight = rgbToLuma(textureOffset(colortex0, texcoord, ivec2(1, 1)).rgb);
    float lumaUpLeft = rgbToLuma(textureOffset(colortex0, texcoord, ivec2(-1, 1)).rgb);
    float lumaDownRight = rgbToLuma(textureOffset(colortex0, texcoord, ivec2(1, -1)).rgb);

    float lumaDownUp = lumaDown + lumaUp;
    float lumaLeftRight = lumaLeft + lumaRight;

    float lumaLeftCorners = lumaDownLeft + lumaUpLeft;
    float lumaDownCorners = lumaDownLeft + lumaDownRight;
    float lumaRightCorners = lumaDownRight + lumaUpRight;
    float lumaUpCorners = lumaUpRight + lumaUpLeft;

    float edgeHorizontal = abs(-2.0 * lumaLeft + lumaLeftCorners) + abs(-2.0 * lumaCenter + lumaDownUp) * 2.0 + abs(-2.0 * lumaRight + lumaRightCorners);
    float edgeVertical = abs(-2.0 * lumaUp + lumaUpCorners) + abs(-2.0 * lumaCenter + lumaLeftRight) * 2.0 + abs(-2.0 * lumaDown + lumaDownCorners);

    bool isHorizontal = edgeHorizontal >= edgeVertical;

    float luma1 = isHorizontal ? lumaDown : lumaLeft;
    float luma2 = isHorizontal ? lumaUp : lumaRight;

    float gradient1 = luma1 - lumaCenter;
    float gradient2 = luma2 - lumaCenter;

    bool is1Steepest = abs(gradient1) >= abs(gradient2);

    float gradientScaled = 0.25 * max(abs(gradient1), abs(gradient2));

    float stepLength = isHorizontal? invScreenSize.y : invScreenSize.x;

    float lumaLocalAverage = 0.0;
    if (is1Steepest) {
        stepLength = - stepLength;
        lumaLocalAverage = 0.5 * (luma1 + lumaCenter);
    } else {
        lumaLocalAverage = 0.5 * (luma2 + lumaCenter);
    }

    vec2 currentUv = texcoord;
    if (isHorizontal) {
        currentUv.y += stepLength * 0.5;
    } else {
        currentUv.x += stepLength * 0.5;
    }
    
    vec2 offset = isHorizontal? vec2(invScreenSize.x, 0) : vec2(0, invScreenSize.y);

    vec2 uv1 = currentUv - offset;
    vec2 uv2 = currentUv + offset;

    float lumaEnd1 = rgbToLuma(texture(colortex0, uv1).rgb);
    float lumaEnd2 = rgbToLuma(texture(colortex0, uv2).rgb);
    lumaEnd1 -= lumaLocalAverage;
    lumaEnd2 -= lumaLocalAverage;

    bool reached1 = abs(lumaEnd1) >= gradientScaled;
    bool reached2 = abs(lumaEnd2) >= gradientScaled;
    bool reachedBoth = reached1 && reached2;

    if (!reached1) {
        uv1 -= offset;
    }
    if (!reached2) {
        uv2 += offset;
    }

    if (!reachedBoth){
        for(int i = 2; i < ITERATIONS; i++){
            if (!reached1) {
                lumaEnd1 = rgbToLuma(texture(colortex0, uv1).rgb);
                lumaEnd1 = lumaEnd1 - lumaLocalAverage;
            }
            if (!reached2) {
                lumaEnd2 = rgbToLuma(texture(colortex0, uv2).rgb);
                lumaEnd2 = lumaEnd2 - lumaLocalAverage;
            }
            reached1 = abs(lumaEnd1) >= gradientScaled;
            reached2 = abs(lumaEnd2) >= gradientScaled;
            reachedBoth = reached1 && reached2;

            if (!reached1) {
                uv1 -= offset * QUALITY(i);
            }
            if (!reached2) {
                uv2 += offset * QUALITY(i);
            }

            if (reachedBoth) break;
        }
    }

    float distance1 = isHorizontal? (texcoord.x - uv1.x) : (texcoord.y - uv1.y);
    float distance2 = isHorizontal? (uv2.x - texcoord.x) : (uv2.y - texcoord.y);

    bool isDirection1 = distance1 < distance2;
    float distanceFinal = min(distance1, distance2);

    float edgeThickness = (distance1 + distance2);

    float pixelOffset = - distanceFinal / edgeThickness + 0.5;

    bool isLumaCenterSmaller = lumaCenter < lumaLocalAverage;
    bool correctVariation = ((isDirection1? lumaEnd1 : lumaEnd2) < 0.0) != isLumaCenterSmaller;

    float finalOffset = correctVariation? pixelOffset : 0.0;

    float lumaAverage = (1.0/12.0) * (2.0 * (lumaDownUp + lumaLeftRight) + lumaLeftCorners + lumaRightCorners);

    float subPixelOffset1 = clamp(abs(lumaAverage - lumaCenter) / lumaRange, 0.0, 1.0);
    float subPixelOffset2 = (-2.0 * subPixelOffset1 + 3.0) * subPixelOffset1 * subPixelOffset1;
    float subPixelOffsetFinal = subPixelOffset2 * subPixelOffset2 * SUBPIXEL_QUALITY;

    finalOffset = max(finalOffset, subPixelOffsetFinal);

    if (isHorizontal) {
        finalUv.y += finalOffset * stepLength;
    } else {
        finalUv.x += finalOffset * stepLength;
    }

    #endif
    // Dithering
    vec3 noise = texture(noisetex, texcoord * vec2(135.126, 290.297) + vec2(628.672, 338.945) * frameTimeCounter).rgb;
    vec4 finalColor = texture(colortex0, finalUv) + texture(colortex7, finalUv);
    gl_FragColor = vec4(pow(finalColor.rgb, vec3(0.454545454545)) + (noise - 0.5) * 0.006, 1);
}