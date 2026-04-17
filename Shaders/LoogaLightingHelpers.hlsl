#ifndef LOOGA_LIGHTING_HELPERS_INCLUDED
#define LOOGA_LIGHTING_HELPERS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

TEXTURE2D_X_HALF(_GBuffer0); 
TEXTURE2D_X_HALF(_GBuffer1); 
TEXTURE2D_X_HALF(_GBuffer2); 
TEXTURE2D_X_HALF(_GBuffer3); 
TEXTURE2D_X(_GTBNTexture);   

float _GTBNDirectLightStrength;

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

#endif