vec3 distortShadowClip(in vec3 shadowClipPos) {
    float distortFactor = dot(shadowClipPos.xy, shadowClipPos.xy) + 0.05;

    shadowClipPos.xy /= distortFactor;
    shadowClipPos.z  *= 0.5;

    return shadowClipPos;
}