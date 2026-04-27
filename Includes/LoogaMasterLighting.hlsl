#ifndef LOOGA_MASTER_LIGHTING_INCLUDED
#define LOOGA_MASTER_LIGHTING_INCLUDED

// 1. Declare the global uniform pushed by LoogaLightingFeature.cs
int _LoogaLightingModel;

// 2. Include all of your modular lighting models from the correct package path
#include "Packages/com.loogasoft.loogalighting/Includes/Lighting Models/DisneyBurley.hlsl"
#include "Packages/com.loogasoft.loogalighting/Includes/Lighting Models/Source2.hlsl"
#include "Packages/com.loogasoft.loogalighting/Includes/Lighting Models/TF2.hlsl"
#include "Packages/com.loogasoft.loogalighting/Includes/Lighting Models/Minnaert.hlsl"
#include "Packages/com.loogasoft.loogalighting/Includes/Lighting Models/OrenNayar.hlsl"
#include "Packages/com.loogasoft.loogalighting/Includes/Lighting Models/Overwatch.hlsl"
#include "Packages/com.loogasoft.loogalighting/Includes/Lighting Models/Arkane.hlsl"

// ==============================================================================
// MASTER DIRECT LIGHTING EVALUATION
// ==============================================================================
float3 EvaluateGlobalLoogaLighting(float3 diffuseColor, float3 f0, float perceptualRoughness, float3 normalWS, float occlusion, float3 viewDirectionWS, float NoV, float3 lightDir, float3 lightColor)
{
    perceptualRoughness = GetLoogaSafePerceptualRoughness(perceptualRoughness);

    if (_LoogaLightingModel == 1) return EvaluateLighting_Source2(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, lightDir, lightColor);
    if (_LoogaLightingModel == 2) return EvaluateLighting_TF2(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, lightDir, lightColor);
    if (_LoogaLightingModel == 3) return EvaluateLighting_Minnaert(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, lightDir, lightColor);
    if (_LoogaLightingModel == 4) return EvaluateLighting_Overwatch(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, lightDir, lightColor);
    if (_LoogaLightingModel == 5) return EvaluateLighting_OrenNayar(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, lightDir, lightColor);
    if (_LoogaLightingModel == 6) return EvaluateLighting_Arkane(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, lightDir, lightColor);
    
    // Fallback (DisneyBurley)
    return EvaluateLighting_DisneyBurley(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, lightDir, lightColor);
}

// ==============================================================================
// MASTER INDIRECT LIGHTING EVALUATION
// ==============================================================================
float3 EvaluateGlobalLoogaIndirect(float3 f0, float perceptualRoughness, float occlusion, float3 viewDirWS, float3 normalWS, float3 bentNormalWS, float NoV, float3 posWS, float2 uv)
{
    perceptualRoughness = GetLoogaSafePerceptualRoughness(perceptualRoughness);

    if (_LoogaLightingModel == 1) return EvaluateIndirect_Source2(f0, perceptualRoughness, occlusion, viewDirWS, normalWS, bentNormalWS, NoV, posWS, uv);
    if (_LoogaLightingModel == 2) return EvaluateIndirect_TF2(f0, perceptualRoughness, occlusion, viewDirWS, normalWS, bentNormalWS, NoV, posWS, uv);
    if (_LoogaLightingModel == 3) return EvaluateIndirect_Minnaert(f0, perceptualRoughness, occlusion, viewDirWS, normalWS, bentNormalWS, NoV, posWS, uv);
    if (_LoogaLightingModel == 4) return EvaluateIndirect_Overwatch(f0, perceptualRoughness, occlusion, viewDirWS, normalWS, bentNormalWS, NoV, posWS, uv);
    if (_LoogaLightingModel == 5) return EvaluateIndirect_OrenNayar(f0, perceptualRoughness, occlusion, viewDirWS, normalWS, bentNormalWS, NoV, posWS, uv);
    if (_LoogaLightingModel == 6) return EvaluateIndirect_Arkane(f0, perceptualRoughness, occlusion, viewDirWS, normalWS, bentNormalWS, NoV, posWS, uv);
    
    // Fallback (DisneyBurley)
    return EvaluateIndirect_DisneyBurley(f0, perceptualRoughness, occlusion, viewDirWS, normalWS, bentNormalWS, NoV, posWS, uv);
}

#endif
