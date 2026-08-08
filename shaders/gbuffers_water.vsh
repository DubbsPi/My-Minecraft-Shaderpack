#version 430 compatibility

#include "/lib/util.glsl"


uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform vec3 cameraPosition;
uniform int frameCounter;
uniform float frameTimeCounter;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;


layout(std430, binding = 2) buffer Vertices {
    Vertex data[];
} verts;
layout(std430, binding = 3) buffer TerrainBuffer {
    uint triCount;
    uint vertexCount;
};


vec2 wavedx(in vec2 position, in vec2 direction, in float frequency, in float timeshift) {
  float x = dot(direction, position) * frequency + timeshift;
  float wave = exp(sin(x) - 1.0);
  float dx = wave * cos(x);
  return vec2(wave, -dx);
}

float getWaves(in vec2 position, in int iterations, in float time) {
	float wavePhaseShift = length(position) * 0.1;
	float iter = 0.0;
	float frequency = 1.0;
	float timeMultiplier = 2.0;
	float weight = 1.0;
	float sumOfValues = 0.0;
	float sumOfWeights = 0.0;
    float waveDragMult = 0.38;

	for(int i=0; i < iterations; i++) {
		vec2 p = vec2(sin(iter), cos(iter));
		vec2 res = wavedx(position + vec2(0.0, sin(position.x * 0.3)), p, frequency, time * timeMultiplier + wavePhaseShift);
		
		position += p * res.y * weight * waveDragMult;
		
		sumOfValues += res.x * weight;
		sumOfWeights += weight;
		
		weight = mix(weight, 0.0, 0.2);
		frequency *= 1.18;
		timeMultiplier *= 1.07;
		iter += 1232.399963;
	}
	// calculate and return
	return sumOfValues / sumOfWeights;
}


void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
    
    vec3 blockViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(blockViewPos, 1)).xyz;
    vec3 worldPos = feetPlayerPos + cameraPosition;

    float waveHeight = -(WAVE_INTENSITY - getWaves(worldPos.xz * WAVE_SCALE, WAVE_ITERATIONS, frameTimeCounter) * WAVE_INTENSITY);
    feetPlayerPos.y += waveHeight;

	const float e  = 0.01;
	const float ie = 1.0 / e;

	float hx = getWaves((worldPos.xz + vec2(e, 0)) * WAVE_SCALE, WAVE_ITERATIONS, frameTimeCounter);
	float hz = getWaves((worldPos.xz + vec2(0, e)) * WAVE_SCALE, WAVE_ITERATIONS, frameTimeCounter);
	float dhdx = (hx - waveHeight) * ie;
	float dhdz = (hz - waveHeight) * ie;

	normal = normalize(vec3(-dhdx * WAVE_INTENSITY, 1, -dhdz * WAVE_INTENSITY));

    uint packedTexcoord = packUnorm2x16(texcoord);
    uint packedGlcolor  = packUnorm4x8(glcolor);

    uint vertexIndex = atomicAdd(vertexCount, 1u);
    verts.data[vertexIndex] = Vertex(feetPlayerPos, packedTexcoord, packedGlcolor, -1);
    if ((vertexIndex & 3u) == 3u) atomicAdd(triCount, 2u);

    vec3 newViewPos = (gbufferModelView * vec4(feetPlayerPos, 1)).xyz;
    gl_Position = gl_ProjectionMatrix * vec4(newViewPos, 1);
}