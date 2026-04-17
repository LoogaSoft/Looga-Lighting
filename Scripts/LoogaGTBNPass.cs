using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace LoogaSoft.Lighting 
{
    public class LoogaGTBNPass : ScriptableRenderPass
    {
        private ComputeShader _gtbnCompute;
        private ComputeShader _blurCompute;
        private Material _applyMaterial;
        private LoogaGTBNFeature _feature;
        
        private int _gtbnKernel, _blurHKernel, _blurVKernel;
        private static readonly int GTBNTextureID = Shader.PropertyToID("_GTBNTexture");

        public LoogaGTBNPass()
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingDeferredLights - 1;
        }

        public void Setup(ComputeShader gtbnCompute, ComputeShader blurCompute, Material applyMaterial, LoogaGTBNFeature feature)
        {
            _gtbnCompute = gtbnCompute;
            _blurCompute = blurCompute;
            _applyMaterial = applyMaterial;
            _feature = feature;
            
            if (_gtbnCompute != null)
                _gtbnKernel = _gtbnCompute.FindKernel("CSMain");
            if (_blurCompute != null)
            {
                _blurHKernel = _blurCompute.FindKernel("BlurHorizontal");
                _blurVKernel = _blurCompute.FindKernel("BlurVertical");
            }
        }

        private class PassData
        {
            public TextureHandle depthTexture;
            public TextureHandle normalsTexture;
            public TextureHandle gtbnTarget;
            public TextureHandle blurPingPong;

            public Vector4 bottomLeftCorner, xExtent, yExtent;
            public Matrix4x4 viewMatrix, invViewMatrix;

            public float projScale;
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
                
                if (passData.depthTexture.IsValid())
                    builder.UseTexture(passData.depthTexture, AccessFlags.Read);
                if (passData.normalsTexture.IsValid())
                    builder.UseTexture(passData.normalsTexture, AccessFlags.Read);
                
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
                
                builder.SetRenderFunc((PassData data, ComputeGraphContext context) =>
                {
                    ComputeCommandBuffer cmd = context.cmd;
                    
                    int threadGroupsX = Mathf.CeilToInt(cameraData.cameraTargetDescriptor.width / 8.0f);
                    int threadGroupsY = Mathf.CeilToInt(cameraData.cameraTargetDescriptor.height / 8.0f);
                    
                    cmd.SetComputeMatrixParam(_gtbnCompute, "_ViewMatrix", data.viewMatrix);
                    cmd.SetComputeMatrixParam(_gtbnCompute, "_InvViewMatrix", data.invViewMatrix);
                    
                    cmd.SetComputeVectorParam(_gtbnCompute, "_GTBNParams1", new Vector4(_feature.radius, _feature.maxRadiusPixels, _feature.sliceCount, _feature.stepCount));
                    cmd.SetComputeVectorParam(_gtbnCompute, "_GTBNParams2", new Vector4(_feature.intensity, _feature.thickness, data.projScale, 0));
                    
                    if (data.depthTexture.IsValid()) cmd.SetGlobalTexture("_CameraDepthTexture", data.depthTexture);
                    if (data.normalsTexture.IsValid()) cmd.SetGlobalTexture("_GBuffer2", data.normalsTexture);
                    
                    cmd.SetComputeVectorParam(_gtbnCompute, "_CameraViewBottomLeftCorner", data.bottomLeftCorner);
                    cmd.SetComputeVectorParam(_gtbnCompute, "_CameraViewXExtent", data.xExtent);
                    cmd.SetComputeVectorParam(_gtbnCompute, "_CameraViewYExtent", data.yExtent);
                    cmd.SetComputeTextureParam(_gtbnCompute, _gtbnKernel, "_RW_GTBNTarget", data.gtbnTarget);
                    cmd.DispatchCompute(_gtbnCompute, _gtbnKernel, threadGroupsX, threadGroupsY, 1);

                    cmd.SetComputeFloatParam(_blurCompute, "_BlurRadius", _feature.blurRadius);
                    cmd.SetComputeVectorParam(_blurCompute, "_BlurDirection", new Vector2(1, 0));
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
}