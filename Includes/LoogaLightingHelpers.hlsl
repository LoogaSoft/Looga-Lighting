#ifndef LOOGA_LIGHTING_HELPERS_INCLUDED
#define LOOGA_LIGHTING_HELPERS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GBufferCommon.hlsl"

TEXTURE2D_X_HALF(_GBuffer0);
TEXTURE2D_X_HALF(_GBuffer1);
TEXTURE2D_X_HALF(_GBuffer2);
TEXTURE2D_X_HALF(_GBuffer3);
TEXTURE2D_X(_GTBNTexture);

float _GTBNDirectLightStrength;
int _LoogaGTBNDebugMode;

float SchlickFresnel(float input)
{
    float v = saturate(1.0 - input);
    return v * v * v * v * v;
}

float3 Fresnel(float3 f0, float cosTheta, float roughness)
{
    return f0 + (max(1.0 - roughness, f0) - f0) * SchlickFresnel(cosTheta);
}

float NDF(float roughness, float NoH)
{
    float a2 = roughness * roughness;
    float NoH2 = NoH * NoH;
    float c = (NoH2 * (a2 - 1.0)) + 1.0;
    return max(a2 / (PI * c * c), 1e-7);
}

float GSF(float NoL, float NoV, float roughness)
{
    float k = ((roughness * 1.0) * (roughness * 1.0)) / 8.0;
    float l = NoL / (NoL * (1.0 - k) + k);
    float v = NoV / (NoV * (1.0 - k) + k);
    return max(l * v, 1e-7);
}

float3 EvaluateSecondaryGGXLobe(float3 f0, float secondaryRoughness, float3 normalWS, float3 lightDir, float3 viewDir, float NoV, float3 radiance, float lobeMix)
{
    float NoL = saturate(dot(normalWS, lightDir));
    if (NoL <= 0.0) return 0.0;

    float3 H = SafeNormalize(lightDir + viewDir);
    float NoH = saturate(dot(normalWS, H));
    float VoH = saturate(dot(viewDir, H));

    float roughness2 = secondaryRoughness * secondaryRoughness;
    float3 ndf = NDF(roughness2, NoH);
    float3 fresnel = Fresnel(f0, VoH, roughness2);
    float gsf = GSF(NoL, NoV, roughness2);

    // Calculate specular and multiply by incoming light radiance and the mix weight
    float3 specular = (fresnel * ndf * gsf) / max((4.0 * NoL * NoV), 1e-7);
    return specular * radiance * NoL * PI * lobeMix;
}

float3 EvaluateLoogaAmbientProbe(float3 normalWS)
{
    #if defined(EVALUATE_SH_VERTEX) || defined(EVALUATE_SH_MIXED)
        half3 ambient = EvaluateAmbientProbeSRGB(normalWS);
    #else
        half3 ambient = SampleSHPixel(half3(0.0, 0.0, 0.0), normalWS);
    #endif

    return ambient;
}

float3 EvaluateLoogaAmbientDiffuse(float3 diffuseColor, float3 normalWS, float occlusion)
{
    half3 ambient = EvaluateLoogaAmbientProbe(normalWS);
    return diffuseColor * ambient * occlusion;
}

float GetLoogaSafePerceptualRoughness(float perceptualRoughness)
{
    return max(perceptualRoughness, 0.08);
}

float3 EvaluateLoogaEnvironmentReflectionFallback(float3 reflectVectorWS, float3 normalWS, float perceptualRoughness)
{
    perceptualRoughness = GetLoogaSafePerceptualRoughness(perceptualRoughness);
    half3 glossyEnvironment = _GlossyEnvironmentColor.rgb;
    half3 reflectedAmbient = EvaluateLoogaAmbientProbe(reflectVectorWS);
    half3 normalAmbient = EvaluateLoogaAmbientProbe(normalWS);
    half3 fallback = max(glossyEnvironment, max(reflectedAmbient, normalAmbient * 0.5));
    half fallbackStrength = lerp(0.65, 0.35, saturate(perceptualRoughness));

    return fallback * fallbackStrength;
}

float3 ApplyLoogaSpecularEnvironmentFloor(float3 indirectSpecular, float3 normalWS, float perceptualRoughness)
{
    perceptualRoughness = GetLoogaSafePerceptualRoughness(perceptualRoughness);
    half3 fallback = EvaluateLoogaEnvironmentReflectionFallback(normalWS, normalWS, perceptualRoughness);
    return max(indirectSpecular, fallback);
}

float GetLoogaMetalIndirectOcclusion(float occlusion, float metallic)
{
    return max(occlusion, 0.65 * saturate(metallic));
}

