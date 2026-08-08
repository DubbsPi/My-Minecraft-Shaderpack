#version 430 compatibility

#include "/lib/util.glsl"


uniform sampler2D colortex0;

uniform sampler2D colortex8;
uniform sampler2D colortex9;

uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;

uniform sampler2D entityAtlas;
uniform sampler2D skyConstants;

uniform mat4 gbufferModelViewInverse;

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform int worldTime;

uniform vec3 fogColor;
uniform vec3 cameraPosition;
uniform float eyeAltitude;

in vec2 texcoord;


/* RENDERTARGETS: 13 */
layout(location = 0) out vec4 color;


layout(std430, binding = 1) buffer EntityBuffer {
    uint textureHashes[1024];
    ivec2 texSize[1024];
} entities;

layout(std430, binding = 2) buffer BlockVertices {
    Vertex data[];
} blockVerts;
layout(std430, binding = 3) buffer TerrainBuffer {
    uint triCount;
    uint vertexCount;
} blocks;

layout(std430, binding = 4) buffer MortonCode {
    MortonCodes codes[];
};
layout(std430, binding = 6) coherent buffer Bvh {
    BvhNode nodes[];
};
layout(std430, binding = 7) coherent buffer Flags {
    uint rootIndex;
    uint nodeCounters[];
};


