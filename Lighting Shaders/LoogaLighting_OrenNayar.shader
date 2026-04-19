Shader "Hidden/LoogaSoft/Lighting/OrenNayar"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            Name "Looga Deferred Lighting - OrenNayar"
            ZWrite Off ZTest Always ZClip False Cull Off
            
            HLSLPROGRAM
            #pragma vertex Vert

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ _USE_GTBN
            
            #include "LoogaLightingHelpers.hlsl"

            float3 EvaluateLighting(float3 diffuseColor, float3 f0, float perceptualRoughness, float3 normalWS, float occlusion, float3 viewDirectionWS, float NoV, float3 lightDir, float3 lightColor)
            {
                float roughness = perceptualRoughness * perceptualRoughness;
                float roughness2 = roughness * roughness;
                
                float NoL = saturate(dot(normalWS, lightDir));
                float3 H = SafeNormalize(lightDir + viewDirectionWS);
                float NoH = saturate(dot(normalWS, H));
                float VoH = saturate(dot(viewDirectionWS, H));
                
                // 1. Oren-Nayar Diffuse Approximation
                // This is a heavily optimized approximation of the Oren-Nayar model that avoids expensive trigonometric functions.
                float A = 1.0 - 0.5 * (roughness2 / (roughness2 + 0.33));
                float B = 0.45 * (roughness2 / (roughness2 + 0.09));
                
                // Calculate the cosine of the angle between the light and view vectors, projected onto the tangent plane
                float LdotV = dot(lightDir, viewDirectionWS);
                float s = LdotV - NoL * NoV;
                float t = lerp(1.0, max(NoL, NoV), step(0.0, s));
                
                float orenNayarTerm = A + B * (s / max(t, 1e-7));
                float3 diffuse = (diffuseColor / PI) * orenNayarTerm;
                
                // 2. Standard GGX Specular
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

            // Uses standard environment reflections
            float3 EvaluateIndirect(float3 f0, float perceptualRoughness, float occlusion, float3 viewDirectionWS, float3 normalWS, float3 bentNormalWS, float NoV, float3 positionWS, float2 uv)
            {
                half3 reflectVector = reflect(-viewDirectionWS, bentNormalWS);
                half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, perceptualRoughness, occlusion, uv);
                
                half surfaceReduction = 1.0 / (perceptualRoughness * perceptualRoughness + 1.0);
                half reflectivity = max(max(f0.r, f0.g), f0.b);
                half grazingTerm = saturate(1.0 - perceptualRoughness + reflectivity);
                half3 envFresnel = f0 + (grazingTerm - f0) * SchlickFresnel(NoV);
                
                return surfaceReduction * indirectSpecular * envFresnel;
            }

            #pragma fragment LoogaDeferredLightingFrag
            #include "LoogaLightingPass.hlsl"

            ENDHLSL
        }
    }
}