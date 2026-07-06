#version 430 compatibility

#include "/lib/util.glsl"


uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;

uniform sampler2D entityAtlas;

uniform sampler2D depthtex0;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform sampler2D shadowcolor0;

uniform sampler2D noisetex;

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform float far;
uniform int worldTime;
uniform float fogDensity;
uniform vec3 fogColor;

in vec2 texcoord;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;


/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA8;
const int colortex3Format = RGBA8;
const int colortex4Format = R16UI;

const int entityAtlas = RGBA8;

const int colortex10Format = RGBA8;
const int colortex11Format = RGBA8;
const int colortex12Format = RGBA8;
*/


layout(std430, binding = 4) buffer BakedSlots {
    uint entityTriCount;
    uint freeSlots[1024];
};
layout(std430, binding = 3) buffer Triangles {
    Triangle entityTriangles[MAX_ENTITY_TRIANGLES];
};


vec2 intersectSphere(in vec3 rayOrigin, in vec3 rayDir, in float radius) {
    float b = dot(rayOrigin, rayDir);
    float c = dot(rayOrigin, rayOrigin) - radius * radius;
    float d = b*b - c;
    if (d < 0.0) return vec2(-1.0);
    d = sqrt(d);
    return vec2(-b - d, -b + d);
}

float phaseRayleigh(in float mu) {
    return 0.05968310365 * (1.0 + mu * mu);
}

float phaseMie(in float mu) {
    float g  = mieG, g2 = g * g;
    return 0.11936620731 * ((1.0 - g2) * (1.0 + mu * mu)) / ((2.0 + g2) * pow(abs(1.0 + g2 - 2.0 * g * mu), 1.5));
}

float opticalDepth(in vec3 pos, in vec3 dir, in float rayLength, in float scaleHeight, in int steps) {
    float stepSize = rayLength / float(steps);
    float depth = 0.0;
    for (int i = 0; i < steps; i++) {
        vec3 p = pos + dir * (float(i) + 0.5) * stepSize;
        float h = length(p) - earthRadius;
        depth += exp(-h / scaleHeight) * stepSize;
    }
    return depth;
}

vec3 scatterAtmosphere(in vec3 viewDir, in vec3 sunDir, in vec3 moonDir, in vec3 worldPos) {
    vec3 origin = vec3(0, earthRadius + worldPos.y * 0.01, 0);

    // Get the atmospheric exit
    vec2 atmoHit = intersectSphere(origin, viewDir, atmosphereRadius);
    float tMin = max(atmoHit.x, 0.0);
    float tMax = atmoHit.y;

    float stepSize = (tMax - tMin) / float(SKY_VIEW_SAMPLES);

    vec3 sunRayleighAccum  = vec3(0);
	vec3 moonRayleighAccum = vec3(0);
	vec3 sunMieAccum  = vec3(0);
    vec3 moonMieAccum = vec3(0);
    float odR = 0.0;
	float odM = 0.0;

    float mu = dot(viewDir, sunDir);

    for (int i = 0; i < SKY_VIEW_SAMPLES; i++) {
        vec3 p = origin + viewDir * (tMin + (float(i) + 0.5) * stepSize);
        float h = length(p) - earthRadius;

        // Local density
        float densR = exp(-h / hr) * stepSize;
        float densM = exp(-h / hm) * stepSize;
        odR += densR;
        odM += densM;

		// Amount of sunlight
        vec2 sunHit = intersectSphere(p, sunDir, atmosphereRadius);
        float sunRayLen = sunHit.y;

        float sunOdR = opticalDepth(p, sunDir, sunRayLen, hr, SKY_LIGHT_SAMPLES);
        float sunOdM = opticalDepth(p, sunDir, sunRayLen, hm, SKY_LIGHT_SAMPLES);

        // Total transmittance
        vec3 sunTransmittance = exp(-(betaRayleigh * (odR + sunOdR)) - (betaMie * (odM + sunOdM) * 1.1));

        sunRayleighAccum += densR * sunTransmittance;
        sunMieAccum += densM * sunTransmittance;

		// Amount of moonlight
		vec2 moonHit = intersectSphere(p, moonDir, atmosphereRadius);
        float moonRayLen = moonHit.y;

        float moonOdR = opticalDepth(p, moonDir, moonRayLen, hr, SKY_LIGHT_SAMPLES);
        float moonOdM = opticalDepth(p, moonDir, moonRayLen, hm, SKY_LIGHT_SAMPLES);

        // Total transmittance
        vec3 moonTransmittance = exp(-(betaRayleigh * (odR + moonOdR)) - (betaMie * (odM + moonOdM) * 1.1));

        moonRayleighAccum += densR * moonTransmittance;
        moonMieAccum += densM * moonTransmittance;
    }

    vec3 skyColor = 0.67 * sunIntensity * (phaseRayleigh(mu) * betaRayleigh * sunRayleighAccum + phaseMie(mu) * betaMie * sunMieAccum);
    skyColor += 1.5 * moonIntensity * (phaseRayleigh(mu) * betaRayleigh * moonRayleighAccum + phaseMie(mu) * betaMie * moonMieAccum);
    return skyColor;
}

