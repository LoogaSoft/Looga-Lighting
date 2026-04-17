Shader "Hidden/LoogaSoft/Lighting/Overwatch"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            Name "Looga Deferred Lighting - Overwatch"
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
                
                // 1. Roughness-Driven Diffuse Wrap
                // Smooth materials get a standard dot product (wrap = 0). Rough materials get a softer wrap.
                float wrap = perceptualRoughness * 0.5; 
                float NoL_Unclamped = dot(normalWS, lightDir);
                float NoL_Wrapped = saturate((NoL_Unclamped + wrap) / ((1.0 + wrap) * (1.0 + wrap)));
                float3 diffuse = (diffuseColor / PI) * NoL_Wrapped;
                
                // Standard Specular setup
                float NoL = saturate(NoL_Unclamped); // Standard NoL for the specular term
                float3 H = SafeNormalize(lightDir + viewDirectionWS);
                float NoH = saturate(dot(normalWS, H));
                float VoH = saturate(dot(viewDirectionWS, H));
                
                // 2. Smoothed GGX NDF
                // We calculate standard GGX, but smoothstep the output to prevent infinite micro-pixel spikes.
                // This keeps specular highlights "chunky" and readable like brush strokes.
                float rawNDF = NDF(roughness, NoH);
                float smoothedNDF = smoothstep(0.0, 1.0, rawNDF * roughness * 4.0) * rawNDF; 
                
                float3 fresnel = Fresnel(f0, VoH, roughness);
                float gsf = GSF(NoL, NoV, roughness);
                float3 specular = (fresnel * smoothedNDF * gsf) / max((4.0 * NoL * NoV), 1e-7);
                
                // Note: We don't multiply diffuse by NoL here because the wrapped diffuse already handles it.
                float3 finalDirectLight = diffuse + (specular * NoL);
                
                #if defined(_USE_GTBN)
                    float directOcclusion = lerp(1.0, occlusion, _GTBNDirectLightStrength);
                    return finalDirectLight * lightColor * PI * directOcclusion;
                #else
                    return finalDirectLight * lightColor * PI;
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