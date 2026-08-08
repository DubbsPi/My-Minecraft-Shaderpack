#define SHADOW_RADIUS 1
#define SHADOW_RANGE 4

// Sky stuff
#define SKY_VIEW_SAMPLES 16 // [8 16 32 64]
#define SKY_LIGHT_SAMPLES 8 // [4 8 16 32]

//#define CHEAP_SKY
//#define DEBUG

// RTX Features
#define REFLECTION_STYLE 2 // [0 1 2]
#if REFLECTION_STYLE == 1
#define SSR
#endif
#if REFLECTION_STYLE == 2
#define WSR
#endif

#define REFLECTION_SCALE 0.5 // [0.1 0.25 0.33 0.5 0.75 1.0]
#define REFLECTION_MULT 1.0 / REFLECTION_SCALE

#define MAX_REFLECTION_TRANSPARENCY_LAYERS 6 // [1 2 3 4 5 6 7 8 9 10]

#define MAX_TERRAIN_TRIANGLES 2097152
#define NUM_WORKGROUPS 4096

#define TRACE_STACK_SIZE 32
#define TRACE_TMAX 10000.0

#define ENTITY_ATLAS_SLOT_SIZE 128
#define ENTITY_ATLAS_SIZE 4096

// FXAA
#define FXAA
#define EDGE_THRESHOLD_MIN 0.0312
#define EDGE_THRESHOLD_MAX 0.125
#define ITERATIONS 12
#define SUBPIXEL_QUALITY 0.75
#define QUALITY(i) ((i) < 5? 1.0 : ((i) == 5? 1.5 : ((i) < 10? 2.0 : ((i) == 10? 4.0 : 8.0))))

// Bloom
#define BLOOM
#define BLOOM_QUALITY 2 // [0 1 2 3]
#define BLOOM_RADIUS 35 // [5 10 15 20 25 35 50 75 100 150 200]
#define BLOOM_STEP_SIZE int[](5, 3, 1, 1)[BLOOM_QUALITY]
#define BLOOM_INTENSITY 0.5 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define BLOOM_THREASHOLD 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

// Shadows
#define MAX_SOFT_SHADOW_DISTANCE 32.0

// Water
#define WAVE_INTENSITY 0.25 // [0.1 0.25 0.33 0.5 0.75 1.0]
#define WAVE_ITERATIONS 3 // [1 2 3 4 5]
#define WAVE_SCALE 1.0 // [0.1 0.33 0.5 1.0 2.0 3.33 5.0]

const float epsilon = 1e-7;

const int noiseTextureResolution = 128;

const int shadowMapResolution = 4096; // [1024 2048 4096 8192]

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

const float shadowDistance = MAX_SOFT_SHADOW_DISTANCE;
const float shadowDistanceRenderMul = 1.0;

const float shadowBias = -0.001;
//const float shadowPixelSize = 1.0 / 16.0;


const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);

const float sunIntensity  = 25.0;
const float moonIntensity = 0.25;
const float earthRadius  = 6371000;  // Physical radius
const float atmosphereRadius = earthRadius + 100000;
const vec3  betaRayleigh = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const float betaMie = 21e-6;
const float mieG = 0.76;
const float hr = 8500.0;
const float hm = 1200.0;

const int coarseSteps = 48;
const int refiningSteps = 12;