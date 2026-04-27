#ifndef LOOGA_MODEL_MINNAERT_INCLUDED
#define LOOGA_MODEL_MINNAERT_INCLUDED

#include "Packages/com.loogasoft.loogalighting/Includes/LoogaLightingHelpers.hlsl"

float3 EvaluateLighting_Minnaert(float3 diffuseColor, float3 f0, float perceptualRoughness, float3 normalWS, float occlusion, float3 viewDirectionWS, float NoV, float3 lightDir, float3 lightColor)
{
    float roughness = perceptualRoughness * perceptualRoughness;
    float NoL = saturate(dot(normalWS, lightDir));
    float3 H = SafeNormalize(lightDir + viewDirectionWS);
    float NoH = saturate(dot(normalWS, H));
    float VoH = saturate(dot(viewDirectionWS, H));
    
    float k = lerp(1.0, 0.5, perceptualRoughness); 
    float minnaertTerm = pow(max(NoL, 1e-4), k) * pow(max(NoV, 1e-4), k - 1.0);
    float3 diffuse = (diffuseColor / PI) * minnaertTerm;
    
    float3 ndf = NDF(roughness, NoH);
    float3 fresnel = Fresnel(f0, VoH, roughness);
    float gsf = GSF(NoL, NoV, roughness);
    float3 specular = (fresnel * ndf * gsf) / max((4.0 * NoL * NoV), 1e-7);

    #if defined(_USE_GTBN)
    return (diffuse + specular) * lightColor * NoL * PI * lerp(1.0, occlusion, _GTBNDirectLightStrength);
    #else
    return (diffuse + specular) * lightColor * NoL * PI;
    #endif
}

float3 EvaluateIndirect_Minnaert(float3 f0, float perceptualRoughness, float occlusion, float3 viewDirWS, float3 normalWS, float3 bentNormalWS, float NoV, float3 posWS, float2 uv)
{
    half3 reflectVector = reflect(-viewDirWS, bentNormalWS);
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, posWS, perceptualRoughness, occlusion, uv);
    indirectSpecular = ApplyLoogaSpecularEnvironmentFloor(indirectSpecular, normalWS, perceptualRoughness);
    half surfaceReduction = 1.0 / (perceptualRoughness * perceptualRoughness + 1.0);
    half reflectivity = max(max(f0.r, f0.g), f0.b);
    half grazingTerm = saturate(1.0 - perceptualRoughness + reflectivity);
    half3 envFresnel = f0 + (grazingTerm - f0) * SchlickFresnel(NoV);
    return surfaceReduction * indirectSpecular * envFresnel;
}
#endif
