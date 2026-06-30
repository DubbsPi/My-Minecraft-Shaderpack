#define SHADOW_RADIUS 1
#define SHADOW_RANGE 4

#define SKY_VIEW_SAMPLES 16
#define SKY_LIGHT_SAMPLES 8

//#define CHEAP_SKY
//#define SSR

// Voxel stuff in util.glsl


const int noiseTextureResolution = 128;

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

const float shadowDistanceRenderMul = 1.0;

const float shadowBias = -0.001;
//const float shadowPixelSize = 1.0 / 16.0;


const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);

const float sunIntensity  = 25.0;
const float moonIntensity = sunIntensity / 100.0;
const float earthRadius  = 6371000;  // Physical radius
const float atmosphereRadius = earthRadius + 100000;
const vec3  betaRayleigh = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const float betaMie = 21e-6;
const float mieG = 0.76;
const float hr = 8500.0;
const float hm = 1200.0;

const int coarseSteps = 48;
const int refiningSteps = 12;