vec3 getSky(in vec3 rayDir, in vec3 sunDir, in vec3 moonDir, in vec3 worldPos, in bool celestials) {
	#ifdef CHEAP_SKY    
	float t = clamp(rayDir.y, 0.0, 1.0);
    vec3 skyColor = mix(fogColor, fogColor * vec3(0.5, 0.5, 0.75), t);
    
    float sunAmount = pow(max(dot(rayDir, sunDir), 0.0), 64.0) * 0.1;
    sunAmount += pow(max(dot(rayDir, sunDir), 0.0), 1024.0) * 0.2;

    sunColor *= vec3(1.0, sunDir.y * 0.5 + 0.5, sunDir.y);
    skyColor += sunColor * sunAmount * clamp((1.0 - sunDir.y) * 5.0, 1.75, 5.0);
    return pow(skyColor * clamp(sunDir.y * 2.0, 0.0, 1.0), vec3(2.2));
	
	#else
	vec3 skyColor = scatterAtmosphere(rayDir, sunDir, moonDir, worldPos);
    
    if (celestials) {
        float sunDisc = smoothstep(0.999, 1.0, dot(rayDir, sunDir));
        skyColor += 0.5 * sunIntensity * sunDisc * smoothstep(0.0, 1.0, sunDir.y);
        float moonDisk = smoothstep(0.9995, 1.0, dot(rayDir, moonDir));
        skyColor += moonIntensity * moonDisk * smoothstep(0.0, 1.0, moonDir.y);
    }

    float horizonBlend = smoothstep(-0.05, 0.05, rayDir.y);
    vec3 brown = vec3(0.35, 0.275, 0.2) * fogColor;

    if (rayDir.y > -0.15)
	    return mix(brown, skyColor, horizonBlend);
    else
        return brown;
	#endif
}

vec3 getShadow(in vec3 shadowScreenPos) {
    float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
    if (transparentShadow == 1.0) return vec3(1);  // Fully sunlit

    float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);
    if (opaqueShadow == 0.0) return vec3(0);  // Fully shadowed

    vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);
    shadowColor.rgb *= (1.0 - shadowColor.a);
    return shadowColor.rgb;
}

