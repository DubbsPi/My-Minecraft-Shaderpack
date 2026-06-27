#version 330 compatibility


uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;
flat in int blockType;


layout(location = 0) out uvec4 color;


void main() {
    if (blockType <= 0) discard;

    color = uvec4(uint(blockType), 0u, 0u, 1u);

    //color = texture(gtexture, texcoord) * glcolor;
    //if (color.a < alphaTestRef) discard;
}