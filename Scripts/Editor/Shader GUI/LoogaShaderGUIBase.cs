using UnityEditor;
using UnityEngine;

namespace LoogaSoft.LightingPrime.Editor
{
    public abstract class LoogaShaderGUIBase : ShaderGUI
    {
        protected static GUIStyle _header, _box;

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