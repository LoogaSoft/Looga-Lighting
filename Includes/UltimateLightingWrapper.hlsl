#ifndef ULTIMATE_LIGHTING_WRAPPER_INCLUDED
#define ULTIMATE_LIGHTING_WRAPPER_INCLUDED

#ifndef SHADERGRAPH_PREVIEW
//main lighting and shadows
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
#pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
#pragma multi_compile _ _CLUSTER_LIGHT_LOOP

//advanced lighting features
#pragma multi_compile _ _LIGHT_LAYERS
#pragma multi_compile _ _LIGHT_COOKIES

//SSAO and reflections
#pragma multi_compile _ _REFLECTION_PROBE_BOX_PROJECTION
#pragma multi_compile _ _REFLECTION_PROBE_BLENDING

//baked GI
#pragma multi_compile _ DYNAMICLIGHTMAP_ON

//URP includes
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

//data structs
struct SubsurfaceData
{
    float3 color;
    float thickness;
    float falloff;
    float ambient;
    float distortion;
};
struct LightInputs
{
    float NoL;
    float NoH;
    float VoH;
    float VoL;
    float LoH;
};

struct BRDF
{
    float3 diffuse;
    float3 specular;
    float3 subsurface;
};

struct OcclusionData
{
    float indirect;
    float direct;
};

//helper functions
float dot01(float3 a, float3 b)
{
    return saturate(dot(a, b));
}

LightInputs GetLightInputs(float3 normalWS, float3 viewDirectionWS, float3 lightDirection)
{
    LightInputs inputs;
    float3 H = SafeNormalize(lightDirection + viewDirectionWS);
    inputs.NoL = dot01(normalWS, lightDirection);
    inputs.NoH = dot01(normalWS, H);
    inputs.VoH = dot01(viewDirectionWS, H);
    inputs.VoL = dot01(viewDirectionWS, lightDirection);
    inputs.LoH = dot01(lightDirection, H);
    return inputs;
}

OcclusionData GetAmbientOcclusionData(float2 ScreenPosition)
{
    OcclusionData occlusionData = (OcclusionData)0;
    occlusionData.indirect = 1;
    occlusionData.direct = 1;
#if defined(_SCREEN_SPACE_OCCLUSION)
    AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(ScreenPosition);
    occlusionData.indirect = aoFactor.indirectAmbientOcclusion;
    occlusionData.direct = aoFactor.directAmbientOcclusion;
#endif
    return occlusionData;
}

//lighting math
float SchlickFresnel(float input)
{
    float v = saturate(1.0 - input);
    return v * v * v * v * v;
}
float FD90(float roughness, float LoH)
{
    return 0.5 + (2.0 * roughness * LoH * LoH);
}

//original diffuse model from ULS
float3 GetDiffuse(float3 baseColor, float perceptualRoughness, float LoH, float NoL, float NoV)
{
    return (baseColor / PI) * (1.0 + (FD90(perceptualRoughness, LoH) - 1.0) * SchlickFresnel(NoL)) * (1.0 + (FD90(perceptualRoughness, LoH) - 1.0) * SchlickFresnel(NoV));
}
void ApplyDirectOcclusion(OcclusionData occlusionData, inout BRDF brdf)
{
    brdf.diffuse *= occlusionData.direct;
    brdf.specular *= occlusionData.direct;
}