vec3 getSoftShadow(in vec4 shadowClipPos) {
    vec3 shadowAccum = vec3(0);
    const float samplesMult = 1.0 / float(SHADOW_RANGE * SHADOW_RANGE * 5);
    const float mult = SHADOW_RADIUS / float(SHADOW_RANGE) / float(shadowMapResolution);

    float noise = texture(noisetex, texcoord * vec2(3168.833, 2845.591)+ vec2(628.672, 338.945) * frameTimeCounter).r;
    float theta = noise * TAU;
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    
    mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

    for (int x = -SHADOW_RANGE; x <= SHADOW_RANGE; x++) {
        for (int y = -SHADOW_RANGE; y <= SHADOW_RANGE; y++) {
            vec2 offset = vec2(x, y) * mult * rotation;
            vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, shadowBias - 0.01 * length(shadowClipPos.xy), 0);
            offsetShadowClipPos.xyz = distortShadowClip(offsetShadowClipPos.xyz);
            vec3 shadowNdcPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w;
            vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;
            shadowAccum += getShadow(shadowScreenPos);
        }
    }
    return shadowAccum * samplesMult;
}

vec3 ssr(in vec3 eyeRayOrigin, in vec3 eyeRayDir, in vec3 worldRayDir, in vec3 sunDir, in vec3 moonDir, in vec3 worldPos) {
	// Rough search
	bool hit = false;
	float coarseStepSize = 0.85;
	float coarseThickness = 0.95;
	
	float stepSize = coarseStepSize;
	float thickness = coarseThickness;
	vec3 hitPos = eyeRayOrigin;

    for (int i = 0; i <= coarseSteps; i++) {
        vec3 rayPos = eyeRayOrigin + eyeRayDir * stepSize * float(i);
		stepSize  *= 1.02;
		thickness *= 1.0325;

        // Project to screen space
        vec4 clipPos = gbufferProjection * vec4(rayPos, 1.0);
        vec3 ndcPos = clipPos.xyz / clipPos.w;
        vec2 uv = ndcPos.xy * 0.5 + 0.5;

        // Boundary check
        if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) break;

        float depth = texture(depthtex0, uv).r;
        if (depth == 1.0) continue; // Skip sky

        vec4 sceneView = gbufferProjectionInverse * vec4(0.0, 0.0, depth * 2.0 - 1.0, 1.0);
        float sceneZ = sceneView.z / sceneView.w;

        float depthDiff = sceneZ - rayPos.z;
        if (depthDiff > 0.0 && depthDiff < thickness) {
			hit = true;
			hitPos = rayPos;
			break;
        }
    }

	if (!hit) return getSky(worldRayDir, sunDir, moonDir, worldPos, true);

	// Fine search
	float currentStep = coarseStepSize;
	vec2 finalUv;

	for (int i = 0; i < refiningSteps; i++) {
		currentStep *= 0.5;

		// Project to screen space
        vec4 clipPos = gbufferProjection * vec4(hitPos, 1.0);
        vec3 ndcPos = clipPos.xyz / clipPos.w;
        finalUv = ndcPos.xy * 0.5 + 0.5;

		float depth = texture(depthtex0, finalUv).r;
        if (depth == 1.0) continue; // Skip sky

        vec4 sceneView = gbufferProjectionInverse * vec4(0.0, 0.0, depth * 2.0 - 1.0, 1.0);
        float sceneZ = sceneView.z / sceneView.w;
		
		float depthDiff = sceneZ - hitPos.z;
		if (depthDiff > 0.0) {
			hitPos -= eyeRayDir * currentStep;
		} else if (depthDiff < 0.0) {
			hitPos += eyeRayDir * currentStep;
		} else {
			break;
		}
	}

	// Final sky check
	if (any(lessThan(finalUv, vec2(0.0))) || any(greaterThan(finalUv, vec2(1.0))))
		return getSky(worldRayDir, sunDir, moonDir, worldPos, true);
	
	return texture(colortex0, finalUv).rgb;
}

