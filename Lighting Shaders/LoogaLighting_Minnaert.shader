Shader "Hidden/LoogaSoft/Lighting/Minnaert"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            Name "Looga Deferred Lighting - Minnaert"
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
                float NoL = saturate(dot(normalWS, lightDir));
                float3 H = SafeNormalize(lightDir + viewDirectionWS);
                float NoH = saturate(dot(normalWS, H));
                float VoH = saturate(dot(viewDirectionWS, H));
                
                // 1. Minnaert Diffuse 
                // We use perceptualRoughness to drive the 'k' parameter.
                // A lower 'k' pushes light to the edges (dust/velvet). A higher 'k' pushes it to the center.
                float k = lerp(1.0, 0.5, perceptualRoughness); 
                
                // max(x, 1e-4) prevents math explosions when NoV hits 0 and k is less than 1
                float minnaertTerm = pow(max(NoL, 1e-4), k) * pow(max(NoV, 1e-4), k - 1.0);
                float3 diffuse = (diffuseColor / PI) * minnaertTerm;
                
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

            // Minnaert primarily affects direct light scattering, so we use standard environment reflections
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