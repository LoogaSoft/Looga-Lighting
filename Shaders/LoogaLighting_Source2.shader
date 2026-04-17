Shader "Hidden/LoogaSoft/Lighting/Source2"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            Name "Looga Deferred Lighting - Source2"
            ZWrite Off ZTest Always ZClip False Cull Off
            
            HLSLPROGRAM
            #pragma vertex Vert

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ _USE_GTBN
            
            #include "LoogaLightingHelpers.hlsl"

            float GetS2SpecularOcclusion(float NoV, float occlusion, float perceptualRoughness, float3 reflectVector, float3 bentNormalWS)
            {
                float roughness = perceptualRoughness * perceptualRoughness;
                float visibility = saturate(pow(abs(NoV + occlusion), exp2(-16.0 * roughness - 1.0)) - 1.0 + occlusion);
                float bentNormalOcclusion = saturate(dot(reflectVector, bentNormalWS));
                return lerp(bentNormalOcclusion, visibility, perceptualRoughness);
            }

            float3 EvaluateLighting(float3 diffuseColor, float3 f0, float perceptualRoughness, float3 normalWS, float occlusion, float3 viewDirectionWS, float NoV, float3 lightDir, float3 lightColor)
            {
                float roughness = perceptualRoughness * perceptualRoughness;
                float NoL = saturate(dot(normalWS, lightDir));
                float3 H = SafeNormalize(lightDir + viewDirectionWS);
                float NoH = saturate(dot(normalWS, H));
                float VoH = saturate(dot(viewDirectionWS, H));
                
                float3 diffuse = diffuseColor / PI;
                
                float3 ndf = NDF(roughness, NoH);
                float3 fresnel = Fresnel(f0, VoH, roughness);
                float gsf = GSF(NoL, NoV, roughness);
                float3 specular = (fresnel * ndf * gsf) / max((4.0 * NoL * NoV), 1e-7);
                
                #if defined(_USE_GTBN)
                    float directOcclusion = lerp(1.0, occlusion, _GTBNDirectLightStrength);
                    return (diffuse + specular) * lightColor * NoL * PI * directOcclusion;
                #else
                    return (diffuse + specular) * lightColor * NoL * PI;
                #endif
            }

            float3 EvaluateIndirect(float3 f0, float perceptualRoughness, float occlusion, float3 viewDirectionWS, float3 normalWS, float3 bentNormalWS, float NoV, float3 positionWS, float2 uv)
            {
                half3 reflectVector = reflect(-viewDirectionWS, bentNormalWS);
                half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, perceptualRoughness, 1.0, uv); 
                
                half surfaceReduction = 1.0 / (perceptualRoughness * perceptualRoughness + 1.0);
                half reflectivity = max(max(f0.r, f0.g), f0.b);
                half grazingTerm = saturate(1.0 - perceptualRoughness + reflectivity);
                half3 envFresnel = f0 + (grazingTerm - f0) * SchlickFresnel(NoV);
                
                half3 appliedIndirectSpecular = surfaceReduction * indirectSpecular * envFresnel;
                float specOcc = GetS2SpecularOcclusion(NoV, occlusion, perceptualRoughness, reflectVector, bentNormalWS);
                
                return appliedIndirectSpecular * specOcc;
            }

            #pragma fragment LoogaDeferredLightingFrag
            #include "LoogaLightingPass.hlsl"

            ENDHLSL
        }
    }
}