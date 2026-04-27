using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using System.Reflection;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace LoogaSoft.Lighting
{
    [DisallowMultipleRendererFeature("Looga Master Lighting")]
    public class LoogaLightingFeature : ScriptableRendererFeature
    {
        public enum LightingModel
        {
            DisneyBurley = 0,
            Source2 = 1,
            TF2 = 2,
            Minnaert = 3,
            Overwatch = 4,
            OrenNayar = 5,
            Arkane = 6
        }
        
        [Header("Global Illumination & Models")]
        public LightingModel activeLightingModel = LightingModel.DisneyBurley;

        [Header("GTBN Settings")]
        public bool enableGTBN = true;
        [Range(0.1f, 1.0f)] public float gtbnRadius = 0.3f;
        [Range(10f, 150f)] public float gtbnMaxRadiusPixels = 100f;
        [Range(0.01f, 0.5f)] public float gtbnThickness = 0.2f;
        [Range(0.0f, 3.0f)] public float gtbnIntensity = 1f;
        [Range(1, 8)] public int gtbnSliceCount = 3;
        [Range(2, 16)] public int gtbnStepCount = 8;
        [Range(0.0f, 1.0f)] public float gtbnDirectLightStrength = 0.5f;
        [Range(0, 4)] public int gtbnBlurRadius = 2;

        [HideInInspector] public ComputeShader gtbnCompute;
        [HideInInspector] public ComputeShader gtbnBlurCompute;
        [HideInInspector] public Shader gtbnApplyShader;

        private Material _activeLightingMaterial;
        private Material _ssssMaterial;
        private Material _gtbnApplyMaterial;

        private LoogaGTBNPass _gtbnPass;
        private CustomLightingPass _customLightingPass;

        private static readonly int GlobalLightingModelID = Shader.PropertyToID("_LoogaLightingModel");
        private static readonly int GBufferNormalsAreOctID = Shader.PropertyToID("_LoogaGBufferNormalsAreOct");

        #if UNITY_EDITOR
        private void OnValidate()
        {
            bool needsSave = false;

            if (gtbnCompute == null) AssignCompute(ref gtbnCompute, "LoogaGTBN", ref needsSave);
            if (gtbnBlurCompute == null) AssignCompute(ref gtbnBlurCompute, "LoogaGTBNBlur", ref needsSave);

            if (gtbnApplyShader == null)
            {
                gtbnApplyShader = Shader.Find("Hidden/LoogaSoft/ApplyGTBN");
                if (gtbnApplyShader != null) needsSave = true;
            }
            
            if (needsSave) EditorUtility.SetDirty(this);
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
            UpdateLightingState();
        }

        private void UpdateLightingState()
        {
            // 1. Core Lighting Initialization
            Shader.SetGlobalInteger(GlobalLightingModelID, (int)activeLightingModel);

            if (_activeLightingMaterial == null || _activeLightingMaterial.shader.name != "Hidden/LoogaSoft/Lighting/MasterDeferred")
            {
                if (_activeLightingMaterial != null) CoreUtils.Destroy(_activeLightingMaterial);
                Shader shader = Shader.Find("Hidden/LoogaSoft/Lighting/MasterDeferred");
                if (shader != null) _activeLightingMaterial = CoreUtils.CreateEngineMaterial(shader);
            }

            if (_ssssMaterial == null || _ssssMaterial.shader.name != "Hidden/LoogaSoft/SSSS")
            {
                Shader ssssShader = Shader.Find("Hidden/LoogaSoft/SSSS");
                if (ssssShader != null) _ssssMaterial = CoreUtils.CreateEngineMaterial(ssssShader);
            }

            if (_activeLightingMaterial != null)
            {
                if (_customLightingPass == null) _customLightingPass = new CustomLightingPass(this);
                else _customLightingPass.UpdateMaterials(this);
            }

            // 2. GTBN Initialization
            if (gtbnApplyShader == null) gtbnApplyShader = Shader.Find("Hidden/LoogaSoft/ApplyGTBN");
            if (gtbnApplyShader != null && _gtbnApplyMaterial == null) _gtbnApplyMaterial = CoreUtils.CreateEngineMaterial(gtbnApplyShader);
                
            if (_gtbnPass == null) _gtbnPass = new LoogaGTBNPass();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (!isActive || (renderingData.cameraData.cameraType != CameraType.Game && renderingData.cameraData.cameraType != CameraType.SceneView))
                return;

            UpdateLightingState();

            // 1. Enqueue GTBN 
            if (enableGTBN && gtbnCompute != null && gtbnBlurCompute != null && _gtbnApplyMaterial != null)
            {
                Shader.EnableKeyword("_USE_GTBN");
                Shader.SetGlobalFloat("_GTBNDirectLightStrength", gtbnDirectLightStrength);
                
                _gtbnPass.Setup(gtbnCompute, gtbnBlurCompute, _gtbnApplyMaterial, this, UsesAccurateGBufferNormals(renderer));
                renderer.EnqueuePass(_gtbnPass);
            }
            else
            {
                Shader.DisableKeyword("_USE_GTBN");
            }

            // 2. Enqueue Deferred Lighting
            if (_activeLightingMaterial != null && _customLightingPass != null)
            {
                renderer.EnqueuePass(_customLightingPass);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (_activeLightingMaterial != null) CoreUtils.Destroy(_activeLightingMaterial);
            if (_ssssMaterial != null) CoreUtils.Destroy(_ssssMaterial);
            if (_gtbnApplyMaterial != null) CoreUtils.Destroy(_gtbnApplyMaterial);
            
            _customLightingPass = null;
            _gtbnPass = null;
            base.Dispose(disposing);
        }

        private static bool UsesAccurateGBufferNormals(ScriptableRenderer renderer)
        {
            const BindingFlags flags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
            PropertyInfo property = renderer?.GetType().GetProperty("accurateGbufferNormals", flags);

            if (property != null && property.PropertyType == typeof(bool))
                return (bool)property.GetValue(renderer);

            return false;
        }

        // =======================================================================
        // NESTED PASS 1: GTBN (Executes at BeforeRenderingDeferredLights - 1)
        // =======================================================================
        private class LoogaGTBNPass : ScriptableRenderPass
        {
            private ComputeShader _gtbnCompute;
            private ComputeShader _blurCompute;
            private Material _applyMaterial;
            private LoogaLightingFeature _feature;
            private bool _useAccurateGBufferNormals;
            
            private int _gtbnKernel, _blurHKernel, _blurVKernel;
            private static readonly int GTBNTextureID = Shader.PropertyToID("_GTBNTexture");

            public LoogaGTBNPass()
            {
                renderPassEvent = RenderPassEvent.BeforeRenderingDeferredLights - 1;
            }

            public void Setup(ComputeShader gtbnCompute, ComputeShader blurCompute, Material applyMaterial, LoogaLightingFeature feature, bool useAccurateGBufferNormals)
            {
                _gtbnCompute = gtbnCompute;
                _blurCompute = blurCompute;
                _applyMaterial = applyMaterial;
                _feature = feature;
                _useAccurateGBufferNormals = useAccurateGBufferNormals;
                
                if (_gtbnCompute != null) _gtbnKernel = _gtbnCompute.FindKernel("CSMain");
                if (_blurCompute != null)
                {
                    _blurHKernel = _blurCompute.FindKernel("BlurHorizontal");
                    _blurVKernel = _blurCompute.FindKernel("BlurVertical");
                }
            }

            private class PassData
            {
                public TextureHandle depthTexture, normalsTexture, gtbnTarget, blurPingPong;
                public Vector4 bottomLeftCorner, xExtent, yExtent;
                public Matrix4x4 viewMatrix, invViewMatrix;
                public float projScale;
                public bool useAccurateGBufferNormals;
            }

            private class ApplyPassData
            {
                public Material material;
                public TextureHandle gtbnSource;
            }

            public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
            {
                if (_gtbnCompute == null || _blurCompute == null) return;
                
                UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
                UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
                
                RenderTextureDescriptor desc = cameraData.cameraTargetDescriptor;
                desc.colorFormat = RenderTextureFormat.ARGB32;
                desc.depthBufferBits = 0;
                desc.enableRandomWrite = true;

                TextureHandle gtbnTarget = renderGraph.CreateTexture(new TextureDesc(desc) { name = "GTBN Target", enableRandomWrite = true });
                TextureHandle blurPingPong = renderGraph.CreateTexture(new TextureDesc(desc) { name = "GTBN Blur PingPong", enableRandomWrite = true });

                using (var builder = renderGraph.AddComputePass<PassData>("Compute GTBN", out var passData))
                {
                    passData.depthTexture = resourceData.activeDepthTexture;
                    passData.normalsTexture = resourceData.gBuffer[2];
                    passData.gtbnTarget = gtbnTarget;
                    passData.blurPingPong = blurPingPong;
                    
                    Matrix4x4 view = cameraData.camera.worldToCameraMatrix;
                    Matrix4x4 proj = cameraData.camera.projectionMatrix;
                    Matrix4x4 invView = cameraData.camera.cameraToWorldMatrix;
                    passData.projScale = 0.5f * cameraData.cameraTargetDescriptor.height * proj.m11;
                    
                    if (passData.depthTexture.IsValid()) builder.UseTexture(passData.depthTexture, AccessFlags.Read);
                    if (passData.normalsTexture.IsValid()) builder.UseTexture(passData.normalsTexture, AccessFlags.Read);
                    
                    builder.UseTexture(passData.gtbnTarget, AccessFlags.ReadWrite);
                    builder.UseTexture(passData.blurPingPong, AccessFlags.ReadWrite);
                    builder.SetGlobalTextureAfterPass(gtbnTarget, GTBNTextureID);
                    builder.AllowGlobalStateModification(true);
                    
                    Matrix4x4 invProj = proj.inverse;
                    Vector3 GetViewRay(float ndcX, float ndcY)
                    {
                        Vector4 viewPos = invProj * new Vector4(ndcX, ndcY, 0.0f, 1.0f);
                        Vector3 ray = new Vector3(viewPos.x, viewPos.y, viewPos.z) / viewPos.w;
                        return ray / -ray.z;
                    }
                    
                    Vector3 bottomLeft = GetViewRay(-1f, -1f);
                    Vector3 bottomRight = GetViewRay(1f, -1f);
                    Vector3 topLeft = GetViewRay(-1f, 1f);

                    passData.bottomLeftCorner = bottomLeft;
                    passData.xExtent = bottomRight - bottomLeft;
                    passData.yExtent = topLeft - bottomLeft;
                    passData.viewMatrix = view;
                    passData.invViewMatrix = invView;
                    passData.useAccurateGBufferNormals = _useAccurateGBufferNormals;
                    
                    builder.SetRenderFunc((PassData data, ComputeGraphContext context) =>
                    {
                        ComputeCommandBuffer cmd = context.cmd;
                        int threadGroupsX = Mathf.CeilToInt(cameraData.cameraTargetDescriptor.width / 8.0f);
                        int threadGroupsY = Mathf.CeilToInt(cameraData.cameraTargetDescriptor.height / 8.0f);
                        
                        cmd.SetComputeMatrixParam(_gtbnCompute, "_ViewMatrix", data.viewMatrix);
                        cmd.SetComputeMatrixParam(_gtbnCompute, "_InvViewMatrix", data.invViewMatrix);
                        
                        cmd.SetComputeVectorParam(_gtbnCompute, "_GTBNParams1", new Vector4(_feature.gtbnRadius, _feature.gtbnMaxRadiusPixels, _feature.gtbnSliceCount, _feature.gtbnStepCount));
                        cmd.SetComputeVectorParam(_gtbnCompute, "_GTBNParams2", new Vector4(_feature.gtbnIntensity, _feature.gtbnThickness, data.projScale, 0));
                        cmd.SetComputeIntParam(_gtbnCompute, GBufferNormalsAreOctID, data.useAccurateGBufferNormals ? 1 : 0);
                        
                        if (data.depthTexture.IsValid()) cmd.SetGlobalTexture("_CameraDepthTexture", data.depthTexture);
                        if (data.normalsTexture.IsValid()) cmd.SetGlobalTexture("_GBuffer2", data.normalsTexture);
                        
                        cmd.SetComputeVectorParam(_gtbnCompute, "_CameraViewBottomLeftCorner", data.bottomLeftCorner);
                        cmd.SetComputeVectorParam(_gtbnCompute, "_CameraViewXExtent", data.xExtent);
                        cmd.SetComputeVectorParam(_gtbnCompute, "_CameraViewYExtent", data.yExtent);
                        cmd.SetComputeTextureParam(_gtbnCompute, _gtbnKernel, "_RW_GTBNTarget", data.gtbnTarget);
                        cmd.DispatchCompute(_gtbnCompute, _gtbnKernel, threadGroupsX, threadGroupsY, 1);

                        cmd.SetComputeFloatParam(_blurCompute, "_BlurRadius", _feature.gtbnBlurRadius);
                        cmd.SetComputeVectorParam(_blurCompute, "_BlurDirection", new Vector2(1, 0));
                        cmd.SetComputeIntParam(_blurCompute, GBufferNormalsAreOctID, data.useAccurateGBufferNormals ? 1 : 0);
                        cmd.SetComputeTextureParam(_blurCompute, _blurHKernel, "_SourceTex", data.gtbnTarget);
                        cmd.SetComputeTextureParam(_blurCompute, _blurHKernel, "_RW_BlurTarget", data.blurPingPong);
                        cmd.DispatchCompute(_blurCompute, _blurHKernel, threadGroupsX, threadGroupsY, 1);

                        cmd.SetComputeVectorParam(_blurCompute, "_BlurDirection", new Vector2(0, 1));
                        cmd.SetComputeTextureParam(_blurCompute, _blurVKernel, "_SourceTex", data.blurPingPong);
                        cmd.SetComputeTextureParam(_blurCompute, _blurVKernel, "_RW_BlurTarget", data.gtbnTarget);
                        cmd.DispatchCompute(_blurCompute, _blurVKernel, threadGroupsX, threadGroupsY, 1);
                    });
                }

                using (var builder = renderGraph.AddRasterRenderPass<ApplyPassData>("Apply GTBN to GBuffer", out var passData))
                {
                    passData.material = _applyMaterial;
                    passData.gtbnSource = gtbnTarget;
                    
                    builder.UseTexture(passData.gtbnSource, AccessFlags.Read);
                    
                    if (resourceData.gBuffer != null && resourceData.gBuffer.Length > 1 && resourceData.gBuffer[1].IsValid())
                        builder.SetRenderAttachment(resourceData.gBuffer[1], 0, AccessFlags.ReadWrite);
                    
                    builder.SetRenderFunc((ApplyPassData data, RasterGraphContext context) =>
                    {
                        if (data.material != null)
                            Blitter.BlitTexture(context.cmd, data.gtbnSource, new Vector4(1,1,0,0), data.material, 0);
                    });
                }
            }
        }

        // =======================================================================
        // NESTED PASS 2: LIGHTING (Executes at BeforeRenderingDeferredLights)
        // =======================================================================
        private class CustomLightingPass : ScriptableRenderPass
        {
            private LoogaLightingFeature _feature;

            private static readonly int[] ShaderGBufferIDs = {
                Shader.PropertyToID("_GBuffer0"), Shader.PropertyToID("_GBuffer1"),
                Shader.PropertyToID("_GBuffer2"), Shader.PropertyToID("_GBuffer3")
            };
            
            private static readonly int CameraDepthTextureID = Shader.PropertyToID("_CameraDepthTexture");
            private static readonly int SSSSProfileTextureID = Shader.PropertyToID("_SSSSProfileTexture");
            private static readonly ShaderTagId SSSSProfileTagId = new ShaderTagId("SSSSProfile");

            public CustomLightingPass(LoogaLightingFeature feature)
            {
                _feature = feature;
                renderPassEvent = RenderPassEvent.BeforeRenderingDeferredLights;
            }

            public void UpdateMaterials(LoogaLightingFeature feature) => _feature = feature;
            
            private class LightingPassData
            {
                public Material material;
                public TextureHandle[] gBuffers;
                public TextureHandle depthTexture, ssssProfileTexture;
            }
            
            private class SSSSPassData { public TextureHandle source; public Material material; public int passIndex; }
            private class DrawProfileData { public RendererListHandle rendererList; }
            private class BlitPassData { public TextureHandle source; }

            public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
            {
                UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
                UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
  
                if (_feature._activeLightingMaterial == null) return;
                
                TextureHandle activeColor = resourceData.activeColorTexture;
                TextureHandle hardwareDepth = resourceData.activeDepthTexture;
                TextureHandle stencilTexture = resourceData.activeDepthTexture;
                
                RenderTextureDescriptor desc = cameraData.cameraTargetDescriptor;
                desc.depthBufferBits = 0;
                
                TextureHandle tempLightingTarget = renderGraph.CreateTexture(new TextureDesc(desc)
                {
                    name = "Looga Lighting Target", enableRandomWrite = true, clearBuffer = true, clearColor = Color.clear
                });

                TextureHandle ssssProfileTarget = TextureHandle.nullHandle;

                if (_feature._ssssMaterial != null && hardwareDepth.IsValid())
                {
                    ssssProfileTarget = renderGraph.CreateTexture(new TextureDesc(desc)
                    {
                        name = "SSSS Profile Target", colorFormat = UnityEngine.Experimental.Rendering.GraphicsFormat.R8G8B8A8_UNorm, clearBuffer = true, clearColor = Color.clear
                    });

                    using (var builder = renderGraph.AddRasterRenderPass<DrawProfileData>("Looga SSSS Profile Draw", out var passData))
                    {
                        builder.SetRenderAttachment(ssssProfileTarget, 0, AccessFlags.Write);
                        builder.SetRenderAttachmentDepth(hardwareDepth, AccessFlags.Read);

                        UniversalRenderingData urpRenderingData = frameData.Get<UniversalRenderingData>();
                        DrawingSettings drawingSettings = new DrawingSettings(SSSSProfileTagId, new SortingSettings(cameraData.camera));
                        FilteringSettings filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

                        passData.rendererList = renderGraph.CreateRendererList(new RendererListParams(urpRenderingData.cullResults, drawingSettings, filteringSettings));
                        builder.UseRendererList(passData.rendererList);

                        builder.SetRenderFunc((DrawProfileData data, RasterGraphContext context) => context.cmd.DrawRendererList(data.rendererList));
                    }
                }

                using (var builder = renderGraph.AddRasterRenderPass<LightingPassData>("Looga Lighting Evaluation", out var passData))
                {
                    passData.material = _feature._activeLightingMaterial;
                    passData.depthTexture = hardwareDepth;
                    passData.ssssProfileTexture = ssssProfileTarget;

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
                    
                    if (passData.depthTexture.IsValid()) builder.UseTexture(passData.depthTexture, AccessFlags.Read);
                    if (passData.ssssProfileTexture.IsValid()) builder.UseTexture(passData.ssssProfileTexture, AccessFlags.Read);

                    builder.SetRenderAttachment(tempLightingTarget, 0, AccessFlags.Write);
                    builder.AllowGlobalStateModification(true);
                    
                    builder.SetRenderFunc((LightingPassData data, RasterGraphContext context) =>
                    {
                        RasterCommandBuffer cmd = context.cmd;
                        if (data.gBuffers != null)
                        {
                            for (int i = 0; i < data.gBuffers.Length; i++)
                                if (data.gBuffers[i].IsValid()) cmd.SetGlobalTexture(ShaderGBufferIDs[i], data.gBuffers[i]);
                        }
                        
                        if (data.depthTexture.IsValid()) cmd.SetGlobalTexture(CameraDepthTextureID, data.depthTexture);
                        if (data.ssssProfileTexture.IsValid()) cmd.SetGlobalTexture(SSSSProfileTextureID, data.ssssProfileTexture);

                        Blitter.BlitTexture(cmd, new Vector4(1,1,0,0), data.material, 0);
                    });
                }

                if (ssssProfileTarget.IsValid())
                {
                    TextureHandle ssssPingPong = renderGraph.CreateTexture(new TextureDesc(desc) { name = "SSSS PingPong Target" });

                    using (var builder = renderGraph.AddRasterRenderPass<SSSSPassData>("Looga SSSS Horizontal", out var passData))
                    {
                        passData.source = tempLightingTarget;
                        passData.material = _feature._ssssMaterial;
                        passData.passIndex = 0;

                        builder.UseTexture(passData.source, AccessFlags.Read);
                        builder.SetRenderAttachment(ssssPingPong, 0, AccessFlags.Write);
                        builder.SetRenderAttachmentDepth(hardwareDepth, AccessFlags.Read);
                        builder.UseTexture(ssssProfileTarget, AccessFlags.Read);
                        builder.AllowGlobalStateModification(true);

                        builder.SetRenderFunc((SSSSPassData data, RasterGraphContext context) =>
                        {
                            context.cmd.SetGlobalTexture(SSSSProfileTextureID, ssssProfileTarget);
                            Blitter.BlitTexture(context.cmd, data.source, new Vector4(1, 1, 0, 0), data.material, data.passIndex);
                        });
                    }

                    using (var builder = renderGraph.AddRasterRenderPass<SSSSPassData>("Looga SSSS Vertical", out var passData))
                    {
                        passData.source = ssssPingPong;
                        passData.material = _feature._ssssMaterial;
                        passData.passIndex = 1;

                        builder.UseTexture(passData.source, AccessFlags.Read);
                        builder.SetRenderAttachment(tempLightingTarget, 0, AccessFlags.Write);
                        builder.SetRenderAttachmentDepth(hardwareDepth, AccessFlags.Read);
                        builder.UseTexture(ssssProfileTarget, AccessFlags.Read);
                        builder.AllowGlobalStateModification(true);

                        builder.SetRenderFunc((SSSSPassData data, RasterGraphContext context) =>
                        {
                            context.cmd.SetGlobalTexture(SSSSProfileTextureID, ssssProfileTarget);
                            Blitter.BlitTexture(context.cmd, data.source, new Vector4(1, 1, 0, 0), data.material, data.passIndex);
                        });
                    }
                }

                using (var builder = renderGraph.AddRasterRenderPass<BlitPassData>("Looga Lighting Blit", out var passData))
                {
                    passData.source = tempLightingTarget;
                    
                    builder.UseTexture(passData.source, AccessFlags.Read);
                    builder.SetRenderAttachment(activeColor, 0, AccessFlags.Write);
                    if (stencilTexture.IsValid()) builder.SetRenderAttachmentDepth(stencilTexture, AccessFlags.Write);
                    
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
