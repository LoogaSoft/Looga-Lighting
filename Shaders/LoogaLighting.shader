Shader "Hidden/LoogaSoft/LoogaLighting"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque""RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            Name "Looga Deferred Lighting"
            ZWrite Off
            ZTest Always
            ZClip False
            Cull Off
            
            /* for if we want to make lighting optional, requiring materials write 1 to stencil buffer to use the lighting
            Stencil {
                Ref 1 
                Comp Equal
            }
            */
            
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            
            #pragma shader_feature_local _ _SOURCE2_LIGHTING
            #pragma shader_feature_local _ _USE_GTBN

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

            TEXTURE2D_X_HALF(_GBuffer0); //albedo - RGB, material flags - A
            TEXTURE2D_X_HALF(_GBuffer1); //specular/metallic - RGB, occlusion - A
            TEXTURE2D_X_HALF(_GBuffer2); //world normal - RGB, smoothness - A
            TEXTURE2D_X_HALF(_GBuffer3); //emission/baked gi - RGB, lighting mode - A
            TEXTURE2D_X(_GTBNTexture); //bent normal - RGB, SS occlusion - A

            float _GTBNDirectLightStrength;
            
            //HELPER FUNCTIONS
            float SchlickFresnel(float input)
            {
                float v = saturate(1.0 - input);
                return v * v * v * v * v;
            }
            float3 Fresnel(float3 f0, float cosTheta, float roughness)
            {
                return f0 + (max(1.0 - roughness, f0) - f0) * SchlickFresnel(cosTheta);
            }
            float FD90(float roughness, float LoH)
            {
                return 0.5 + (2.0 * roughness * LoH * LoH);
            }
            float3 NDF(float roughness, float NoH)
            {
                float a2 = roughness * roughness;
                float NoH2 = NoH * NoH;
                float c = (NoH2 * (a2 - 1.0)) + 1.0;
                return max(a2 / (PI * c * c), 1e-7);
            }
            float GSF(float NoL, float NoV, float roughness)
            {
                float k = ((roughness * 1.0) * (roughness * 1.0)) / 8.0;
                float l = NoL / (NoL * (1.0 - k) + k);
                float v = NoV / (NoV * (1.0 - k) + k);
                return max(l * v, 1e-7);
            }
            #if defined(_SOURCE2_LIGHTING)
            float GetS2SpecularOcclusion(float NoV, float occlusion, float perceptualRoughness, float3 reflectVector, float3 bentNormalWS)
            {
                float roughness = perceptualRoughness * perceptualRoughness;
                float visibility = saturate(pow(abs(NoV + occlusion), exp2(-16.0 * roughness - 1.0)) - 1.0 + occlusion);
                
                float bentNormalOcclusion = saturate(dot(reflectVector, bentNormalWS));
                
                return lerp(bentNormalOcclusion, visibility, perceptualRoughness);
            }
            #endif
            float3 EvaluateLighting(float3 diffuseColor, float3 f0, float perceptualRoughness, float3 normalWS, float occlusion, float3 viewDirectionWS, float NoV, float3 lightDir, float3 lightColor)
            {
                float roughness = perceptualRoughness * perceptualRoughness;
                float NoL = saturate(dot(normalWS, lightDir));

                //BRDF vectors
                float3 H = SafeNormalize(lightDir + viewDirectionWS);
                float NoH = saturate(dot(normalWS, H));
                float LoH = saturate(dot(lightDir, H));
                float VoH = saturate(dot(viewDirectionWS, H));
                
                #if defined(_SOURCE2_LIGHTING)
                    //valve source 2 diffuse
                    float3 diffuse = diffuseColor / PI;
                    float3 ndf = NDF(roughness, NoH);
                    float3 fresnel = Fresnel(f0, VoH, roughness);
                    float gsf = GSF(NoL, NoV, roughness);
                    float3 specular = (fresnel * ndf * gsf) / max((4.0 * NoL * NoV), 1e-7);
                #else
                    //calculate disney/burley diffuse
                    float3 diffuse = (diffuseColor / PI) * (1.0 + (FD90(perceptualRoughness, LoH) - 1.0) * SchlickFresnel(NoL)) * (1.0 + (FD90(perceptualRoughness, LoH) - 1.0) * SchlickFresnel(NoV));

                    //calculate GGX specular
                    float3 ndf = NDF(roughness, NoH);
                    float3 fresnel = Fresnel(f0, VoH, roughness);
                    float gsf = GSF(NoL, NoV, roughness);
                    float3 specular = (fresnel * ndf * gsf) / max((4.0 * NoL * NoV), 1e-7);
                #endif
                
                #if defined(_USE_GTBN)
                    float directOcclusion = lerp(1.0, occlusion, _GTBNDirectLightStrength);
                    return (diffuse + specular) * lightColor * NoL * PI * directOcclusion;
                #else
                    return (diffuse + specular) * lightColor * NoL * PI;
                #endif
            }

            //FRAGMENT SHADER
            half4 Frag(Varyings input) : SV_Target
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
                
                //URP CLUSTERED DYNAMIC LIGHTS
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
                    }
                #endif
                
                //sample environment (skybox and reflection probes)
                #if defined(_SOURCE2_LIGHTING)
                    //source 2 specular
                    half3 reflectVector = reflect(-viewDirectionWS, bentNormalWS);
                    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, perceptualRoughness, 1.0);
                #else
                    //disney specular
                    half3 reflectVector = reflect(-viewDirectionWS, bentNormalWS);
                    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, perceptualRoughness, occlusion);
                #endif
                
                //get reflection intensity based on roughness and fresnel at grazing angles
                half surfaceReduction = 1.0 / (perceptualRoughness * perceptualRoughness + 1.0);
                half reflectivity = max(max(f0.r, f0.g), f0.b);
                half grazingTerm = saturate(1.0 - perceptualRoughness + reflectivity);
                
                half3 envFresnel = f0 + (grazingTerm - f0) * SchlickFresnel(NoV);
                half3 appliedIndirectSpecular = surfaceReduction * indirectSpecular * envFresnel;
                
                #if defined(_SOURCE2_LIGHTING)
                    //valve specular occlusion
                    float specOcc = GetS2SpecularOcclusion(NoV, occlusion, perceptualRoughness, reflectVector, bentNormalWS);
                    appliedIndirectSpecular *= specOcc;
                #endif

                finalColor += appliedIndirectSpecular;
                finalColor += emission * occlusion;
                
                return half4(finalColor, 1.0);
            }
            
            ENDHLSL
        }
    }
}