using UnityEditor;
using UnityEngine;

namespace LoogaSoft.LightingPrime.Editor
{
    public abstract class LoogaShaderGUIBase : ShaderGUI
    {
        protected static GUIStyle _header, _box;
        private static readonly GUIContent[] RenderFaceLabels =
        {
            new GUIContent("Front"),
            new GUIContent("Back"),
            new GUIContent("Both")
        };
        private static readonly float[] RenderFaceValues = { 2.0f, 1.0f, 0.0f };

        protected static void Styles()
        {
            if (_header != null) return;
            _header = new GUIStyle(EditorStyles.boldLabel) { fontSize = 13, padding = new RectOffset(0, 0, 0, 4) };
            _box = new GUIStyle("HelpBox") { padding = new RectOffset(8, 8, 6, 6) };
        }

        protected void DrawLoogaSoftHeader()
        {
            GUIStyle titleStyle = new GUIStyle()
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = 12,
                normal = { textColor = new Color(0.5f, 0.5f, 0.5f) }
            };
            
            EditorGUILayout.Space(3);
            GUILayout.Label("-  LoogaSoft  -", titleStyle);
            EditorGUILayout.Space(3);
        }

        protected void Section(string title, string prefKey, bool defaultShow, System.Action content)
        {
            bool show = EditorPrefs.GetBool(prefKey, defaultShow);

            EditorGUILayout.BeginVertical(_box);
            Rect full = GUILayoutUtility.GetRect(GUIContent.none, _header);
            full.height += 4f; full.y -= 2f; full.width += 8f; full.x -= 4f;
            Rect text  = new Rect(full.x + 4, full.y + 1, full.width - 24, full.height);
            Rect arrow = new Rect(full.xMax - 10, full.y, 15, full.height);
            
            if (full.Contains(Event.current.mousePosition)) EditorGUI.DrawRect(full, new Color(1, 1, 1, 0.05f));
            GUI.Label(text, title, _header);
            
            bool newShow = EditorGUI.Foldout(arrow, show, GUIContent.none);
            if (Event.current.type == EventType.MouseDown && full.Contains(Event.current.mousePosition) && Event.current.button == 0)
            { 
                newShow = !show; 
                Event.current.Use(); 
            }
            
            if (newShow != show)
            {
                EditorPrefs.SetBool(prefKey, newShow);
                show = newShow;
            }
            
            if (show)
            {
                EditorGUILayout.Space(2);
                content();
                EditorGUILayout.Space(2);
            }
            EditorGUILayout.EndVertical();
        }

        protected void DrawEmissionToggle(MaterialEditor materialEditor, MaterialProperty emissionMap, MaterialProperty emissionColor, string keyword, string mapLabel)
        {
            bool enabled = ShouldEnableEmissionFromExistingMaterial(materialEditor, keyword);
            EditorGUI.BeginChangeCheck();
            enabled = EditorGUILayout.Toggle("Emission", enabled);
            if (EditorGUI.EndChangeCheck())
            {
                SetKeyword(materialEditor, keyword, enabled);
            }

            if (enabled)
            {
                EditorGUI.indentLevel += 1;
                materialEditor.TexturePropertySingleLine(new GUIContent(mapLabel), emissionMap, emissionColor);
                EditorGUI.indentLevel -= 1;
            }
        }

