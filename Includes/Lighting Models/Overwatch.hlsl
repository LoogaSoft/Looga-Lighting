#ifndef LOOGA_MODEL_OVERWATCH_INCLUDED
#define LOOGA_MODEL_OVERWATCH_INCLUDED

#include "Packages/com.loogasoft.loogalighting/Includes/LoogaLightingHelpers.hlsl"

float3 EvaluateLighting_Overwatch(float3 diffuseColor, float3 f0, float perceptualRoughness, float3 normalWS, float occlusion, float3 viewDirectionWS, float NoV, float3 lightDir, float3 lightColor)
{
    float roughness = perceptualRoughness * perceptualRoughness;
    float wrap = perceptualRoughness * 0.5; 
    float NoL_Unclamped = dot(normalWS, lightDir);
    float NoL_Wrapped = saturate((NoL_Unclamped + wrap) / ((1.0 + wrap) * (1.0 + wrap)));
    float3 diffuse = (diffuseColor / PI) * NoL_Wrapped;
    
    float NoL = saturate(NoL_Unclamped);
    float3 H = SafeNormalize(lightDir + viewDirectionWS);
    float NoH = saturate(dot(normalWS, H));
    float VoH = saturate(dot(viewDirectionWS, H));

    float rawNDF = NDF(roughness, NoH);
    float smoothedNDF = smoothstep(0.0, 1.0, rawNDF * roughness * 4.0) * rawNDF; 
    
    float3 fresnel = Fresnel(f0, VoH, roughness);
    float gsf = GSF(NoL, NoV, roughness);
    float3 specular = (fresnel * smoothedNDF * gsf) / max((4.0 * NoL * NoV), 1e-7);

    float3 finalDirectLight = diffuse + (specular * NoL);
    
    #if defined(_USE_GTBN)
        return finalDirectLight * lightColor * PI * lerp(1.0, occlusion, _GTBNDirectLightStrength);
    #else
        return finalDirectLight * lightColor * PI;
    #endif
}

float3 EvaluateIndirect_Overwatch(float3 f0, float perceptualRoughness, float occlusion, float3 viewDirWS, float3 normalWS, float3 bentNormalWS, float NoV, float3 posWS, float2 uv)
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
