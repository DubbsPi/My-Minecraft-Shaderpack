#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;
flat in int blockType;


/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 dataOut;
layout(location = 2) out vec4 encodedNormal;


void main() {
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) {
		discard;
	}

	float reflectivity = 0.0;
    if (blockType == 0) reflectivity = 1.0;

    dataOut = vec4(lmcoord, reflectivity, 1);
	encodedNormal = vec4(normal * 0.5 + 0.5, 1);
}