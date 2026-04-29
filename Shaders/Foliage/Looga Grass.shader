Shader "LoogaSoft/Grass"
{
    Properties
    {
        [MainTexture] _BaseMap ("Albedo & Alpha", 2D) = "white" {}
        [Enum(Specular, 0, Metallic, 1)] _WorkflowMode ("Workflow Mode", Float) = 1.0
        [Enum(Opaque, 0, Transparent, 1)] _Surface ("Surface Type", Float) = 0.0
        _Cull ("Render Face", Float) = 0.0
        [Enum(Mirror, 0, Flip, 1)] _BackfaceNormalMode ("Backface Normals", Float) = 1.0
        [ToggleUI] _AlphaClip ("Alpha Clipping", Float) = 1.0
        [ToggleUI] _ReceiveShadows ("Receive Shadows", Float) = 1.0
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Float) = 1.0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.1
        
        [Toggle(_USE_SSSS)] _UseSSSS ("Enable SSSS", Float) = 1.0
        _SubsurfaceColor ("Subsurface Color", Color) = (0.6, 0.8, 0.2, 1.0)
        _ScatterWidth ("Scatter Width", Range(0.1, 5.0)) = 1.5
        _ThicknessMap ("Thickness Map (Black=Glow, White=Solid)", 2D) = "black" {}
        _TransmissionStrength ("Transmission Strength", Range(0.0, 5.0)) = 1.0

        _WindInfluence ("Wind Influence", Range(0.0, 1.0)) = 1.0
        _WindTint ("Wind Gust Tint", Color) = (1.2, 1.2, 0.8, 1.0)
        _WindTintStrength ("Wind Tint Strength", Range(0, 1)) = 0.5
        
        _InteractionBend ("Interaction Bend Strength", Range(0.0, 5.0)) = 1.0
        
        _GlobalGridScale ("Global Grid Scale", Float) = 0.1
        _GlobalHueVar ("Global Hue Var", Vector) = (0, 0, 0, 0)
        _GlobalSatVar ("Global Sat Var", Vector) = (0, 0, 0, 0)
        _GlobalLumVar ("Global Lum Var", Vector) = (0, 0, 0, 0)
        
        _LocalNoiseScale ("Local Noise Scale", Float) = 1.0
        [Enum(Blocky, 0, Smooth, 1, Wavy, 2)] _LocalNoiseType ("Local Noise Type", Int) = 1
        _LocalHueVar ("Local Hue Var", Vector) = (0, 0, 0, 0)
        _LocalSatVar ("Local Sat Var", Vector) = (0, 0, 0, 0)
        _LocalLumVar ("Local Lum Var", Vector) = (0, 0, 0, 0)
        
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
    }
    
    SubShader
    {
        Tags { "RenderType" = "TransparentCutout" "RenderPipeline" = "UniversalPipeline" "Queue" = "AlphaTest" }
        Cull [_Cull]

        // =========================================================
        // 1. GBUFFER PASS
        // =========================================================
        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "UniversalGBuffer" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _USE_SSSS
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            
            #include "LoogaFoliageCore.hlsl"
            #include "Packages/com.loogasoft.loogalighting/Includes/LoogaLightingHelpers.hlsl"

            FoliageVaryings Vert(FoliageAttributes input)
            {
                FoliageVaryings output; 
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                float3 interactionPushWS = ApplyGrassInteraction(positionWS, input.positionOS.xyz, _InteractionBend); 
                float3 interactionPushOS = mul(GetWorldToObjectMatrix(), float4(interactionPushWS, 0.0)).xyz; 
                input.positionOS.xyz += interactionPushOS;
                
                positionWS = TransformObjectToWorld(input.positionOS.xyz); 
                input.positionOS.xyz = ApplyProceduralWind(input.positionOS.xyz, positionWS, 1.0, _WindInfluence); 
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                output.windGust = CalculateWindGust(output.positionWS);
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz); 
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                
                output.positionCS = vertexInput.positionCS; 
                output.uv = input.uv; 
                output.normalWS = normalInput.normalWS; 
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w); 
                
                return output;
            }

            struct FragmentOutput 
            { 
                half4 GBuffer0 : SV_Target0; 
                half4 GBuffer1 : SV_Target1; 
                half4 GBuffer2 : SV_Target2; 
                half4 GBuffer3 : SV_Target3; 
            };
            
            FragmentOutput Frag(FoliageVaryings input, bool isFrontFace : SV_IsFrontFace)
            {
                FragmentOutput outGBuffer;
                
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv); 
                if (_AlphaClip > 0.5) clip(albedo.a - _Cutoff);
                
                half3 finalAlbedo = GetVariedColor(albedo.rgb, input.positionWS); 
                half3 windTintedColor = finalAlbedo * _WindTint.rgb; 
                finalAlbedo = lerp(finalAlbedo, windTintedColor, input.windGust * _WindTintStrength);

                half4 normalSample = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                half3 normalTS = UnpackNormalScale(normalSample, _BumpScale);
                
                half sign = input.tangentWS.w * GetOddNegativeScale(); 
                half3 bitangentWS = cross(input.normalWS, input.tangentWS.xyz) * sign;
                half3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS)); 
                normalWS = NormalizeNormalPerPixel(normalWS); 
                normalWS = (!isFrontFace && _BackfaceNormalMode > 0.5) ? -normalWS : normalWS;

                half3 ambientDiffuse = EvaluateLoogaAmbientDiffuse(finalAlbedo, normalWS, 1.0);

                #if defined(_USE_SSSS)
                    half thickness = SAMPLE_TEXTURE2D(_ThicknessMap, sampler_BaseMap, input.uv).r;
                    half transmissionMask = (1.0 - thickness) * _TransmissionStrength;
                    outGBuffer.GBuffer0 = half4(finalAlbedo, 33.0 / 255.0);
                    outGBuffer.GBuffer3 = half4(ambientDiffuse, transmissionMask); 
                #else
                    outGBuffer.GBuffer0 = half4(finalAlbedo, 1.0 / 255.0); 
                    outGBuffer.GBuffer3 = half4(ambientDiffuse, 0); 
                #endif
                
                outGBuffer.GBuffer1 = half4(0.0, 0.0, 0.0, 1.0); 
                outGBuffer.GBuffer2 = half4(PackGBufferNormal(normalWS), _Smoothness);
                
                return outGBuffer;
            }
            ENDHLSL
        }

        // =========================================================
        // 2. FORWARD LIT PASS
        // =========================================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            ZWrite On 
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex VertForward
            #pragma fragment FragForward
            #pragma shader_feature_local _USE_SSSS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _SHADOWS_SOFT
            
            #include "LoogaFoliageCore.hlsl"
            #include "Packages/com.loogasoft.loogalighting/Includes/LoogaLightingHelpers.hlsl"
            #include "Packages/com.loogasoft.loogalighting/Includes/LoogaMasterLighting.hlsl"

            FoliageVaryings VertForward(FoliageAttributes input)
            {
                FoliageVaryings output; 
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                float3 interactionPushWS = ApplyGrassInteraction(positionWS, input.positionOS.xyz, _InteractionBend); 
                float3 interactionPushOS = mul(GetWorldToObjectMatrix(), float4(interactionPushWS, 0.0)).xyz; 
                input.positionOS.xyz += interactionPushOS;
                
                positionWS = TransformObjectToWorld(input.positionOS.xyz); 
                input.positionOS.xyz = ApplyProceduralWind(input.positionOS.xyz, positionWS, 1.0, _WindInfluence); 
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                output.windGust = CalculateWindGust(output.positionWS);
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz); 
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                
                output.positionCS = vertexInput.positionCS; 
                output.uv = input.uv; 
                output.normalWS = normalInput.normalWS; 
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w); 
                
                return output;
            }

            half4 FragForward(FoliageVaryings input, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                half4 albedoSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv); 
                if (_AlphaClip > 0.5) clip(albedoSample.a - _Cutoff);
                
                half3 finalAlbedo = GetVariedColor(albedoSample.rgb, input.positionWS); 
                half3 windTintedColor = finalAlbedo * _WindTint.rgb; 
                finalAlbedo = lerp(finalAlbedo, windTintedColor, input.windGust * _WindTintStrength);

                half4 normalSample = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                half3 normalTS = UnpackNormalScale(normalSample, _BumpScale);
                
                half sign = input.tangentWS.w * GetOddNegativeScale(); 
                half3 bitangentWS = cross(input.normalWS, input.tangentWS.xyz) * sign;
                half3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS)); 
                normalWS = NormalizeNormalPerPixel(normalWS); 
                normalWS = (!isFrontFace && _BackfaceNormalMode > 0.5) ? -normalWS : normalWS;

                half perceptualRoughness = 1.0 - _Smoothness; 
                half3 f0 = kDielectricSpec.rgb;
                
                float3 viewDirWS = SafeNormalize(GetCameraPositionWS() - input.positionWS); 
                float NoV = saturate(dot(normalWS, viewDirWS)); 
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                
                Light mainLight = GetMainLight(shadowCoord, input.positionWS, 1.0); 
                float3 mainRadiance = mainLight.color * mainLight.shadowAttenuation * mainLight.distanceAttenuation;
                float3 color = EvaluateGlobalLoogaLighting(finalAlbedo, f0, perceptualRoughness, normalWS, 1.0, viewDirWS, NoV, mainLight.direction, mainRadiance);

                #if defined(_USE_SSSS)
                    half thickness = SAMPLE_TEXTURE2D(_ThicknessMap, sampler_BaseMap, input.uv).r;
                    half transmissionMask = (1.0 - thickness) * _TransmissionStrength;
                    color += EvaluateTransmission(_SubsurfaceColor.rgb, _ScatterWidth, mainLight.direction, viewDirWS, normalWS, mainRadiance, mainLight.shadowAttenuation, transmissionMask);
                #endif

                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightCount; lightIndex++)
                {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS, half4(1,1,1,1)); 
                    float3 dynRadiance = light.color * light.shadowAttenuation * light.distanceAttenuation;
                    color += EvaluateGlobalLoogaLighting(finalAlbedo, f0, perceptualRoughness, normalWS, 1.0, viewDirWS, NoV, light.direction, dynRadiance);
                }
                
                color += EvaluateLoogaAmbientDiffuse(finalAlbedo, normalWS, 1.0);
                color += EvaluateGlobalLoogaIndirect(f0, perceptualRoughness, 1.0, viewDirWS, normalWS, normalWS, NoV, input.positionWS, input.uv);
                
                return half4(color, 1.0);
            }
            ENDHLSL
        }
        
        // =========================================================
        // 3. SSSS PROFILE PASS
        // =========================================================
        Pass 
        { 
            Name "SSSSProfile" 
            Tags { "LightMode" = "SSSSProfile" } 
            
            ZWrite Off 
            ZTest LEqual 
            Cull [_Cull]

            HLSLPROGRAM 
            #pragma vertex VertProfile 
            #pragma fragment FragProfile 
            #pragma shader_feature_local _USE_SSSS 
            
            #include "LoogaFoliageCore.hlsl" 

            VaryingsProfile VertProfile(AttributesProfile input) 
            { 
                VaryingsProfile output; 
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz); 
                input.positionOS.xyz = ApplyProceduralWind(input.positionOS.xyz, positionWS, 1.0, _WindInfluence); 
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz); 
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz); 
                output.uv = input.uv; 
                return output; 
            } 

            half4 FragProfile(VaryingsProfile input) : SV_Target 
            { 
                #if !defined(_USE_SSSS) 
                    discard; 
                #endif 
                
                if (_AlphaClip > 0.5) clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a - _Cutoff);
                
                half3 finalSSSS = GetVariedColor(_SubsurfaceColor.rgb, input.positionWS); 
                return half4(finalSSSS, _ScatterWidth / 5.0); 
            } 
            ENDHLSL 
        }

        // =========================================================
        // 4. META PASS
        // =========================================================
        Pass 
        { 
            Name "Meta" 
            Tags { "LightMode" = "Meta" } 
            
            Cull Off 

            HLSLPROGRAM 
            #pragma vertex UniversalVertexMeta 
            #pragma fragment UniversalFragmentMetaLit 
            #pragma shader_feature EDITOR_VISUALIZATION 

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl" 
            ENDHLSL 
        }

        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER" 
        UsePass "Universal Render Pipeline/Lit/DEPTHONLY"
    }
    
    CustomEditor "LoogaSoft.LightingPrime.Editor.LoogaGrassShaderGUI" 
    Fallback "Universal Render Pipeline/Lit"
}
