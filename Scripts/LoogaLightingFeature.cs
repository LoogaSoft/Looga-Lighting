using System;
using UnityEditor;
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
            Source2
        }

        [Serializable]
        public class GTBNSettings
        {
            [Range(0.1f, 1.0f)] public float radius = 0.3f;
            [Range(10f, 150f)] public float maxRadiusPixels = 100f;
            [Range(0.01f, 0.5f)] public float thickness = 0.2f;
            [Range(0.0f, 3.0f)] public float intensity = 1f;
            [Range(1, 8)] public int sliceCount = 3;
            [Range(2, 16)] public int stepCount = 8;
            [Range(0.0f, 1.0f)] public float directLightStrength = 0.5f;
            [Range(0, 4)] public int blurRadius = 2;
        }
        
        public LightingModel activeLightingModel = LightingModel.DisneyBurley;

        public bool useGTBN = false;
        public GTBNSettings gtbnSettings = new();
        public ComputeShader gtbnCompute;
        public ComputeShader gtbnBlurCompute;
        public Shader gtbnApplyShader;

        [SerializeField] private Shader _customLightingShader;
        private Material _customLightingMaterial;
        private Material _gtbnApplyMaterial;
        private CustomLightingPass _customLightingPass;
        private LoogaGTBNPass _gtbnPass;
        
        #if UNITY_EDITOR
        private void OnValidate()
        {
            bool needsSave = false;

            if (_customLightingShader == null)
            {
                _customLightingShader = Shader.Find("Hidden/LoogaSoft/LoogaLighting");
                if (_customLightingShader != null)
                    needsSave = true;
            }

            if (gtbnCompute == null)
                AssignCompute(ref gtbnCompute, "LoogaGTBN", ref needsSave);
            if (gtbnBlurCompute == null)
                AssignCompute(ref gtbnBlurCompute, "LoogaGTBNBlur", ref needsSave);

            if (gtbnApplyShader == null)
            {
                gtbnApplyShader = Shader.Find("Hidden/LoogaSoft/ApplyGTBN");
                needsSave = true;
            }
            
            if (needsSave)
                EditorUtility.SetDirty(this);
        }

        private void AssignCompute(ref ComputeShader compute, string computeName, ref bool needsSave)
        {
            string[] guids = AssetDatabase.FindAssets($"{computeName} t:ComputeShader");
            if (guids.Length > 0)
            {
                string path = AssetDatabase.GUIDToAssetPath(guids[0]);
                compute = AssetDatabase.LoadAssetAtPath<ComputeShader>(path);
                needsSave = true;
            }
        }
        #endif
        
        public override void Create()
        {
            if (_customLightingShader == null)
                _customLightingShader = Shader.Find("Hidden/LoogaSoft/LoogaLighting");
            if (gtbnApplyShader == null)
                gtbnApplyShader = Shader.Find("Hidden/LoogaSoft/ApplyGTBN");
            
            if (_customLightingShader != null && _customLightingMaterial == null)
                _customLightingMaterial = CoreUtils.CreateEngineMaterial(_customLightingShader);
            if (_customLightingMaterial != null && _customLightingPass == null)
                _customLightingPass = new CustomLightingPass(_customLightingMaterial);
            if (gtbnApplyShader != null && _gtbnApplyMaterial == null)
                _gtbnApplyMaterial = CoreUtils.CreateEngineMaterial(gtbnApplyShader);
            if (_gtbnPass == null)
                _gtbnPass = new LoogaGTBNPass();
        }
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (_customLightingMaterial == null) return;
            
            bool isSource2Lighting = activeLightingModel == LightingModel.Source2;
            if (isSource2Lighting)
                _customLightingMaterial.EnableKeyword("_SOURCE2_LIGHTING");
            else
                _customLightingMaterial.DisableKeyword("_SOURCE2_LIGHTING");

            if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView)
            {
                if (useGTBN && gtbnCompute != null && gtbnBlurCompute != null)
                {
                    _customLightingMaterial.EnableKeyword("_USE_GTBN");
                    _customLightingMaterial.SetFloat("_GTBNDirectLightStrength", gtbnSettings.directLightStrength);
                    _gtbnPass.Setup(gtbnCompute, gtbnBlurCompute, _gtbnApplyMaterial, gtbnSettings);
                    renderer.EnqueuePass(_gtbnPass);
                }
                else
                    _customLightingMaterial.DisableKeyword("_USE_GTBN");
                
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

            if (_gtbnApplyMaterial != null)
            {
                CoreUtils.Destroy(_gtbnApplyMaterial);
                _gtbnApplyMaterial = null;
            }
            
            _customLightingPass = null;
            _gtbnPass = null;

            base.Dispose(disposing);
        }

        private class CustomLightingPass : ScriptableRenderPass
        {
            private readonly Material _lightingMaterial;

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