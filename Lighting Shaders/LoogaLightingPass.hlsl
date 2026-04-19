#ifndef LOOGA_LIGHTING_PASS_INCLUDED
#define LOOGA_LIGHTING_PASS_INCLUDED

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
    
    if (isSpecularWorkflow)
    {
        f0 = gbuffer1.rgb;
        diffuseColor = albedo;
    }
    else
    {
        half metallic = gbuffer1.r;
        f0 = lerp(kDielectricSpec.rgb, albedo, metallic);
        diffuseColor = albedo * (1.0 - metallic);
    }
    
    half occlusion = gbuffer1.a;
    half3 emission = gbuffer3.rgb;
    
    #if defined(_GBUFFER_NORMALS_OCT)
        half2 remappedOctNormalWS = Unpack888ToFloat2(gbuffer2.xyz);
        half2 octNormalWS = remappedOctNormalWS.xy * 2.0 - 1.0;
        half3 normalWS = normalize(UnpackNormalOctQuadEncode(octNormalWS));
    #else
        half3 normalWS = normalize(gbuffer2.rgb);
    #endif
    
    half3 bentNormalWS = normalWS;
    #if defined(_USE_GTBN)
        half4 gtbnData = SAMPLE_TEXTURE2D_X_LOD(_GTBNTexture, sampler_LinearClamp, uv, 0);
        bentNormalWS = normalize(gtbnData.rgb * 2.0 - 1.0);
    #endif
    
    half smoothness = gbuffer2.a;
    half perceptualRoughness = 1.0 - smoothness;
    half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - positionWS);
    float NoV = saturate(dot(normalWS, viewDirectionWS));
    
    float3 finalColor = 0;
    float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
    
    Light mainLight = GetMainLight(shadowCoord, positionWS, 1.0);
    float3 mainRadiance = mainLight.color * mainLight.shadowAttenuation * mainLight.distanceAttenuation;

    finalColor += EvaluateLighting(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, mainLight.direction, mainRadiance);
    
    if (isDualLobe)
    {
        finalColor += EvaluateSecondaryGGXLobe(f0, secondaryRoughness, normalWS, mainLight.direction, viewDirectionWS, NoV, mainRadiance, lobeMix);
    }

    #if USE_CLUSTER_LIGHT_LOOP
        ClusterIterator clusterIterator = ClusterInit(uv, positionWS, 0);
        uint lightIndex = 0;
        [loop]
        while (ClusterNext(clusterIterator, lightIndex))
        {
            lightIndex += URP_FP_DIRECTIONAL_LIGHTS_COUNT;
            Light light = GetAdditionalLight(lightIndex, positionWS, half4(1,1,1,1));
            float3 dynRadiance = light.color * light.shadowAttenuation * light.distanceAttenuation;
            finalColor += EvaluateLighting(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, light.direction, dynRadiance);
        }
    #else
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0; lightIndex < pixelLightCount; lightIndex++)
        {
            Light light = GetAdditionalLight(lightIndex, positionWS, half4(1,1,1,1));
            float3 dynRadiance = light.color * light.shadowAttenuation * light.distanceAttenuation;
            finalColor += EvaluateLighting(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirectionWS, NoV, light.direction, dynRadiance);
            
            if (isDualLobe) 
            {
                finalColor += EvaluateSecondaryGGXLobe(f0, secondaryRoughness, normalWS, light.direction, viewDirectionWS, NoV, dynRadiance, lobeMix);
            }
        }
    #endif
    
    finalColor += EvaluateIndirect(f0, perceptualRoughness, occlusion, viewDirectionWS, normalWS, bentNormalWS, NoV, positionWS, uv);
    finalColor += emission;
    
    return half4(finalColor, 1.0);
}
#endif