//true PBR lighting model
void EvaluateLighting(float3 albedo, float perceptualRoughness, float alpha, float metalness, float3 f0, float NoV,
    float3 normalWS, float3 viewDirectionWS, Light light, float receiveShadows, SubsurfaceData ssData, float lambertDiffuseWrap, inout BRDF brdf)
{
    LightInputs inputs = GetLightInputs(normalWS, viewDirectionWS, light.direction);
    
    //diffuse calculation
    float3 diffuse = GetDiffuse(albedo, perceptualRoughness, inputs.LoH, inputs.NoL, NoV);
    //ensure metals don't reflect diffuse light
    diffuse *= (1.0 - metalness);

    //GGX specular
    float alpha2 = alpha * alpha;
    
    //normal distribution
    float d = inputs.NoH * inputs.NoH * (alpha2 - 1.0) + 1.0;
    float D = alpha2 / (PI * d * d);

    //smith-GGX correlated visibility
    float visDenominator = inputs.NoL * sqrt(NoV * NoV * (1.0 - alpha2) + alpha2) + 
                           NoV * sqrt(inputs.NoL * inputs.NoL * (1.0 - alpha2) + alpha2);
    float V = 0.5 / max(visDenominator, 1e-5);

    //schlick fresnel using exp2 (standard ggx)
    float3 F = f0 + (1.0 - f0) * exp2((-5.55473 * inputs.VoH - 6.98316) * inputs.VoH); 
    float3 specular = max(0.0, D * V * F);

    //multiple scatter compensation (based on Fdez-Aguera method)
    //calculate directional albedo to see how much light is bouncing in micro-grooves
    float E = exp2((-7.353 * NoV - 1.284) * NoV) * (1.0 - perceptualRoughness) + perceptualRoughness;
    float3 F_avg = f0 + (1.0 - f0) / 21.0;

    //generate trapped light energy
    float3 multiScatter = (F_avg * F_avg * E) / (1.0 - F_avg * (1.0 - E));

    //add scattered light back to specular
    specular += specular * multiScatter * (1.0 - E);
    
    float shadowAttenuation = lerp(1.0, light.shadowAttenuation, receiveShadows);
    float3 radiance = light.color * (light.distanceAttenuation * shadowAttenuation) * inputs.NoL;

    #if defined(_USE_HALF_LAMBERT)
        float unclampedNoL = dot(normalWS, light.direction);
        float wrap = lambertDiffuseWrap;
        float wrappedNoL = saturate((unclampedNoL + wrap) / ((1.0 + wrap) * (1.0 + wrap)));

        float terminatorMask = smoothstep(-0.1, 0.2, unclampedNoL);
        float stylizedShadow = lerp(1.0, shadowAttenuation, terminatorMask);

        float3 diffuseRadiance = light.color * (light.distanceAttenuation * stylizedShadow) * wrappedNoL;

        brdf.diffuse += diffuse * diffuseRadiance * PI;
    #else
        //pi is multiplied back into diffuse because GetDiffuse divides by pi
        brdf.diffuse += diffuse * radiance * PI; 
    #endif
    
    brdf.specular += specular * radiance;

    //subsurface
    #if defined(_USE_SUBSURFACE)
        float3 halfDirectionWS = normalize(-light.direction + normalWS * ssData.distortion);
        float3 lightColor = light.color * light.distanceAttenuation;
        float subsurfaceAmount = pow(dot01(viewDirectionWS, halfDirectionWS), ssData.falloff) + ssData.ambient;
        float3 subsurface = subsurfaceAmount * (1.0 - ssData.thickness) * ssData.color;
        brdf.subsurface += subsurface * lightColor * albedo;
    #endif
}

void GetAdditionalLightData(float3 albedo, float perceptualRoughness, float alpha, float metalness, float3 f0, float NoV,
    float2 normalizedScreenSpaceUV, float3 positionWS, float3 normalWS, float3 viewDirectionWS, float receiveShadows, SubsurfaceData ssData, float lambertDiffuseWrap, inout BRDF brdf)
{
    #if defined(_ADDITIONAL_LIGHTS)
    uint count = GetAdditionalLightsCount();
    uint meshRenderingLayers = GetMeshRenderingLayer();
    
    #if USE_CLUSTER_LIGHT_LOOP
    ClusterIterator clusterIterator = ClusterInit(normalizedScreenSpaceUV, positionWS, 0);
    uint lightIndex = 0;
    [loop] while (ClusterNext(clusterIterator, lightIndex)) 
    {
        lightIndex += URP_FP_DIRECTIONAL_LIGHTS_COUNT;
        CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK
        Light light = GetAdditionalLight(lightIndex, positionWS, half4(1,1,1,1));
    
        #if defined(_LIGHT_LAYERS)
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
        {
            EvaluateLighting(albedo, perceptualRoughness, alpha, metalness, f0, NoV, normalWS, viewDirectionWS, light, receiveShadows, ssData, lambertDiffuseWrap, brdf);
        }
    }
    #else
    for(uint lightIndex = 0; lightIndex < count; lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, positionWS, half4(1,1,1,1));

        #if defined(_LIGHT_LAYERS)
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
        {
            EvaluateLighting(albedo, perceptualRoughness, alpha, metalness, f0, NoV, normalWS, viewDirectionWS, light, receiveShadows, ssData, lambertDiffuseWrap, brdf);
        }
    }
    #endif
    #endif
}

float3 GetReflection(float3 viewDirectionWS, float3 normalWS, float3 positionWS, float roughness, float2 normalizedScreenSpaceUV)
{
    float3 reflection = reflect(-viewDirectionWS, normalWS);
    return GlossyEnvironmentReflection(half3(reflection), positionWS, half(roughness), half(1.0), normalizedScreenSpaceUV);
}

