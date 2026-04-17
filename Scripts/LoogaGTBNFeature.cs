using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace LoogaSoft.Lighting
{
    [DisallowMultipleRendererFeature("Looga GTBN")]
    public class LoogaGTBNFeature : ScriptableRendererFeature
    {
        [Range(0.1f, 1.0f)] public float radius = 0.3f;
        [Range(10f, 150f)] public float maxRadiusPixels = 100f;
        [Range(0.01f, 0.5f)] public float thickness = 0.2f;
        [Range(0.0f, 3.0f)] public float intensity = 1f;
        [Range(1, 8)] public int sliceCount = 3;
        [Range(2, 16)] public int stepCount = 8;
        [Range(0.0f, 1.0f)] public float directLightStrength = 0.5f;
        [Range(0, 4)] public int blurRadius = 2;

        [HideInInspector] public ComputeShader gtbnCompute;
        [HideInInspector] public ComputeShader gtbnBlurCompute;
        [HideInInspector] public Shader gtbnApplyShader;

        private Material _gtbnApplyMaterial;
        private LoogaGTBNPass _gtbnPass;

        #if UNITY_EDITOR
        private void OnValidate()
        {
            bool needsSave = false;

            if (gtbnCompute == null)
                AssignCompute(ref gtbnCompute, "LoogaGTBN", ref needsSave);
            
            if (gtbnBlurCompute == null)
                AssignCompute(ref gtbnBlurCompute, "LoogaGTBNBlur", ref needsSave);

            if (gtbnApplyShader == null)
            {
                gtbnApplyShader = Shader.Find("Hidden/LoogaSoft/ApplyGTBN");
                if (gtbnApplyShader != null) needsSave = true;
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
            if (gtbnApplyShader == null)
                gtbnApplyShader = Shader.Find("Hidden/LoogaSoft/ApplyGTBN");
            
            if (gtbnApplyShader != null && _gtbnApplyMaterial == null)
                _gtbnApplyMaterial = CoreUtils.CreateEngineMaterial(gtbnApplyShader);
                
            if (_gtbnPass == null)
                _gtbnPass = new LoogaGTBNPass();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            // We now strictly respect the built-in active state of the renderer feature
            if (!isActive || (renderingData.cameraData.cameraType != CameraType.Game && renderingData.cameraData.cameraType != CameraType.SceneView))
                return;

            if (gtbnCompute != null && gtbnBlurCompute != null)
            {
                Shader.EnableKeyword("_USE_GTBN");
                Shader.SetGlobalFloat("_GTBNDirectLightStrength", directLightStrength);
                
                _gtbnPass.Setup(gtbnCompute, gtbnBlurCompute, _gtbnApplyMaterial, this);
                renderer.EnqueuePass(_gtbnPass);
            }
            else
            {
                Shader.DisableKeyword("_USE_GTBN");
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (_gtbnApplyMaterial != null)
            {
                CoreUtils.Destroy(_gtbnApplyMaterial);
                _gtbnApplyMaterial = null;
            }
            
            _gtbnPass = null;
            base.Dispose(disposing);
        }
    }
}