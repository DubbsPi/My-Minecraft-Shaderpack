#version 330 compatibility

#include "/lib/distort.glsl"


uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D depthtex0;

uniform sampler2D shadowtex0;

uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

in vec2 texcoord;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

/*
const int colortex0Format = RGB16;
*/

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.1);


vec3 projectDiv(in mat4 projectionMatrix, in vec3 position) {
	vec4 homePos = projectionMatrix * vec4(position, 1);
	return homePos.xyz / homePos.w;
}


void main() {
	float depth = texture(depthtex0, texcoord).r;

	// Sky test
	if (depth == 1.0) {
		color = vec4(0, 0, 0, 1);
		return;
	}

	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));  // Convert to linear

	vec2 lightmap = texture(colortex1, texcoord).rg;
	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize(encodedNormal - 0.5);

	vec3 blockLight = lightmap.r * blocklightColor;
	vec3 skyLight = lightmap.g * skylightColor;
	vec3 ambient = ambientColor;


	vec3 lightVector = normalize(shadowLightPosition);
	vec3 lightDir = mat3(gbufferModelViewInverse) * lightVector;

	// Shadow calculations
	vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectDiv(gbufferProjectionInverse, ndcPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1);
	shadowClipPos.z  -= 0.001;  // Shadow bias
	shadowClipPos.xyz = distortShadowClip(shadowClipPos.xyz);  // Undo distortion
	vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;

	float shadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
	vec3 sunLight = sunlightColor * max(dot(lightDir, normal), 0.0) * shadow;


	color.rgb *= blockLight + skyLight + ambient + sunLight;

	color.rgb = pow(color.rgb, vec3(0.45454545454));  // Convet back to human
}