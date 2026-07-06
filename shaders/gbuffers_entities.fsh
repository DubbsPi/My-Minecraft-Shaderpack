#version 430 compatibility

#include "/lib/util.glsl"


uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D specular;

uniform float alphaTestRef = 0.1;
uniform int entityId;


in vec2 texCoord;
in vec2 lmCoord;
in vec4 glColor;
in vec3 Normal;
flat in uint id;
flat in ivec2 texsize;


/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 specularData;


void main() {
	color = texture(gtexture, texCoord) * glColor;
	if (color.a < alphaTestRef) discard;

	color *= texture(lightmap, lmCoord);
	specularData = texture(specular, texCoord);
	lightmapData = vec4(lmCoord, 0.0, 1.0);
	encodedNormal = vec4(Normal * 0.5 + 0.5, 1.0);
}