bool intersectTri(in vec3 rayOrigin, in vec3 rayDir, in mat3 vertices, out vec3 uvt) {
    vec3 e1 = vertices[1] - vertices[0];
    vec3 e2 = vertices[2] - vertices[0];

    vec3 normal = cross(e1, e2);
    if (dot(normal, rayDir) > 0.0) return false;

    vec3 perp = cross(rayDir, e2);
    float det = dot(e1, perp);

    if (abs(det) < epsilon) return false;

    float invDet = 1.0 / det;
    
    vec3 tVec = rayOrigin - vertices[0];
    uvt.x = dot(tVec, perp) * invDet;
    if (uvt.x < 0.0 || uvt.x > 1.0) return false;

    vec3 qVec = cross(tVec, e1);
    uvt.y = dot(rayDir, qVec) * invDet;
    if (uvt.y < 0.0 || uvt.x + uvt.y > 1.0) return false;

    uvt.z = dot(e2, qVec) * invDet;
    return uvt.z > epsilon;
}

vec3 trace(in vec3 rayOrigin, in vec3 rayDir, out Triangle tri) {
    vec2 uv = vec2(-1);
    float t = -1.0;

    for (int i = 0; i < min(entityTriCount, MAX_ENTITY_TRIANGLES); i++) {
        Triangle temp = entityTriangles[i];
        vec3 uvt = vec3(-1);
        mat3 vertices = mat3(temp.v0 + cameraPosition, temp.v1 + cameraPosition, temp.v2 + cameraPosition);
        bool hit = intersectTri(rayOrigin, rayDir, vertices, uvt);

        if (hit && (uvt.z < t || t < -0.5)) {
            tri = temp;
            uv = uvt.xy;
            t  = uvt.z;
        }
    }
    return vec3(uv, t);
}

vec3 wsr(in vec3 rayOrigin, in vec3 rayDir, in vec3 sunDir, in vec3 moonDir, in vec3 playerPos) {
    vec2 uv = vec2(-1);
    float t = -1.0;
    Triangle tri;

    vec3 uvt = trace(rayOrigin, rayDir, tri);
    uv = uvt.xy;
    t  = uvt.z;

    if (t < 0.0) return getSky(rayDir, sunDir, moonDir, playerPos, true);

    vec3 e1 = tri.v1 - tri.v0;
    vec3 e2 = tri.v2 - tri.v0;
    vec3 normal = normalize(cross(e1, e2));

    vec3 hitPos = rayOrigin + rayDir * t;
    
    // Interpolate uv between vertices
    vec2 triUv = tri.uv0 * (1.0 - uv.x - uv.y) + tri.uv1 * uv.x + tri.uv2 * uv.y;

    ivec2 pos = slotToTexel(tri.id);
    ivec2 texel = clamp(ivec2(triUv * tri.texSize), ivec2(0), tri.texSize - 1);

    vec4 color = texelFetch(entityAtlas, pos + texel, 0);
    float alpha = color.a;

    if (alpha != 1.0) {
        for (int i = 0; i < MAX_REFLECTION_TRANSPARENCY_LAYERS; i++) {
            uvt = trace(hitPos - normal * 0.0001, rayDir, tri);
            uv = uvt.xy;
            t  = uvt.z;

            if (t < -0.5) {
                color.rgb = mix(getSky(rayDir, sunDir, moonDir, playerPos, true), color.rgb, color.a);
                alpha = 1.0;
            } else {
                e1 = tri.v1 - tri.v0;
                e2 = tri.v2 - tri.v0;
                normal = normalize(cross(e1, e2));
                
                hitPos = hitPos + rayDir * t;

                triUv = tri.uv0 * (1.0 - uv.x - uv.y) + tri.uv1 * uv.x + tri.uv2 * uv.y;
                pos = slotToTexel(tri.id);
                texel = clamp(ivec2(triUv * tri.texSize), ivec2(0), tri.texSize - 1);

                vec4 newCol = texelFetch(entityAtlas, pos + texel, 0);
                color.rgb = mix(newCol.rgb, color.rgb, alpha);
                alpha = newCol.a;
            }
            if (alpha == 1.0) break;
        }
    }
    
    return color.rgb;
}


