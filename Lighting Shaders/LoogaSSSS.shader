Shader "Hidden/LoogaSoft/SSSS"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100
        
        ZWrite Off 
        ZTest Always 
        Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        TEXTURE2D_X_HALF(_SSSSProfileTexture);

        static const float SSS_WEIGHTS[7] = { 0.006, 0.061, 0.242, 0.382, 0.242, 0.061, 0.006 };
        static const float SSS_OFFSETS[7] = { -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0 };

        half4 PerformBlur(Varyings input, float2 direction)
        {
            float2 uv = input.texcoord;

            // 1. Read Profile Target FIRST
            half4 sssData = SAMPLE_TEXTURE2D_X_LOD(_SSSSProfileTexture, sampler_LinearClamp, uv, 0);
            
            // EARLY OUT: If the profile is blank, this is not a skin pixel. Skip the expensive blur entirely.
            if (sssData.a <= 0.001)
            {
                return SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, uv, 0);
            }

            half4 centerColor = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, uv, 0);
            float centerDepth = SampleSceneDepth(uv);
            float linearCenterDepth = LinearEyeDepth(centerDepth, _ZBufferParams);
            
            float localScatterWidth = sssData.a * 5.0; 
            half3 localSubsurfaceColor = sssData.rgb;

            // 2. Fix the Scale Math (Multiply by 15.0 so it maps cleanly to screen pixels)
            float2 texelSize = _ScreenSize.zw; 
            float2 step = texelSize * direction * (localScatterWidth * 15.0) / max(linearCenterDepth, 0.001);

            half3 blurredColor = centerColor.rgb * SSS_WEIGHTS[3];
            float totalWeight = SSS_WEIGHTS[3];

            for(int i = 0; i < 7; i++)
            {
                if (i == 3) continue;

                float2 offsetUV = uv + step * SSS_OFFSETS[i];
                float sampleDepth = SampleSceneDepth(offsetUV);
                float linearSampleDepth = LinearEyeDepth(sampleDepth, _ZBufferParams);

                // 3. Loosen the Depth Rejection (Reduced from 30.0 to 8.0)
                float depthDiff = abs(linearCenterDepth - linearSampleDepth);
                float depthWeight = exp(-depthDiff * 8.0); 
                
                float weight = SSS_WEIGHTS[i] * depthWeight;

                half3 sampleColor = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, offsetUV, 0).rgb;
                blurredColor += sampleColor * weight;
                totalWeight += weight;
            }

            blurredColor /= max(totalWeight, 0.0001);

            half3 finalColor = lerp(centerColor.rgb, blurredColor, localSubsurfaceColor);

            return half4(finalColor, centerColor.a);
        }
        ENDHLSL

        // ====================================================================
        // PASS 0: HORIZONTAL BLUR
        // ====================================================================
        Pass
        {
            Name "Horizontal SSSS Blur"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragHorizontal

            half4 FragHorizontal(Varyings input) : SV_Target
            {
                return PerformBlur(input, float2(1.0, 0.0));
            }
            ENDHLSL
        }

        // ====================================================================
        // PASS 1: VERTICAL BLUR
        // ====================================================================
        Pass
        {
            Name "Vertical SSSS Blur"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragVertical

            half4 FragVertical(Varyings input) : SV_Target
            {
                return PerformBlur(input, float2(0.0, 1.0));
            }
            ENDHLSL
        }
    }
}