        protected void DrawSurfaceOptionsSection(MaterialEditor materialEditor, MaterialProperty[] properties, string prefKey)
        {
            MaterialProperty workflowMode = FindProperty("_WorkflowMode", properties, false);
            MaterialProperty surface = FindProperty("_Surface", properties, false);
            MaterialProperty cull = FindProperty("_Cull", properties, false);
            MaterialProperty alphaClip = FindProperty("_AlphaClip", properties, false);
            MaterialProperty cutoff = FindProperty("_Cutoff", properties, false);
            MaterialProperty receiveShadows = FindProperty("_ReceiveShadows", properties, false);
            MaterialProperty backfaceNormalMode = FindProperty("_BackfaceNormalMode", properties, false);

            Section("Surface Options", prefKey, true, () =>
            {
                if (workflowMode != null) materialEditor.ShaderProperty(workflowMode, "Workflow Mode");
                if (surface != null) materialEditor.ShaderProperty(surface, "Surface Type");
                if (cull != null) DrawRenderFaceProperty(cull);

                if (cull != null && backfaceNormalMode != null && !cull.hasMixedValue && Mathf.Approximately(cull.floatValue, 0.0f))
                {
                    EditorGUI.indentLevel += 1;
                    materialEditor.ShaderProperty(backfaceNormalMode, "Backface Normals");
                    EditorGUI.indentLevel -= 1;
                }

                if (alphaClip != null) materialEditor.ShaderProperty(alphaClip, "Alpha Clipping");
                if (alphaClip != null && cutoff != null && (alphaClip.hasMixedValue || alphaClip.floatValue > 0.5f))
                {
                    EditorGUI.indentLevel += 1;
                    materialEditor.ShaderProperty(cutoff, "Threshold");
                    EditorGUI.indentLevel -= 1;
                }

                if (receiveShadows != null) materialEditor.ShaderProperty(receiveShadows, "Receive Shadows");
            });
        }

        private static void DrawRenderFaceProperty(MaterialProperty cull)
        {
            EditorGUI.showMixedValue = cull.hasMixedValue;
            int selected = 0;
            if (!cull.hasMixedValue)
            {
                selected = Mathf.Approximately(cull.floatValue, 1.0f) ? 1 : Mathf.Approximately(cull.floatValue, 0.0f) ? 2 : 0;
            }

            Rect rect = EditorGUILayout.GetControlRect();
            EditorGUI.BeginChangeCheck();
            selected = EditorGUI.Popup(rect, new GUIContent("Render Face"), selected, RenderFaceLabels);
            if (EditorGUI.EndChangeCheck())
            {
                cull.floatValue = RenderFaceValues[selected];
            }
            EditorGUI.showMixedValue = false;
        }

        private static bool ShouldEnableEmissionFromExistingMaterial(MaterialEditor materialEditor, string keyword)
        {
            foreach (Object target in materialEditor.targets)
            {
                if (target is not Material material)
                    continue;

                if (material.IsKeywordEnabled(keyword))
                    return true;

            }

            return false;
        }

        private static void SetKeyword(MaterialEditor materialEditor, string keyword, bool enabled)
        {
            foreach (Object target in materialEditor.targets)
            {
                if (target is not Material material)
                    continue;

                if (enabled)
                    material.EnableKeyword(keyword);
                else
                    material.DisableKeyword(keyword);
            }
        }

        protected void DrawMinMaxSlider(MaterialProperty prop, string label, float minLimit, float maxLimit)
        {
            Vector4 vec = prop.vectorValue;
            float minVal = vec.x;
            float maxVal = vec.y;

            Rect rect = EditorGUILayout.GetControlRect();
            Rect labelRect = new Rect(rect.x, rect.y, EditorGUIUtility.labelWidth, rect.height);
            
            float fieldWidth = 45f;
            float spacing = 4f;
            
            Rect minFieldRect = new Rect(labelRect.xMax, rect.y, fieldWidth, rect.height);
            float sliderWidth = rect.width - EditorGUIUtility.labelWidth - (fieldWidth * 2) - (spacing * 2);
            Rect sliderRect = new Rect(minFieldRect.xMax + spacing, rect.y, sliderWidth, rect.height);
            Rect maxFieldRect = new Rect(sliderRect.xMax + spacing, rect.y, fieldWidth, rect.height);

            EditorGUI.LabelField(labelRect, new GUIContent(label));

            EditorGUI.BeginChangeCheck();
            
            minVal = EditorGUI.FloatField(minFieldRect, (float)System.Math.Round(minVal, 3));
            EditorGUI.MinMaxSlider(sliderRect, ref minVal, ref maxVal, minLimit, maxLimit);
            maxVal = EditorGUI.FloatField(maxFieldRect, (float)System.Math.Round(maxVal, 3));

            if (EditorGUI.EndChangeCheck())
            {
                minVal = Mathf.Clamp(minVal, minLimit, maxVal);
                maxVal = Mathf.Clamp(maxVal, minVal, maxLimit);
                vec.x = minVal;
                vec.y = maxVal;
                prop.vectorValue = vec;
            }
        }
    }
}
