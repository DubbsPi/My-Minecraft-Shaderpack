#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform sampler2D specular;


uniform float alphaTestRef = 0.1;


in vec2 lmCoord;
in vec2 texCoord;
in vec4 glColor;
in vec3 Normal;
flat in int blockType;


/* RENDERTARGETS: 0,1,2,3,4 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 dataOut;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 specularOut;
layout(location = 4) out uvec4 blockId;


void main() {
	if (blockType == 0) discard;

	color = texture(gtexture, texCoord) * glColor;
	if (color.a < alphaTestRef) discard;

    dataOut = vec4(lmCoord, 0, 1);
	encodedNormal = vec4(Normal * 0.5 + 0.5, 1);
	specularOut = texture(specular, texCoord);

	blockId = uvec4(uint(clamp(blockType, 0, 65535)), 0u, 0u, 1u);
}