void main() {
    float depth = texture(depthtex0, texcoord).r;
	
    vec3 ndcPos  = vec3(texcoord.xy, depth) * 2.0 - 1.0;
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);

	vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1)).xyz;
	vec3 worldPos = playerPos + cameraPosition;

	vec3 skyDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

    vec3 lightDir = mat3(gbufferModelViewInverse) * shadowLightPosition * 0.01;
	vec3 sunDir  = mat3(gbufferModelViewInverse) * sunPosition * 0.01;
	vec3 moonDir = mat3(gbufferModelViewInverse) * moonPosition * 0.01;

	float timeMod = cos(float(worldTime) * 0.00004166667 * PI) * 0.5 + 0.5;

    // Sky test
    if (depth == 1.0) {
        color = vec4(getSky(skyDir, sunDir, moonDir, worldPos, true), 1);
    } else {
        color = texture(colortex0, texcoord);
        color.rgb = pow(color.rgb, vec3(2.2));  // Convert to linear

        vec4 specularSample = texture(colortex3, texcoord);

        vec4 data = texture(colortex1, texcoord);

        vec2 lightmap = data.rg;
        vec3 encodedNormal = texture(colortex2, texcoord).rgb;
        vec3 normal = normalize(encodedNormal - 0.5);  // World space normal

        vec3 blockLight = lightmap.r * blocklightColor;
        vec3 skyLight = lightmap.g * skylightColor * mix(0.01, 1.0, timeMod);

        // Shadow calculations
        vec3 shadowViewPos = (shadowModelView * vec4(playerPos, 1)).xyz;
        vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1);
        
        vec3 shadow   = getSoftShadow(shadowClipPos);
        vec3 sunLight = sunlightColor * max(dot(lightDir, normal), 0.0) * shadow * mix(0.01, 1.0, timeMod);

        color.rgb *= blockLight + skyLight + sunLight;

        // LabPBR 1.3 stuff
        float f0 = specularSample.r;

        bool isMetal = f0 >= 0.9;
        float dielectric = isMetal ? 0.04 : f0 * 0.25444444444;

        vec3 specularColor = isMetal ? color.rgb : vec3(dielectric);

        #if defined(SSR) || defined(WSR)
        if (max(specularColor.r, max(specularColor.g, specularColor.b)) > 0.01) {
            vec3 reflection = vec3(0);
            
            #ifdef SSR
            // Transform normal to eye space
            vec3 viewNormal = mat3(gbufferModelView) * normal;
            vec3 viewRayDir = reflect(normalize(viewPos), viewNormal);
            
            reflection = ssr(viewPos + viewNormal * 0.02, viewRayDir, skyDir, sunDir, moonDir, worldPos);
            #endif

            #ifdef WSR
            vec3 rayOrigin = worldPos + normal * 0.01;
            vec3 rayDir = reflect(skyDir, normal);

            #ifdef SSR
            reflection = max(reflection, wsr(rayOrigin, rayDir, sunDir, moonDir, playerPos));
            #else
            reflection = wsr(rayOrigin, rayDir, sunDir, moonDir, playerPos);
            #endif
            #endif

            color.rgb += reflection * specularColor;
		}
        #endif

        float dist = length(viewPos) / far;
        float fogFactor = pow(dist, 2.0 / max(fogDensity, 0.1));

        color.rgb = mix(color.rgb, getSky(skyDir, sunDir, moonDir, worldPos, false), clamp(fogFactor, 0.0, 1.0));
    }

    float normalized = float(entityTriCount) / float(MAX_ENTITY_TRIANGLES);
    if (gl_FragCoord.x < normalized * viewWidth && gl_FragCoord.y < 20) {
        color.rgb = vec3(normalized, 1.0 - normalized, 0.0);
    }

    // Possible patch? Research needed
    #if HDR_MOD_INSTALLED
    #else
    color.rgb = pow(color.rgb, vec3(0.45454545454));  // Convert back to gamma space
    #endif
}