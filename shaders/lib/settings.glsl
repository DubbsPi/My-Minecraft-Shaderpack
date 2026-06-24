#define SHADOW_RADIUS 1
#define SHADOW_RANGE 4

#define FOG_DENSITY 5.0


const int noiseTextureResolution = 128;

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

const int shadowMapResolution = 2048;
const float shadowDistanceRenderMul = 1.0;


const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.1);

const float shadowBias = -0.001;