struct HitInfo {
    vec2 uv;
    float t;
    bool hit;
    uint triId;
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

vec3 scatterAtmosphere(in vec3 viewDir, in vec3 sunDir, in vec3 moonDir) {
    vec3 origin = vec3(0, earthRadius + eyeAltitude, 0);

    // Get the atmospheric exit
    vec2 atmoHit = intersectSphere(origin, viewDir, atmosphereRadius);
    float tMin = max(atmoHit.x, 0.0);
    float tMax = atmoHit.y;

    vec2 groundHit = intersectSphere(origin, viewDir, earthRadius);
    if (groundHit.x > 0.0)
        tMax = min(tMax, groundHit.x);

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

vec3 getSky(in vec3 rayDir, in vec3 sunDir, in vec3 moonDir, in float timeMod, in bool celestials) {
	#ifdef CHEAP_SKY    
	float t = clamp(rayDir.y, 0.0, 1.0);
    vec3 skyColor = mix(fogColor, fogColor * vec3(0.5, 0.5, 0.75), t);
    
    float sunAmount = pow(max(dot(rayDir, sunDir), 0.0), 64.0) * 0.1;
    sunAmount += pow(max(dot(rayDir, sunDir), 0.0), 1024.0) * 0.2;

    vec3 sunColor = vec3(1);
    sunColor *= vec3(1.0, sunDir.y * 0.5 + 0.5, sunDir.y);
    skyColor += sunColor * sunAmount * clamp((1.0 - sunDir.y) * 5.0, 1.75, 5.0);
    return pow(skyColor * clamp(sunDir.y * 2.0, 0.0, 1.0), vec3(2.2));
	
	#else
    rayDir.y = max(rayDir.y, -0.25);
    
	vec3 skyColor = scatterAtmosphere(rayDir, sunDir, moonDir);
    
    if (celestials) {
        float sunDisc = smoothstep(0.99925, 1.0, dot(rayDir, sunDir));
        skyColor += 0.75 * sunIntensity * sunDisc * smoothstep(0.0, 1.0, sunDir.y);
        float moonDisk = smoothstep(0.9995, 1.0, dot(rayDir, moonDir));
        skyColor += moonIntensity * moonDisk * smoothstep(0.0, 1.0, moonDir.y);
    }

    return skyColor;
    #endif
}

bool intersectTri(in vec3 rayOrigin, in vec3 rayDir, in mat3 vertices, out vec3 uvt) {
    vec3 e1 = vertices[1] - vertices[0];
    vec3 e2 = vertices[2] - vertices[0];

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

bool intersectBox(in vec3 rayOrigin, in vec3 inverseDir, in vec3 bMin, in vec3 bMax, in float tMax, out float tHit) {
    vec3 t0 = (bMin - rayOrigin) * inverseDir;
    vec3 t1 = (bMax - rayOrigin) * inverseDir;

    vec3 tSmall = min(t0, t1);
    vec3 tBig = max(t0, t1);

    float tEnter = max(tSmall.x, max(tSmall.y, tSmall.z));
    float tExit  = min(tBig.x, min(tBig.y, tBig.z));

    tHit = max(tEnter, 0.0);
    return tExit >= tHit && tEnter <= tMax;
}

Triangle getTri(in uint id) {
    uint quadID = id >> 1;
    uint triInQuad = id & 1u;
    uint baseVert = quadID * 4u;

    uint i0 = baseVert;
    uint i1 = (triInQuad == 0u)? (baseVert + 1u) : (baseVert + 2u);
    uint i2 = (triInQuad == 0u)? (baseVert + 2u) : (baseVert + 3u);

    Vertex v0 = blockVerts.data[i0];
    Vertex v1 = blockVerts.data[i1];
    Vertex v2 = blockVerts.data[i2];

    vec2 uv0 = unpackUnorm2x16(v0.uv);
    vec2 uv1 = unpackUnorm2x16(v1.uv);
    vec2 uv2 = unpackUnorm2x16(v2.uv);

    vec4 glcolor0 = unpackUnorm4x8(v0.glcolor);
    vec4 glcolor1 = unpackUnorm4x8(v1.glcolor);
    vec4 glcolor2 = unpackUnorm4x8(v2.glcolor);

    return Triangle(v0.pos, v1.pos, v2.pos, uv0, uv1, uv2, glcolor0, glcolor1, glcolor2, v0.id, v0.id >= 0? entities.texSize[v0.id] : ivec2(0));
}

mat3 getTriVerts(in uint id) {
    uint quadID = id >> 1;
    uint triInQuad = id & 1u;
    uint baseVert = quadID * 4u;

    uint i0 = baseVert;
    uint i1 = (triInQuad == 0u)? (baseVert + 1u) : (baseVert + 2u);
    uint i2 = (triInQuad == 0u)? (baseVert + 2u) : (baseVert + 3u);

    vec3 pos0 = blockVerts.data[i0].pos;
    vec3 pos1 = blockVerts.data[i1].pos;
    vec3 pos2 = blockVerts.data[i2].pos;

    return mat3(pos0, pos1, pos2);
}

HitInfo trace(in vec3 rayOrigin, in vec3 rayDir) {
    vec3 inverseDir = 1.0 / rayDir;
    float tMax = TRACE_TMAX;
    
    HitInfo result = HitInfo(vec2(0), -1.0, false, 0u);

    vec3 localRayOrigin = rayOrigin - cameraPosition;

    int triCount = int(blocks.triCount);
    int leafOffset = triCount - 1;

    int stack[TRACE_STACK_SIZE];
    int stackPointer = 0;
    int current = int(rootIndex);

    while (true) {
        if (current >= leafOffset) {
            uint leafId = uint(current - leafOffset);
            uint triId = codes[leafId].triIdsA;
            mat3 verts = getTriVerts(triId);

            vec3 uvt;
            if (intersectTri(localRayOrigin, rayDir, verts, uvt)) {
                result = HitInfo(uvt.xy, uvt.z, true, triId);
                tMax = uvt.z;
            }
        } else {
            int left  = nodes[current].leftChild;
            int right = nodes[current].rightChild;

            float tLeft, tRight;
            vec3 lMinBounds = nodes[left].minBounds;
            vec3 lMaxBounds = nodes[left].maxBounds;
            vec3 rMinBounds = nodes[right].minBounds;
            vec3 rMaxBounds = nodes[right].maxBounds;

            bool hitLeft  = intersectBox(localRayOrigin, inverseDir, lMinBounds, lMaxBounds, tMax, tLeft);
            bool hitRight = intersectBox(localRayOrigin, inverseDir, rMinBounds, rMaxBounds, tMax, tRight);

            if (hitLeft && hitRight) {
                if (tLeft > tRight) {
                    // Swap the two
                    int temp = left;
                    left = right;
                    right = temp;
                }
                if (stackPointer < TRACE_STACK_SIZE)
                    stack[stackPointer++] = right;
                current = left;
                continue;
            } else if (hitLeft) {
                current = left;
                continue;
            } else if (hitRight) {
                current = right;
                continue;
            }
        }

        if (stackPointer == 0) break;
        current = stack[--stackPointer];
    }
    return result;
}

vec3 wsr(in vec3 rayOrigin, in vec3 rayDir, in vec3 sunDir, in vec3 moonDir, in vec3 lightDir, in float timeMod, in vec3 sunLightColor, in vec3 skyLightColor) {
    vec3 finalColor = vec3(0);
    float transmittance = 1.0;
    vec3 ro = rayOrigin;
    vec3 sky = getSky(rayDir, sunDir, moonDir, timeMod, true);

    for (int i = 0; i < MAX_REFLECTION_TRANSPARENCY_LAYERS; i++) {
        HitInfo result = trace(ro, rayDir);

        if (!result.hit) {
            finalColor += transmittance * sky;
            transmittance = 0.0;
            break;
        }

        Triangle tri = getTri(result.triId);
        bool entity = tri.id >= 0;

        vec3 hitPos = ro + rayDir * result.t;
        vec3 e1 = tri.v1 - tri.v0;
        vec3 e2 = tri.v2 - tri.v0;
        vec3 normal = normalize(cross(e1, e2));

        // Interpolate between vertices
        vec2 triUv  = tri.uv0 * (1.0 - result.uv.x - result.uv.y) + tri.uv1 * result.uv.x + tri.uv2 * result.uv.y;
        vec4 glcolor = tri.glcolor0 * (1.0 - result.uv.x - result.uv.y) + tri.glcolor1 * result.uv.x + tri.glcolor2 * result.uv.y;

        vec4 color;
        if (entity) {
            ivec2 pos = slotToTexel(tri.id);
            ivec2 texel = clamp(ivec2(triUv * tri.texSize), ivec2(0), tri.texSize - 1);
            color = texelFetch(entityAtlas, pos + texel, 0);
        } else {
            color = texture(colortex10, triUv) * glcolor;
        }
        
        if (color.a > 0.01) {
            vec3 lighting = sunLightColor * max(dot(lightDir, normal), 0.0) * mix(0.01, 1.0, timeMod) + skyLightColor;
            vec3 litColor = color.rgb * lighting;

            finalColor += transmittance * litColor * color.a;
            transmittance *= 1.0 - color.a;

            if (transmittance < 0.05) {
                transmittance = 0.0;
                break;
            }
        }

        if (dot(rayDir, normal) > 0.0)
            normal = -normal;
        
        ro = hitPos - normal * 0.01;
    }

    // If transmittance is 0, this does nothing. Better than a tiny branch
    finalColor += transmittance * sky;
    return finalColor;
}


void main() {
    if (any(greaterThanEqual(texcoord, vec2(REFLECTION_SCALE)))) {
        color = vec4(0);
        return;
    }

    vec3 lightDir = mat3(gbufferModelViewInverse) * shadowLightPosition * 0.01;
	vec3 sunDir  = mat3(gbufferModelViewInverse) * sunPosition * 0.01;
	vec3 moonDir = mat3(gbufferModelViewInverse) * moonPosition * 0.01;

	float timeMod = cos(float(worldTime) * 0.00004166667 * PI) * 0.5 + 0.5;

    vec3 skyLightColor = texelFetch(skyConstants, ivec2(0, 0), 0).rgb;
    vec3 sunLightColor = texelFetch(skyConstants, ivec2(1, 0), 0).rgb;
    
    vec3 rayOrigin = texture(colortex8, texcoord * REFLECTION_MULT).xyz + cameraPosition;
    vec3 rayDir = texture(colortex9, texcoord * REFLECTION_MULT).xyz;
    
    color = texture(colortex0, texcoord * REFLECTION_MULT);
    if (color.a == 0.5)
        color.rgb *= wsr(rayOrigin, rayDir, sunDir, moonDir, lightDir, timeMod, sunLightColor, skyLightColor);
}
