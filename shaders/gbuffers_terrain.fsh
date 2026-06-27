#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform sampler2D specular;


uniform float alphaTestRef = 0.1;


in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;
flat in int blockType;


/* RENDERTARGETS: 0,1,2,3,4 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 dataOut;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 specularOut;
layout(location = 4) out uvec4 blockId;


void main() {
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) {
		discard;
	}

    dataOut = vec4(lmcoord, 0, 1);
	encodedNormal = vec4(normal * 0.5 + 0.5, 1);
	specularOut = texture(specular, texcoord);

	uint blockI = uint(clamp(blockType, 0, 65535));
	blockId = uvec4(blockI, 0u, 0u, 1u);
}