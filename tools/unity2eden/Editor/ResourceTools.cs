using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace Eden
{

public enum AssetFabriqueType : sbyte
{
    Texture = 0,
    DasMesh = 1,
    Material = 2,
    Model = 3,
    Sound = 4,
    Text = 5,
    Font = 6,
    Prefab = 8,
    CubeMap = 9,
    Texture2DArray = 10,
    ShaderGraph = 11,
    DasShader = 12,
    Count,
    Invalid = -1
}

public enum ResourceFabriqueType : sbyte
{
  Invalid = 0,
  Mesh = 1,
  Texture = 2,
  Material = 3,
  Model = 4,
  Sound = 5,
  Animation = 7,
  Skeleton = 8,
  AnimationMask = 9,
  Text = 10,
  Font = 11,
  Prefab = 12,
  Collision = 13,
  UserShader = 14,
  Count
}

public static class ResourceTools
{
    // Unity GUIDs are 32 lowercase hex chars with no dashes.
    // Eden's parse_uuid expects XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (36 chars, 8-4-4-4-12).

    public static string UnityGuidToEdenGuid(string unityGuid) =>
        $"{unityGuid[..8]}-{unityGuid[8..12]}-{unityGuid[12..16]}-{unityGuid[16..20]}-{unityGuid[20..]}";
}

public class MetaAsset
{
    public string path; // Unity asset path (e.g. Assets/Prefabs/Foo.prefab)
    public AssetFabriqueType assetType;
    public DataBlock content = new();

    public MetaAsset(string path, AssetFabriqueType assetType)
    {
        this.path = path;
        this.assetType = assetType;

        var guid = AssetDatabase.AssetPathToGUID(path);
        content.AddString("guid", ResourceTools.UnityGuidToEdenGuid(guid));
        content.AddInt("assetType", (int)assetType);
    }
}

public struct ResourceEntry
{
    public ulong refId;
    public ResourceFabriqueType assetType;
    public string id;
}

public class GlobalPrefabExportContext
{
    public Queue<string> pendingPrefabs = new Queue<string>();
    public HashSet<string> processedPrefabs = new HashSet<string>();
    public HashSet<string> copyAssets = new HashSet<string>();
    public List<MetaAsset> metaAssets = new List<MetaAsset>();
    public Dictionary<string, DataBlock> generatedFiles = new Dictionary<string, DataBlock>(); // unityPath -> content
    public string[] models = AssetDatabase.FindAssets("t:Model");

    public void EnqueuePrefab(string path)
    {
        if (processedPrefabs.Add(path))
            pendingPrefabs.Enqueue(path);
    }

    public void AddGeneratedFile(string unityPath, DataBlock content, AssetFabriqueType assetType)
    {
        generatedFiles[unityPath] = content;
        metaAssets.Add(new MetaAsset(unityPath, assetType));
    }

    public void FlushFiles()
    {
        if (ExportGlobalConfig.IsExportFolderValid())
        {
            foreach (var path in copyAssets)
            {
                var physPath = Path.GetFullPath(path);
                var newPath = FileTools.UnityPathToExportPath(path);
                Debug.Log($"copying {physPath} to {newPath}");
                FileTools.EnsureDir(newPath);
                File.Copy(physPath, newPath, true);
            }
            foreach (var kv in generatedFiles)
                FileTools.WriteTextFile(kv.Key, kv.Value);
            foreach (var asset in metaAssets)
                FileTools.WriteTextFile(asset.path + ".meta", asset.content);
        }
    }
}

public class PrefabExportContext
{
    public GlobalPrefabExportContext globalCtx;
    public System.Random nodeRng = new(0);
    public DataBlock body = new DataBlock();
    public Dictionary<Transform, uint> transformUids = new Dictionary<Transform, uint>();
    public Dictionary<string, ResourceEntry> resources = new Dictionary<string, ResourceEntry>();
    public List<string> resourceOrder = new List<string>();

    public bool TryGetResource(string guid, out ulong refId)
    {
        if (resources.TryGetValue(guid, out var existing))
        {
            refId = existing.refId;
            return true;
        }
        refId = 0;
        return false;
    }

    public ulong RegisterResourceRef(string guid, ResourceFabriqueType assetType, string id = "")
    {
        if (resources.TryGetValue(guid, out var existing))
            return existing.refId;
        var bytes = new byte[guid.Length / 2];
        for (int i = 0; i < bytes.Length; i++)
            bytes[i] = System.Convert.ToByte(guid.Substring(i * 2, 2), 16);
        var refId = ResourceLink.ComputeId(bytes, id, (byte)assetType);
        resources[guid] = new ResourceEntry { refId = refId, assetType = assetType, id = id };
        resourceOrder.Add(guid);
        return refId;
    }

    public ulong RegisterResourceRefByEdenGuid(string edenGuid, ResourceFabriqueType assetType, string id = "")
    {
        var unityGuid = edenGuid.Replace("-", "");
        return RegisterResourceRef(unityGuid, assetType, id);
    }

    private int emittedResCount = 0;

    public void EmitAccumulatedRefLinks()
    {
        for (int i = emittedResCount; i < resourceOrder.Count; i++)
        {
            var guid = resourceOrder[i];
            var entry = resources[guid];
            ResourceLink.Serialize(body, ResourceTools.UnityGuidToEdenGuid(guid), entry.assetType, entry.refId, entry.id);
        }
        emittedResCount = resourceOrder.Count;
    }
}

public static class FileTools
{

    public static string UnityPathToExportPath(string unityPath) =>
        Path.Combine(ExportGlobalConfig.Config.exportFolder, RemapPath(unityPath));

    public static void EnsureDir(string path)
    {
        var dir = Path.GetDirectoryName(path);
        if (!Directory.Exists(dir))
            Directory.CreateDirectory(dir);
    }

    public static void WriteTextFile(string unityPath, DataBlock content)
    {
        if (!string.IsNullOrEmpty(unityPath))
        {
            var path = UnityPathToExportPath(RemapExtension(unityPath));
            EnsureDir(path);
            File.WriteAllText(path, content.ToString());
        }
        else
        {
            Debug.Log(content.ToString());
        }
    }

    public static string RemapExtension(string path)
    {
        if (path.EndsWith(".meta"))
            return RemapExtension(path[..^".meta".Length]) + ".meta";
        return Path.GetExtension(path) switch
        {
            ".mat" => Path.ChangeExtension(path, ".material"),
            ".unity" => Path.ChangeExtension(path, ".prefab"),
            _ => path,
        };
    }

    public static string RemapPath(string path)
    {
        foreach (var remap in ExportGlobalConfig.Config.remapNames)
        {
            if (path.StartsWith(remap.oldName))
            {
                return Path.Combine(remap.newName, path.Substring(remap.oldName.Length));
            }
        }
        return path;
    }
}

// The runtime reconstructs the ResourceId by hashing (guid, name, type) on deserialization,
// so to bake an id at convert-time we need to reproduce the same XXH3-64 digest exactly.
//
// Hash input layout (matches the three streaming updates in the C++ hash functor):
//   bytes 0..15  : guid (16 raw bytes, in uuid[0..15] order)
//   bytes 16..N-2: name UTF-8 bytes (no null terminator)
//   byte  N-1    : type as uint8
public static class ResourceLink
{
    public static void Serialize(DataBlock sb, string edenGuid, ResourceFabriqueType assetType, ulong id, string name = "")
    {
        sb.OpenBlock("res");
        sb.AddString("guid", edenGuid);
        if (!string.IsNullOrEmpty(name))
            sb.AddString("id", name);
        sb.AddInt("type", (int)assetType);
        sb.AddInt64("refId", id);
        sb.CloseBlock(); // res
    }

    public static ulong ComputeId(byte[] guidBytes, string name, byte type)
    {
        var nameBytes = name == null ? System.Array.Empty<byte>() : Encoding.UTF8.GetBytes(name);
        var buf = new byte[16 + nameBytes.Length + 1];
        System.Buffer.BlockCopy(guidBytes, 0, buf, 0, 16);
        System.Buffer.BlockCopy(nameBytes, 0, buf, 16, nameBytes.Length);
        buf[16 + nameBytes.Length] = type;
        return XxHash3.Hash64(buf);
    }
}

}
