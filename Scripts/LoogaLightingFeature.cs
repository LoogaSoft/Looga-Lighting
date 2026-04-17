using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace LoogaSoft.Lighting
{
    [DisallowMultipleRendererFeature("Looga Lighting")]
    public class LoogaLightingFeature : ScriptableRendererFeature
    {
        public enum LightingModel
        {
            DisneyBurley,
            Source2,
            TF2,
            Minnaert,
            Overwatch,
            OrenNayar,
            Arkane
        }
        
        public LightingModel activeLightingModel = LightingModel.DisneyBurley;

        private Material _customLightingMaterial;
        private CustomLightingPass _customLightingPass;
        
        public override void Create()
        {
            UpdateLightingMaterial();
        }

        private void UpdateLightingMaterial()
        {
            string shaderName = activeLightingModel switch
            {
                LightingModel.DisneyBurley => "Hidden/LoogaSoft/Lighting/DisneyBurley",
                LightingModel.Source2 => "Hidden/LoogaSoft/Lighting/Source2",
                LightingModel.TF2 => "Hidden/LoogaSoft/Lighting/TF2",
                LightingModel.Minnaert => "Hidden/LoogaSoft/Lighting/Minnaert",
                LightingModel.Overwatch => "Hidden/LoogaSoft/Lighting/Overwatch",
                LightingModel.OrenNayar => "Hidden/LoogaSoft/Lighting/OrenNayar",
                LightingModel.Arkane => "Hidden/LoogaSoft/Lighting/Arkane",
                _ => "Hidden/LoogaSoft/Lighting/DisneyBurley"
            };

            if (_customLightingMaterial == null || _customLightingMaterial.shader.name != shaderName)
            {
                if (_customLightingMaterial != null)
                    CoreUtils.Destroy(_customLightingMaterial);

                Shader shader = Shader.Find(shaderName);
                if (shader != null)
                {
                    _customLightingMaterial = CoreUtils.CreateEngineMaterial(shader);
                }
                else
                {
                    Debug.LogError($"[LoogaLighting] Could not find shader: {shaderName}");
                }
            }

            if (_customLightingMaterial != null)
            {
                if (_customLightingPass == null)
                    _customLightingPass = new CustomLightingPass(_customLightingMaterial);
                else
                    _customLightingPass.UpdateMaterial(_customLightingMaterial);
            }
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            UpdateLightingMaterial();

            if (_customLightingMaterial == null) return;
            
            if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView)
            {
                renderer.EnqueuePass(_customLightingPass);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (_customLightingMaterial != null)
            {
                CoreUtils.Destroy(_customLightingMaterial);
                _customLightingMaterial = null;
            }
            
            _customLightingPass = null;
            base.Dispose(disposing);
        }

        private class CustomLightingPass : ScriptableRenderPass
        {
            private Material _lightingMaterial;

            private static readonly int[] ShaderGBufferIDs = {
                Shader.PropertyToID("_GBuffer0"),
                Shader.PropertyToID("_GBuffer1"),
                Shader.PropertyToID("_GBuffer2"),
                Shader.PropertyToID("_GBuffer3"),
            };
            
            private static readonly int CameraDepthTextureID = Shader.PropertyToID("_CameraDepthTexture");

            public CustomLightingPass(Material material)
            {
                _lightingMaterial = material;
                renderPassEvent = RenderPassEvent.BeforeRenderingDeferredLights;
            }

            public void UpdateMaterial(Material newMaterial)
            {
                _lightingMaterial = newMaterial;
            }
            
            private class LightingPassData
            {
                public Material material;
                public TextureHandle[] gBuffers;
                public TextureHandle depthTexture;
            }
            
            private class BlitPassData
            {
                public TextureHandle source;
            }

            public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
            {
                UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
                UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
  
                if (_lightingMaterial == null) return;
                
                TextureHandle activeColor = resourceData.activeColorTexture;
                TextureHandle hardwareDepth = resourceData.activeDepthTexture;
                TextureHandle stencilTexture = resourceData.activeDepthTexture;
                
                RenderTextureDescriptor desc = cameraData.cameraTargetDescriptor;
                desc.depthBufferBits = 0;
                TextureHandle tempLightingTarget = renderGraph.CreateTexture(new TextureDesc(desc)
                {
                    name = "Looga Lighting Target",
                    enableRandomWrite = true,
                    clearBuffer = true,
                    clearColor = Color.clear
                });

                using (var builder = renderGraph.AddRasterRenderPass<LightingPassData>("Looga Lighting Evaluation", out var passData))
                {
                    passData.material = _lightingMaterial;
                    passData.depthTexture = hardwareDepth;

                    TextureHandle[] currentGBuffers = resourceData.gBuffer;
                    if (currentGBuffers != null)
                    {
                        passData.gBuffers = new TextureHandle[Mathf.Min(currentGBuffers.Length, 4)];
                        for (int i = 0; i < passData.gBuffers.Length; i++)
                        {
                            if (currentGBuffers[i].IsValid())
                            {
                                passData.gBuffers[i] = currentGBuffers[i];
                                builder.UseTexture(passData.gBuffers[i], AccessFlags.Read);
                            }
                        }
                    }
                    
                    if (passData.depthTexture.IsValid())
                        builder.UseTexture(passData.depthTexture, AccessFlags.Read);

                    builder.SetRenderAttachment(tempLightingTarget, 0, AccessFlags.Write);
                    builder.AllowGlobalStateModification(true);
                    
                    builder.SetRenderFunc((LightingPassData data, RasterGraphContext context) =>
                    {
                        RasterCommandBuffer cmd = context.cmd;

                        if (data.gBuffers != null)
                        {
                            for (int i = 0; i < data.gBuffers.Length; i++)
                            {
                                if (data.gBuffers[i].IsValid())
                                    cmd.SetGlobalTexture(ShaderGBufferIDs[i], data.gBuffers[i]);
                            }
                        }
                        
                        if (data.depthTexture.IsValid())
                            cmd.SetGlobalTexture(CameraDepthTextureID, data.depthTexture);

                        Blitter.BlitTexture(cmd, new Vector4(1,1,0,0), data.material, 0);
                    });
                }

                using (var builder = renderGraph.AddRasterRenderPass<BlitPassData>("Looga Lighting Blit", out var passData))
                {
                    passData.source = tempLightingTarget;
                    
                    builder.UseTexture(passData.source, AccessFlags.Read);
                    builder.SetRenderAttachment(activeColor, 0, AccessFlags.Write);
                    
                    if (stencilTexture.IsValid())
                        builder.SetRenderAttachmentDepth(stencilTexture, AccessFlags.Write);
                    
                    builder.SetRenderFunc((BlitPassData data, RasterGraphContext context) =>
                    {
                        RasterCommandBuffer cmd = context.cmd;
                        Blitter.BlitTexture(cmd, data.source, new Vector4(1,1,0,0), 0.0f, false);
                        cmd.ClearRenderTarget(RTClearFlags.Stencil, Color.clear, 1.0f, 0);
                    });
                }
            }
        }
    }
}