#version 430 compatibility

#include "/lib/util.glsl"


uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D specular;

uniform float alphaTestRef = 0.1;
uniform int entityId;


in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;


/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 specularData;


void main() {
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) discard;

	lightmapData = vec4(0, 0, 1, 1);
	specularData = texture(specular, texcoord);
	encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
}