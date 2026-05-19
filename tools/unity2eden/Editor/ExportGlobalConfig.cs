using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace Eden
{

[Serializable]
public struct GlobalRemapName
{
    public string oldName;
    public string newName;
}

[FilePath("ProjectSettings/Packages/com.gaijin.edenspark-converter/Settings.asset", FilePathAttribute.Location.ProjectFolder)]
public class ExportGlobalConfig : ScriptableSingleton<ExportGlobalConfig>
{
    private const string MainDasTemplate = @"require engine.core

class Tag : Component {
    name : string
}
";

    [SerializeField]
    public List<GlobalRemapName> remapNames = new List<GlobalRemapName>()
    {
        new GlobalRemapName() {oldName="Assets/", newName="assets/"},
        new GlobalRemapName() {oldName="Packages/", newName="packages/"},
    };

    [SerializeField]
    public string exportFolder;

    public static ExportGlobalConfig Config => instance;

    public void SaveConfig() => Save(true);

    public static bool IsExportFolderValid() =>
        !string.IsNullOrEmpty(Config.exportFolder) && Directory.Exists(Config.exportFolder);

    public static void RevealExportFolder()
    {
        if (!EnsureExportFolderConfigured())
            return;
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = Config.exportFolder,
            UseShellExecute = true,
        });
    }

    public static bool EnsureExportFolderConfigured()
    {
        var folder = Config.exportFolder;
        string message;
        if (string.IsNullOrEmpty(folder))
            message = "Export folder is not set.\n\nConfigure it under Edit -> Project Settings -> EdenSpark Converter.";
        else if (!Directory.Exists(folder))
            message = $"Export folder does not exist:\n{folder}\n\nFix it under Edit -> Project Settings -> EdenSpark Converter.";
        else
            return true;
        if (EditorUtility.DisplayDialog("Eden Export", message, "Open Settings", "Cancel"))
            SettingsService.OpenProjectSettings("Project/EdenSpark Converter");
        return false;
    }

    [SettingsProvider]
    private static SettingsProvider CreateSettingsProvider()
    {
        return new SettingsProvider("Project/EdenSpark Converter", SettingsScope.Project)
        {
            label = "EdenSpark Converter",
            guiHandler = _ => DrawSettingsGui(),
            keywords = new HashSet<string> { "eden", "edenspark", "export", "converter", "daslang", "remap" },
        };
    }

    private static void DrawSettingsGui()
    {
        var cfg = Config;

        EditorGUI.BeginChangeCheck();

        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("Export folder", GUILayout.Width(100));
        cfg.exportFolder = EditorGUILayout.TextField(cfg.exportFolder ?? "");
        if (GUILayout.Button("Browse...", GUILayout.Width(80)))
        {
            var picked = EditorUtility.OpenFolderPanel("Pick export folder", cfg.exportFolder ?? "", "");
            if (!string.IsNullOrEmpty(picked))
            {
                cfg.exportFolder = picked;
                GUI.FocusControl(null);
                GUI.changed = true;
            }
        }
        using (new EditorGUI.DisabledScope(!IsExportFolderValid()))
        {
            if (GUILayout.Button("Open", GUILayout.Width(60)))
                RevealExportFolder();
        }
        EditorGUILayout.EndHorizontal();

        if (string.IsNullOrEmpty(cfg.exportFolder))
            EditorGUILayout.HelpBox("Export folder is required for exports to work.", MessageType.Warning);
        else if (!Directory.Exists(cfg.exportFolder))
            EditorGUILayout.HelpBox($"Export folder does not exist: {cfg.exportFolder}", MessageType.Error);
        else
            EditorGUILayout.HelpBox("Export folder valid.", MessageType.Info);

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Path remaps (Unity prefix -> Eden prefix)", EditorStyles.boldLabel);

        cfg.remapNames ??= new();
        int removeIdx = -1;
        for (int i = 0; i < cfg.remapNames.Count; ++i)
        {
            EditorGUILayout.BeginHorizontal();
            var entry = cfg.remapNames[i];
            entry.oldName = EditorGUILayout.TextField(entry.oldName);
            EditorGUILayout.LabelField("->", GUILayout.Width(24));
            entry.newName = EditorGUILayout.TextField(entry.newName);
            cfg.remapNames[i] = entry;
            if (GUILayout.Button("-", GUILayout.Width(24)))
                removeIdx = i;
            EditorGUILayout.EndHorizontal();
        }
        if (removeIdx >= 0)
            cfg.remapNames.RemoveAt(removeIdx);
        if (GUILayout.Button("+ Add remap", GUILayout.Width(120)))
        {
            cfg.remapNames.Add(new GlobalRemapName());
            GUI.changed = true;
        }

        if (EditorGUI.EndChangeCheck())
            cfg.SaveConfig();

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Project bootstrap", EditorStyles.boldLabel);
        using (new EditorGUI.DisabledScope(!IsExportFolderValid()))
        {
            if (GUILayout.Button("Create main.das in export folder", GUILayout.Width(260)))
                CreateMainDas(cfg.exportFolder);
        }
    }

    private static void CreateMainDas(string folder)
    {
        var path = Path.Combine(folder, "main.das");
        if (File.Exists(path))
        {
            if (!EditorUtility.DisplayDialog(
                    "Create main.das",
                    $"{path} already exists.\n\nOverwrite?",
                    "Overwrite",
                    "Cancel"))
                return;
        }
        Directory.CreateDirectory(folder);
        File.WriteAllText(path, MainDasTemplate);
        Debug.Log($"Created {path}");
    }
}

}