#endif

//shader graph custom function
void UltimateLitCustom_float(
    float3 Albedo,
    float Alpha,
    float3 NormalWS,
    float3 Emission,
    float3 PositionWS,
    float3 ViewDirectionWS,
    float Metalness,
    float AmbientOcclusion,
    float Roughness,
    float2 ScreenSpaceUV,
    float ReceiveShadows,
    //subsurface inputs
    float3 SubsurfaceColor,
    float SubsurfaceThickness,
    float SubsurfaceFalloff,
    float SubsurfaceAmbient,
    float SubsurfaceDistortion,
    float LambertDiffuseWrap,
    //outputs
    out float3 FinalColor,
    out float FinalAlpha
)
{
#ifdef SHADERGRAPH_PREVIEW
    FinalColor = Albedo + Emission;
    FinalAlpha = Alpha;
#else

    SubsurfaceData ssData;
    ssData.color = SubsurfaceColor;
    ssData.thickness = SubsurfaceThickness;
    ssData.falloff = SubsurfaceFalloff;
    ssData.ambient = SubsurfaceAmbient;
    ssData.distortion = SubsurfaceDistortion;

    BRDF brdf;
    brdf.diffuse = 0;
    brdf.specular = 0;
    brdf.subsurface = float3(0,0,0);

    float perceptualRoughness = max(Roughness, 0.045);

    #if defined(_USE_SPECULAR_AA)
    float3 dndx = ddx(NormalWS);
    float3 dndy = ddy(NormalWS);

    //use standard "magic" numbers for variance and threshold (0.15 and 0.2)
    float variance = 0.15 * (dot(dndx, dndx) + dot(dndy, dndy));
    float kernelRoughness = min(variance, 0.2);

    float sqRoughness = perceptualRoughness * perceptualRoughness;
    perceptualRoughness = saturate(sqrt(sqRoughness + kernelRoughness));
    #endif
    
    float alpha = perceptualRoughness * perceptualRoughness;

    float NoV = dot01(NormalWS, ViewDirectionWS);
    
    //hardcoded 4% base reflectivity for dielectrics
    float3 f0 = lerp(float3(0.04, 0.04, 0.04), Albedo, Metalness);

    //evaluate main light
    float4 shadowCoord = TransformWorldToShadowCoord(PositionWS);
    Light mainLight = GetMainLight(shadowCoord, PositionWS, 1.0);
    EvaluateLighting(Albedo, perceptualRoughness, alpha, Metalness, f0, NoV, NormalWS, ViewDirectionWS, mainLight, ReceiveShadows, ssData, LambertDiffuseWrap, brdf);

    //evaluate additional lights
    GetAdditionalLightData(Albedo, perceptualRoughness, alpha, Metalness, f0, NoV, ScreenSpaceUV, PositionWS, NormalWS, ViewDirectionWS, ReceiveShadows, ssData, LambertDiffuseWrap, brdf);

    //SSAO
    OcclusionData occlusionData = GetAmbientOcclusionData(ScreenSpaceUV);
    ApplyDirectOcclusion(occlusionData, brdf);

    //global illumination + reflection
    float3 bakedGI = SampleSH(NormalWS);
    MixRealtimeAndBakedGI(mainLight, NormalWS, bakedGI);

    //environment BRDF
    float surfaceReduction = 1.0 / (alpha * alpha + 1.0);
    float reflectivity = max(max(f0.r, f0.g), f0.b);
    float grazingTerm = saturate((1.0 - perceptualRoughness) + reflectivity);
    float3 envFresnel = f0 + (max(float3(grazingTerm, grazingTerm, grazingTerm), f0) - f0) * pow(1.0 - NoV, 5.0);

    float3 indirectSpecular = GetReflection(ViewDirectionWS, NormalWS, PositionWS, perceptualRoughness, ScreenSpaceUV);
    //prevent metals from accumulating diffuse GI
    float3 indirectDiffuse = bakedGI * Albedo * (1.0 - Metalness);
    
    brdf.specular += indirectSpecular * envFresnel * surfaceReduction * occlusionData.indirect * AmbientOcclusion;
    brdf.diffuse += indirectDiffuse * occlusionData.indirect * AmbientOcclusion;

    // 5. Final Composition
    FinalColor = brdf.diffuse + brdf.specular + brdf.subsurface + Emission;
    FinalAlpha = Alpha;
#endif
}
#endif