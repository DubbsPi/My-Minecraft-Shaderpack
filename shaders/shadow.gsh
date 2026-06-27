#version 330 compatibility

#include "/lib/util.glsl"


uniform vec3 cameraPosition;

layout(triangles) in;
layout(triangle_strip, max_vertices = 4) out;

in vec3 worldPos[];
flat in int blockId[];
flat out int blockType;


void main() {
    if (blockId[0] == 0) return;

    vec3 edge1  = worldPos[1] - worldPos[0];
    vec3 edge2  = worldPos[2] - worldPos[0];
    vec3 normal = normalize(cross(edge1, edge2));
    
    vec3 center   = (worldPos[0] + worldPos[1] + worldPos[2]) / 3.0;
    vec3 insetPos = center - normal * 0.1;

    vec3 toFace = normalize(center - cameraPosition);
    if (dot(normal, toFace) > 0.0) return;

    vec2 uv = worldPosToVoxelUv(insetPos, cameraPosition);
    if (uv.x < 0.0) return;

    float px = 1.0 / float(shadowMapResolution);
    vec2 ndc = uv * 2.0 - 1.0;
    blockType = blockId[0];

    gl_Position = vec4(ndc + vec2(-px, -px), 0.0, 1.0); EmitVertex();
    gl_Position = vec4(ndc + vec2( px, -px), 0.0, 1.0); EmitVertex();
    gl_Position = vec4(ndc + vec2(-px,  px), 0.0, 1.0); EmitVertex();
    gl_Position = vec4(ndc + vec2( px,  px), 0.0, 1.0); EmitVertex();
    EndPrimitive();
}