float3 EvaluateLoogaMetalAmbientReflection(float3 f0, float metallic, float perceptualRoughness, float3 normalWS, float3 bentNormalWS, float3 viewDirWS, float NoV, float occlusion)
{
    perceptualRoughness = GetLoogaSafePerceptualRoughness(perceptualRoughness);
    half metalMask = saturate(metallic);
    half3 reflectionWS = reflect(-viewDirWS, bentNormalWS);
    half3 roughReflectionWS = normalize(lerp(reflectionWS, normalWS, saturate(perceptualRoughness * 0.75)));
    half3 reflectedAmbient = EvaluateLoogaAmbientProbe(roughReflectionWS);
    half3 normalAmbient = EvaluateLoogaAmbientProbe(normalWS);
    half3 ambientReflection = max(reflectedAmbient, normalAmbient);

    half reflectivity = max(max(f0.r, f0.g), f0.b);
    half grazingTerm = saturate(1.0 - perceptualRoughness + reflectivity);
    half3 envFresnel = f0 + (grazingTerm - f0) * SchlickFresnel(NoV);
    half surfaceReduction = 1.0 / (perceptualRoughness * perceptualRoughness + 1.0);
    half indirectOcclusion = GetLoogaMetalIndirectOcclusion(occlusion, metallic);

    return ambientReflection * envFresnel * surfaceReduction * indirectOcclusion * metalMask;
}

float3 EvaluateLoogaDeferredMetalEnvironmentReflection(float3 f0, float metallic, float perceptualRoughness, float3 normalWS, float3 bentNormalWS, float3 viewDirWS, float NoV, float occlusion, float3 positionWS, float2 normalizedScreenSpaceUV)
{
    perceptualRoughness = GetLoogaSafePerceptualRoughness(perceptualRoughness);
    half metalMask = saturate(metallic);
    half indirectOcclusion = GetLoogaMetalIndirectOcclusion(occlusion, metallic);
    half3 reflectVector = reflect(-viewDirWS, bentNormalWS);

    half3 indirectSpecular;
#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
    #if USE_CLUSTER_LIGHT_LOOP && CLUSTER_HAS_REFLECTION_PROBES && _REFLECTION_PROBE_BLENDING
        indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, perceptualRoughness, indirectOcclusion, normalizedScreenSpaceUV);
    #else
        half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
        half4 encodedIrradiance = half4(SAMPLE_TEXTURECUBE_LOD(_GlossyEnvironmentCubeMap, sampler_GlossyEnvironmentCubeMap, reflectVector, mip));
        indirectSpecular = DecodeHDREnvironment(encodedIrradiance, _GlossyEnvironmentCubeMap_HDR) * indirectOcclusion;
    #endif
#else
    indirectSpecular = _GlossyEnvironmentColor.rgb * indirectOcclusion;
#endif

    half3 fallbackSpecular = EvaluateLoogaEnvironmentReflectionFallback(reflectVector, normalWS, perceptualRoughness) * indirectOcclusion;
    indirectSpecular = max(indirectSpecular, fallbackSpecular);

    half reflectivity = max(max(f0.r, f0.g), f0.b);
    half grazingTerm = saturate(1.0 - perceptualRoughness + reflectivity);
    half3 envFresnel = f0 + (grazingTerm - f0) * SchlickFresnel(NoV);
    half surfaceReduction = 1.0 / (perceptualRoughness * perceptualRoughness + 1.0);

    return indirectSpecular * envFresnel * surfaceReduction * metalMask;
}

float3 EvaluateTransmission(float3 ssssColor, float scatterWidth, float3 lightDir, float3 viewDirWS, float3 normalWS, float3 lightRadiance, float shadowAttenuation, float transmissionMask)
{
    if (transmissionMask <= 0.0) return float3(0,0,0);

    float distortion = 0.2;
    float3 backlightDir = normalize(lightDir + normalWS * distortion);

    // 1. Forward Scattering (The bright "sun-behind" glow)
    float transmissionPhase = saturate(dot(viewDirWS, -backlightDir));
    float scatterPower = lerp(12.0, 1.0, saturate(scatterWidth / 5.0));
    float directionalGlow = pow(transmissionPhase, scatterPower);

    // 2. Internal Ambient Scattering (The omnidirectional glow)
    // We wrap the light slightly around the back normal so it glows even from the side
    float ambientGlow = saturate(dot(-normalWS, lightDir) * 0.5 + 0.5) * 0.2;

    float transmissionProfile = directionalGlow + ambientGlow;
    float transmissionIntensity = transmissionProfile * (scatterWidth * 0.5);

    float softShadow = saturate(shadowAttenuation + 0.35);

    // Apply the user's painted thickness mask and strength multiplier
    return ssssColor * lightRadiance * transmissionIntensity * softShadow * transmissionMask;
}

#endif
