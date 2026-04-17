Shader "Hidden/LoogaSoft/Lighting/TF2"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            Name "Looga Deferred Lighting - TF2"
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
                
                // Get unclamped NoL for the wrap diffuse
                float NoL_Unclamped = dot(normalWS, lightDir);
                float NoL = saturate(NoL_Unclamped);
                
                float3 H = SafeNormalize(lightDir + viewDirectionWS);
                float NoH = saturate(dot(normalWS, H));
                float VoH = saturate(dot(viewDirectionWS, H));
                
                // 1. TF2 Warped Half-Lambert Diffuse
                // Scales and biases the dot product so it reaches 0 further around the back of the object
                float warpedDiffuse = pow(NoL_Unclamped * 0.5 + 0.5, 2.0);
                float3 diffuse = diffuseColor * warpedDiffuse;
                
                // 2. Standard GGX Specular
                float3 ndf = NDF(roughness, NoH);
                float3 fresnel = Fresnel(f0, VoH, roughness);
                float gsf = GSF(NoL, NoV, roughness);
                float3 specular = (fresnel * ndf * gsf) / max((4.0 * NoL * NoV), 1e-7);
                
                // 3. TF2 Rim Light
                // Creates a strong rim highlight on edges facing away from the camera, masked by light direction
                float rimPower = 4.0;
                float rimTerm = pow(saturate(1.0 - NoV), rimPower) * saturate(NoL);
                float3 rimLight = diffuseColor * rimTerm; // Tinting by albedo keeps it cohesive
                
                // Note: Diffuse and Rim do not get multiplied by NoL at the end, 
                // because their math already natively handles the light falloff and wrap.
                float3 finalDirectLight = diffuse + (specular * NoL) + rimLight;
                
                #if defined(_USE_GTBN)
                    float directOcclusion = lerp(1.0, occlusion, _GTBNDirectLightStrength);
                    return finalDirectLight * lightColor * PI * directOcclusion;
                #else
                    return finalDirectLight * lightColor * PI;
                #endif
            }

            float3 EvaluateIndirect(float3 f0, float perceptualRoughness, float occlusion, float3 viewDirectionWS, float3 normalWS, float3 bentNormalWS, float NoV, float3 positionWS, float2 uv)
            {
                // TF2 relies heavily on ambient color bleed, so we keep standard Disney-style environment reflections here
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