#ifndef LOOGA_LIGHTING_PASS_INCLUDED
#define LOOGA_LIGHTING_PASS_INCLUDED

// NEW: Include your master switchboard!
#include "Packages/com.loogasoft.loogalighting/Includes/LoogaMasterLighting.hlsl"

TEXTURE2D_X_HALF(_SSSSProfileTexture);

half4 LoogaDeferredLightingFrag(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv = input.texcoord;

    #if UNITY_REVERSED_Z
        float depth = SampleSceneDepth(uv);
    #else
        float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
    #endif

    float3 positionWS = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
    half4 gbuffer0 = SAMPLE_TEXTURE2D_X_LOD(_GBuffer0, sampler_LinearClamp, uv, 0);
    half4 gbuffer1 = SAMPLE_TEXTURE2D_X_LOD(_GBuffer1, sampler_LinearClamp, uv, 0);
    half4 gbuffer2 = SAMPLE_TEXTURE2D_X_LOD(_GBuffer2, sampler_LinearClamp, uv, 0);
    half4 gbuffer3 = SAMPLE_TEXTURE2D_X_LOD(_GBuffer3, sampler_LinearClamp, uv, 0);

    half3 albedo = gbuffer0.rgb;
    uint materialFlags = uint(gbuffer0.a * 255.0);
    bool isSpecularWorkflow = (materialFlags & 8) != 0;

    bool isDualLobe = (materialFlags & 16) != 0;
    half secondaryRoughness = gbuffer1.g;
    half lobeMix = gbuffer1.b;

    half3 diffuseColor;
    half3 f0;
    half metallic = 0.0;

    if (isSpecularWorkflow)
    {
        f0 = gbuffer1.rgb;
        diffuseColor = albedo;
    }
    else
    {
        metallic = gbuffer1.r;
        f0 = lerp(kDielectricSpec.rgb, albedo, metallic);
        diffuseColor = albedo * (1.0 - metallic);
    }

    half materialOcclusion = gbuffer1.a;
    half gtbnOcclusion = 1.0;
    half3 bakedGIAndEmission = gbuffer3.rgb;
    half transmissionMask = gbuffer3.a;

    // Sample the SSSS Profile
    half4 ssssProfile = SAMPLE_TEXTURE2D_X_LOD(_SSSSProfileTexture, sampler_LinearClamp, uv, 0);
    bool hasSSSS = ssssProfile.a > 0.001;
    half3 ssssColor = ssssProfile.rgb;
    float ssssWidth = ssssProfile.a * 5.0; // Unpack from 0-1

    #if defined(_GBUFFER_NORMALS_OCT)
        half2 remappedOctNormalWS = Unpack888ToFloat2(gbuffer2.xyz);
        half2 octNormalWS = remappedOctNormalWS.xy * 2.0 - 1.0;
        half3 normalWS = normalize(UnpackNormalOctQuadEncode(octNormalWS));
    #else
        half3 normalWS = normalize(gbuffer2.rgb);
    #endif

    half3 bentNormalWS = normalWS;

    #if defined(_USE_GTBN)
        half4 gtbnData = SAMPLE_TEXTURE2D_X_LOD(_GTBNTexture, sampler_PointClamp, uv, 0);
        gtbnOcclusion = gtbnData.a;
        bentNormalWS = normalize(gtbnData.rgb * 2.0 - 1.0);

        if (_LoogaGTBNDebugMode == 1)
            return half4(half3(gtbnData.a, gtbnData.a, gtbnData.a), 1.0);

        if (_LoogaGTBNDebugMode == 2)
            return half4(half3(1.0 - gtbnData.a, 1.0 - gtbnData.a, 1.0 - gtbnData.a), 1.0);

        if (_LoogaGTBNDebugMode == 3)
            return half4(gtbnData.rgb, 1.0);

        if (_LoogaGTBNDebugMode == 4)
            return half4(saturate(abs(bentNormalWS - normalWS) * 4.0), 1.0);

        if (_LoogaGTBNDebugMode == 5)
            return half4(half3(materialOcclusion, materialOcclusion, materialOcclusion), 1.0);

        if (_LoogaGTBNDebugMode == 6)
        {
            half combinedOcclusionDebug = saturate(materialOcclusion * gtbnOcclusion);
            return half4(half3(combinedOcclusionDebug, combinedOcclusionDebug, combinedOcclusionDebug), 1.0);
        }
    #endif

    half combinedOcclusion = saturate(materialOcclusion * gtbnOcclusion);

    half smoothness = gbuffer2.a;
    half perceptualRoughness = 1.0 - smoothness;

    half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - positionWS);
    float NoV = saturate(dot(normalWS, viewDirectionWS));

    float3 finalColor = 0;
    float4 shadowCoord = TransformWorldToShadowCoord(positionWS);

    // Evaluate Main Light
    Light mainLight = GetMainLight(shadowCoord, positionWS, 1.0);
    float3 mainRadiance = mainLight.color * mainLight.shadowAttenuation * mainLight.distanceAttenuation;

    // NEW: Call the master global switch function
    finalColor += EvaluateGlobalLoogaLighting(diffuseColor, f0, perceptualRoughness, normalWS, combinedOcclusion, viewDirectionWS, NoV, mainLight.direction, mainRadiance);

    // Add Transmission for the Sun
    if (hasSSSS)
    {
        finalColor += EvaluateTransmission(ssssColor, ssssWidth, mainLight.direction, viewDirectionWS, normalWS, mainLight.color * mainLight.distanceAttenuation, mainLight.shadowAttenuation, transmissionMask);
    }
    if (isDualLobe)
    {
        finalColor += EvaluateSecondaryGGXLobe(f0, secondaryRoughness, normalWS, mainLight.direction, viewDirectionWS, NoV, mainRadiance, lobeMix);
    }

    // Evaluate Additional Lights
    #if USE_CLUSTER_LIGHT_LOOP
        ClusterIterator clusterIterator = ClusterInit(uv, positionWS, 0);
        uint lightIndex = 0;
        [loop]
        while (ClusterNext(clusterIterator, lightIndex))
        {
            lightIndex += URP_FP_DIRECTIONAL_LIGHTS_COUNT;
            Light light = GetAdditionalLight(lightIndex, positionWS, half4(1,1,1,1));
            float3 dynRadiance = light.color * light.shadowAttenuation * light.distanceAttenuation;

            // NEW: Call the master global switch function
            finalColor += EvaluateGlobalLoogaLighting(diffuseColor, f0, perceptualRoughness, normalWS, combinedOcclusion, viewDirectionWS, NoV, light.direction, dynRadiance);
        }
    #else
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0; lightIndex < pixelLightCount; lightIndex++)
        {
            Light light = GetAdditionalLight(lightIndex, positionWS, half4(1,1,1,1));
            float3 dynRadiance = light.color * light.shadowAttenuation * light.distanceAttenuation;

            // NEW: Call the master global switch function
            finalColor += EvaluateGlobalLoogaLighting(diffuseColor, f0, perceptualRoughness, normalWS, combinedOcclusion, viewDirectionWS, NoV, light.direction, dynRadiance);

            if (isDualLobe)
            {
                finalColor += EvaluateSecondaryGGXLobe(f0, secondaryRoughness, normalWS, light.direction, viewDirectionWS, NoV, dynRadiance, lobeMix);
            }
        }
    #endif

    // NEW: Call the master indirect switch function
    half indirectOcclusion = GetLoogaMetalIndirectOcclusion(combinedOcclusion, metallic);
    finalColor += EvaluateGlobalLoogaIndirect(f0, perceptualRoughness, indirectOcclusion, viewDirectionWS, normalWS, bentNormalWS, NoV, positionWS, uv);
    finalColor += EvaluateLoogaDeferredMetalEnvironmentReflection(f0, metallic, perceptualRoughness, normalWS, bentNormalWS, viewDirectionWS, NoV, combinedOcclusion, positionWS, uv);
    finalColor += EvaluateLoogaMetalAmbientReflection(f0, metallic, perceptualRoughness, normalWS, bentNormalWS, viewDirectionWS, NoV, combinedOcclusion);
    finalColor += bakedGIAndEmission;

    return half4(finalColor, 1.0);
}
#endif
