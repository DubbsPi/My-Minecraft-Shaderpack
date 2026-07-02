#version 430 compatibility

#include "/lib/util.glsl"


uniform vec3 cameraPosition;

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in vec2 lmcoord[];
in vec2 texcoord[];
in vec4 glcolor[];
in vec3 normal[];
in vec3 worldPos[];
flat in int blockId[];

out vec2 lmCoord;
out vec2 texCoord;
out vec4 glColor;
out vec3 Normal;
flat out int blockType;


layout(std430, binding = 0) buffer voxelBuffer {
	uint voxels[];
};
layout(std430, binding = 1) buffer faceBuffer {
	uvec3 faces[];
};


void main() {
    blockType = blockId[0];

    if (isVoxelizable(blockType)) {
        vec3 sNormal = (normal[0] + normal[1] + normal[2]) * 0.33333333;
        vec3 center  = (worldPos[0] + worldPos[1] + worldPos[2]) * 0.33333333;
        vec3 insetPos = center - sNormal * 0.5;

        ivec3 voxelPos = ivec3(floor(insetPos));
        if (all(lessThan(abs(voxelPos - ivec3(cameraPosition)), ivec3(VOXEL_RADIUS)))) {
            uint index = getVoxelIndex(voxelPos);
            uint face = getFaceIndex(sNormal);
            uint slot = index * 6u + face;

            uint packedColor = packUnorm4x8((glcolor[0] + glcolor[1] + glcolor[2]) * 0.33333333);

            vec2 uvMin = min(texcoord[0], min(texcoord[1], texcoord[2]));
            vec2 uvMax = max(texcoord[0], max(texcoord[1], texcoord[2]));

            voxels[index] = uint(blockType);
            faces[slot] = uvec3(packedColor, packHalf2x16(uvMin), packHalf2x16(uvMax));
        }
    }

    for (int i = 0; i < 3; i++) {
        gl_Position = gl_in[i].gl_Position;
        texCoord = texcoord[i];
        lmCoord = lmcoord[i];
        glColor = glcolor[i];
        Normal = normal[i];
        EmitVertex();
    }
    EndPrimitive();
}