#version 330 compatibility

#include "/lib/util.glsl"
#include "/lib/settings.glsl"


uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D depthtex0;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform sampler2D noisetex;

uniform vec3 shadowLightPosition;

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

uniform vec3 fogColor;
uniform float far;


in vec2 texcoord;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

/*
const int colortex0Format = RGB16;
*/

vec3 getSky(in vec3 worldDir, in vec3 sunDir, in vec3 sunColor) {
    float noise = texture(noisetex, abs(worldDir.xz * 5289034.8923 + frameTimeCounter)).r;  // For debanding
    float t = clamp(worldDir.y + noise * 0.02, 0.0, 1.0);
    vec3 skyColor = mix(fogColor, fogColor * vec3(0.5, 0.5, 0.75), t);
    
    float sunAmount = pow(max(dot(worldDir, sunDir), 0.0), 64.0) * 0.1;
    sunAmount += pow(max(dot(worldDir, sunDir), 0.0), 1024.0) * 0.2;

    sunColor *= vec3(1.0, sunDir.y * 0.5 + 0.5, sunDir.y);
    skyColor += sunColor * sunAmount * clamp((1.0 - sunDir.y) * 5.0, 1.75, 5.0);
    return skyColor * clamp(sunDir.y * 2.0, 0.0, 1.0);
}

vec4 getNoise(in ivec2 pixel) {
	ivec2 coord = pixel % 128;
	return texelFetch(noisetex, coord, 0);
}

vec3 getShadow(in vec3 shadowScreenPos) {
	// Sample everything
    float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);

	if (transparentShadow == 1.0) return vec3(1);  // Fully sunlit

	// Sample only opaques
	float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);

	if (opaqueShadow == 0.0) return vec3(0);  // Fully shadowed

	// Colored
	vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);
	shadowColor.rgb *= (1.0 - shadowColor.a);
	return shadowColor.rgb;
}

vec3 getSoftShadow(in vec4 shadowClipPos) {
	vec3 shadowAccum = vec3(0);
	const float samplesMult = 1.0 / float(SHADOW_RANGE * SHADOW_RANGE * 5);
	const float mult = SHADOW_RADIUS / float(SHADOW_RANGE) / float(shadowMapResolution);

	float noise = getNoise(ivec2(texcoord * vec2(viewWidth, viewHeight))).r;
	float theta = noise * TAU;
	float cosTheta = cos(theta);
	float sinTheta = sin(theta);
	
	mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

	for (int x = -SHADOW_RANGE; x <= SHADOW_RANGE; x++) {
		for (int y = -SHADOW_RANGE; y <= SHADOW_RANGE; y++) {
			vec2 offset = vec2(x, y) * mult * rotation;
			vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, shadowBias, 0);
			offsetShadowClipPos.xyz = distortShadowClip(offsetShadowClipPos.xyz);
			vec3 shadowNdcPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w;
			vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;
			shadowAccum += getShadow(shadowScreenPos);
		}
	}

	return shadowAccum * samplesMult;
}

vec3 getWorldPos(in vec2 uv, in float depth) {
	vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1);
	vec4 view = gbufferProjectionInverse * clip;
	view.xyz /= view.w;
	return (gbufferModelViewInverse * view).xyz + cameraPosition;
}

vec3 worldToScreen(in vec3 worldPos) {
	vec4 view = gbufferModelView * vec4(worldPos - cameraPosition, 1);
	vec4 clip = gbufferProjection * view;
	clip.xyz /= clip.w;
	return clip.xyz * 0.5 + 0.5;
}

bool blockOccupied(in vec3 worldPos) {
	vec3 screen = worldToScreen(worldPos);

	if (any(lessThan(screen.xy, vec2(0))) || (any(greaterThan(screen.xy, vec2(1))))) return false;

	float sceneDepth = texture(depthtex0, screen.xy).r;
	return sceneDepth < screen.z - 0.001;
}

vec4 ddaReflection(in vec3 rayOrigin, in vec3 rayDir, in vec3 lightDir) {
	ivec3 cell    = ivec3(floor(rayOrigin));
	ivec3 stepDir = ivec3(sign(rayDir));
	vec3  tDelta  = abs(1.0 / rayDir);
	vec3  tMax    = (vec3(cell + max(stepDir, ivec3(0))) - rayOrigin) / rayDir;

	for (int i = 0; i < 64; i++) {
		float tHit;

		if (tMax.x < tMax.y && tMax.x < tMax.z) {
			tHit = tMax.x;
            cell.x += stepDir.x;
			tMax.x += tDelta.x;
        } else if (tMax.y < tMax.z) {
			tHit = tMax.y;
            cell.y += stepDir.y;
			tMax.y += tDelta.y;
        } else {
			tHit = tMax.z;
            cell.z += stepDir.z;
			tMax.z += tDelta.z;
        }

        vec3 samplePos = vec3(cell) + 0.5;
        if (blockOccupied(samplePos)) {
			vec3 hitPos = rayOrigin + rayDir * tHit;
            vec3 screen = worldToScreen(hitPos);
            return vec4(texture(colortex0, screen.xy).rgb, 1);
        } 
	}
	return vec4(0);
}


void main() {
	float depth = texture(depthtex0, texcoord).r;

	vec3 ndcPos  = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);

	// Sky test
	if (depth == 1.0) {
        vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0)).xyz;
        vec3 lightDir = mat3(gbufferModelViewInverse) * normalize(shadowLightPosition);

        color = vec4(getSky(normalize(worldPos), lightDir, sunlightColor), 1);
	} else {
		color = texture(colortex0, texcoord);
		color.rgb = pow(color.rgb, vec3(2.2));  // Convert to linear

		vec4 data = texture(colortex1, texcoord);
		vec2 lightmap = data.rg;
		vec3 encodedNormal = texture(colortex2, texcoord).rgb;
		vec3 normal = normalize(encodedNormal - 0.5);

		vec3 blockLight = lightmap.r * blocklightColor;
		vec3 skyLight = lightmap.g * skylightColor;
		vec3 ambient  = ambientColor;


		vec3 lightDir = mat3(gbufferModelViewInverse) * normalize(shadowLightPosition);

		// Shadow calculations
		vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1)).xyz;
		vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1)).xyz;
		vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1);
		
		vec3 shadow   = getSoftShadow(shadowClipPos);
		vec3 sunLight = sunlightColor * max(dot(lightDir, normal), 0.0) * shadow;


		color.rgb *= blockLight + skyLight + ambient + sunLight;

		float reflective = data.b;
		if (reflective > 0.1) {
			vec3 worldPos = getWorldPos(texcoord, depth);
			vec3 viewDir  = normalize(worldPos - cameraPosition);
			vec3 reflectDir = reflect(viewDir, normal);

			vec4 reflection = ddaReflection(worldPos + normal * 0.01, reflectDir, lightDir);
			if (reflection.w > 0.5)
				color.rgb = mix(color.rgb, reflection.rgb, reflective);
			else {
				vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0)).xyz;
        		vec3 lightDir = mat3(gbufferModelViewInverse) * normalize(shadowLightPosition);

        		color = vec4(getSky(reflectDir, lightDir, sunlightColor), 1);
			}
			
		}

		float dist = length(viewPos) / far;
		float fogFactor = exp(-FOG_DENSITY * (1.0 - dist));

		color.rgb = mix(color.rgb, fogColor, clamp(fogFactor, 0.0, 1.0));
	}

	color.rgb = pow(color.rgb, vec3(0.45454545454));  // Convet back to human
}