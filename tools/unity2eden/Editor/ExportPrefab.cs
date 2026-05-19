using System;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Eden
{

public enum CollisionDetection : byte
{
  Discrete = 0,
  Continuous = 1,
}


public enum ShapeType : byte
{
    Box = 0,
    Sphere = 1,
    Cylinder = 2, // does not exist in Unity
    Capsule = 3,
    Mesh = 4,
}

public enum MotionType : byte
{
  Dynamic = 0,
  Kinematic = 1,
}

public enum Interpolation : byte
{
  None = 0,
  Interpolate = 1,
  Extrapolate = 2,
}

public class ExportPrefab
{
    static public string EscapeStr(string s)
    {
        if (s == null)
            return s;
        return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "\\r").Replace("\t", "\\t");
    }
    public static uint GenNodeUid(System.Random rng)
    {
        var bytes = new byte[4];
        uint val;
        do
        {
            rng.NextBytes(bytes);
            val = BitConverter.ToUInt32(bytes, 0);
        } while (val == 0);
        return val;
    }

    public static void DoExportPrefab(Transform root, string prefabPath)
    {
        var ctx = new PrefabExportContext { models = AssetDatabase.FindAssets("t:Model"), nodeRng = new System.Random(prefabPath.GetHashCode()) };

        ExportTransform(root, ctx, 0);
        ctx.ExportResLinks();
        ctx.AddGeneratedFile(prefabPath, ctx.body, AssetFabriqueType.Prefab);

        ctx.FlushFiles();
    }

    public static void DoExportScene(Scene scene, string scenePath)
    {
        var ctx = new PrefabExportContext { models = AssetDatabase.FindAssets("t:Model"), nodeRng = new System.Random(scenePath.GetHashCode()) };

        var rootUid = GenNodeUid(ctx.nodeRng);
        var rootName = Path.GetFileNameWithoutExtension(scenePath);
        ctx.body.AppendLine("node{");
        ctx.body.AppendLine($"name:t=\"{EscapeStr(rootName)}\"");
        ctx.body.AppendLine($"uid:i={(int)rootUid}");
        ctx.body.AppendLine("}");

        foreach (var go in scene.GetRootGameObjects())
            ExportTransform(go.transform, ctx, rootUid);

        ctx.ExportResLinks();
        ctx.AddGeneratedFile(scenePath, ctx.body, AssetFabriqueType.Prefab);

        ctx.FlushFiles();
    }

    static bool FindMeshAsset(PrefabExportContext ctx, Mesh mesh, out string path)
    {
        path = null;
        if (mesh == null)
            return false;
        foreach (var guid in ctx.models)
        {
            var assetPath = AssetDatabase.GUIDToAssetPath(guid);
            GameObject model = AssetDatabase.LoadAssetAtPath<GameObject>(assetPath);
            foreach (MeshFilter filter in model.GetComponentsInChildren<MeshFilter>(true))
            {
                if (filter.sharedMesh == mesh)
                {
                    path = assetPath;
                    return true;
                }
            }
        }
        return false;
    }
    static ulong ExportMaterial(Material mat, PrefabExportContext ctx)
    {
        // TODO: more info export
        if (!mat)
            return 0;
        var matAssetPath = AssetDatabase.GetAssetPath(mat);
        if (string.IsNullOrEmpty(matAssetPath) || matAssetPath.StartsWith("Resources/"))
            return 0;
        var matGuid = AssetDatabase.AssetPathToGUID(matAssetPath);
        if (ctx.TryGetResource(matGuid, out var existingId))
            return existingId;

        var c = mat.HasProperty("_Color") ? mat.color : Color.white;
        var matBlk = new StringBuilder();
        matBlk.AppendLine("shader:t=\"mobile_shader\"");
        matBlk.AppendLine("userShader{}");
        matBlk.AppendLine("textures{");
        for (int i = 0; i < 6; i++) matBlk.AppendLine("it{}");
        matBlk.AppendLine("}");
        matBlk.AppendLine("properties{");
        matBlk.AppendLine("color{");
        matBlk.AppendLine("__variant_index:i=1");
        matBlk.AppendLine($"f4:p4={BlkTools.Float(c.r)}, {BlkTools.Float(c.g)}, {BlkTools.Float(c.b)}, {BlkTools.Float(c.a)}");
        matBlk.AppendLine("}");
        var mainTex = mat.HasProperty("_MainTex") ? mat.mainTexture : null;
        if (mainTex)
        {
            var texAssetPath = AssetDatabase.GetAssetPath(mainTex);
            ctx.copyAssets.Add(texAssetPath);
            var texGuid = AssetDatabase.AssetPathToGUID(texAssetPath);
            ctx.RegisterResourceRef(texGuid, ResourceFabriqueType.Texture);
            matBlk.AppendLine("diffuse{");
            matBlk.AppendLine("__variant_index:i=5");
            matBlk.AppendLine($"guid:t=\"{ResourceTools.UnityGuidToEdenGuid(texGuid)}\"");
            matBlk.AppendLine($"type:i={(int)ResourceFabriqueType.Texture}");
            matBlk.AppendLine("}");
        }
        matBlk.AppendLine("}");

        ctx.AddGeneratedFile(matAssetPath, matBlk, AssetFabriqueType.Material);
        return ctx.RegisterResourceRef(matGuid, ResourceFabriqueType.Material);
    }

    public static void ExportTransform(Transform tm, PrefabExportContext ctx, uint parentUid)
    {
        // == MAIN INFO
        var uid = GenNodeUid(ctx.nodeRng);
        ctx.transformUids[tm] = uid;
        ctx.body.AppendLine("node{");
        ctx.body.AppendLine($"name:t=\"{EscapeStr(tm.name)}\"");
        ctx.body.AppendLine($"uid:i={(int)uid}");
        if (parentUid != 0)
            ctx.body.AppendLine($"parent:i={(int)parentUid}");
        if (!tm.gameObject.activeSelf)
            ctx.body.AppendLine("active:b=false");
        var lp = tm.localPosition;
        if (lp != Vector3.zero)
            ctx.body.AppendLine($"pos:p3={BlkTools.Vec3(lp)}");
        var lr = tm.localRotation;
        if (lr != Quaternion.identity)
            ctx.body.AppendLine($"rot:p4={BlkTools.Quat(lr)}");
        var ls = tm.localScale;
        if (ls != Vector3.one)
            ctx.body.AppendLine($"scl:p3={BlkTools.Vec3(ls)}");

        var tag = tm.tag;
        if (tag != "Untagged")
            ctx.body.AppendLine($"Tag{{name:t=\"{tag}\";}}");


        // COLLIDER

        // TODO: query all collider components
        // TODO: walk tree and collect all colliders
        // TODO: support mesh collider
        var friction = -1f;
        var restitution = -1f;
        var isTrigger = false;

        var boxCollider = tm.GetComponent<BoxCollider>();
        if (boxCollider)
        {
            isTrigger = boxCollider.isTrigger;
            if (boxCollider.material)
            {
                friction = boxCollider.material.dynamicFriction;
                restitution = boxCollider.material.bounciness;
            }
        }

        var sphereCollider = tm.GetComponent<SphereCollider>();
        if (sphereCollider)
        {
            isTrigger = sphereCollider.isTrigger;
            if (sphereCollider.material)
            {
                friction = sphereCollider.material.dynamicFriction;
                restitution = sphereCollider.material.bounciness;
            }
        }

        var capsuleCollider = tm.GetComponent<CapsuleCollider>();
        if (capsuleCollider)
        {
            isTrigger = capsuleCollider.isTrigger;
            if (capsuleCollider.material)
            {
                friction = capsuleCollider.material.dynamicFriction;
                restitution = capsuleCollider.material.bounciness;
            }
        }

        if (boxCollider || sphereCollider || capsuleCollider)
        {
            ctx.body.AppendLine("Collider{");
            ctx.body.AppendLine($"friction:r={BlkTools.Float(friction)}");
            ctx.body.AppendLine($"restitution:r={BlkTools.Float(restitution)}");
            ctx.body.AppendLine($"isSensor:b={(isTrigger ? "yes" : "no")}");
            ctx.body.AppendLine("collisionLayer:i=0");
            ctx.body.AppendLine("shapes{");

            void EmitShape(int shapeType, Vector3 translation, Vector3 shapeParams, Quaternion rotation)
            {
                ctx.body.AppendLine("shape{");
                ctx.body.AppendLine($"shapeType:i={shapeType}");
                ctx.body.AppendLine($"translation:p3={BlkTools.Vec3(translation)}");
                ctx.body.AppendLine($"rotation:p4={BlkTools.Quat(rotation)}");
                ctx.body.AppendLine($"params:p3={BlkTools.Vec3(shapeParams)}");
                ctx.body.AppendLine($"__mesh:i64=0");
                ctx.body.AppendLine("}");
            }

            if (boxCollider)
                EmitShape((int)ShapeType.Box,
                    boxCollider.center,
                    boxCollider.size,
                    Quaternion.identity);

            if (sphereCollider)
                EmitShape((int)ShapeType.Sphere,
                    sphereCollider.center,
                    new Vector3(sphereCollider.radius, sphereCollider.radius, sphereCollider.radius),
                    Quaternion.identity);

            if (capsuleCollider)
                EmitShape((int)ShapeType.Capsule,
                    capsuleCollider.center,
                    new Vector3(capsuleCollider.height, capsuleCollider.radius, capsuleCollider.direction),
                    Quaternion.identity);

            ctx.body.AppendLine("}"); // shapes
            ctx.body.AppendLine("}"); // Collider
        }

        var rigidBody = tm.GetComponent<Rigidbody>();
        if (rigidBody)
        {
            ctx.body.AppendLine("RigidBody{");
            ctx.body.AppendLine("enabled:b=yes");
            ctx.body.AppendLine($"mass:r={BlkTools.Float(rigidBody.mass)}");
            ctx.body.AppendLine($"linearDamping:r={BlkTools.Float(rigidBody.linearDamping)}");
            ctx.body.AppendLine($"angularDamping:r={BlkTools.Float(rigidBody.angularDamping)}");
            var useGravity = rigidBody.useGravity ? "yes" : "no";
            ctx.body.AppendLine($"useGravity:b={useGravity}");
            var motionType = rigidBody.isKinematic ? MotionType.Kinematic : MotionType.Dynamic;
            ctx.body.AppendLine($"motionType:i={(int)motionType}");
            var collisionMode = rigidBody.collisionDetectionMode == CollisionDetectionMode.Discrete ? CollisionDetection.Discrete : CollisionDetection.Continuous;
            ctx.body.AppendLine($"collisionDetection:i={(int)collisionMode}");
            var c = rigidBody.constraints;
            int dofs = 0;
            if ((c & RigidbodyConstraints.FreezePositionX) == 0) dofs |= 1;  // AllowTranslationX
            if ((c & RigidbodyConstraints.FreezePositionY) == 0) dofs |= 2;  // AllowTranslationY
            if ((c & RigidbodyConstraints.FreezePositionZ) == 0) dofs |= 4;  // AllowTranslationZ
            if ((c & RigidbodyConstraints.FreezeRotationX) == 0) dofs |= 8;  // AllowRotationX
            if ((c & RigidbodyConstraints.FreezeRotationY) == 0) dofs |= 16; // AllowRotationY
            if ((c & RigidbodyConstraints.FreezeRotationZ) == 0) dofs |= 32; // AllowRotationZ
            ctx.body.AppendLine($"allowedDofs:i={dofs}");
            ctx.body.AppendLine($"maxVelocity:r={BlkTools.Float(rigidBody.maxLinearVelocity)}");
            ctx.body.AppendLine($"maxAngularVelocity:r={BlkTools.Float(rigidBody.maxAngularVelocity)}");
            var interpolation = rigidBody.interpolation switch
            {
                RigidbodyInterpolation.None        => Interpolation.None,
                RigidbodyInterpolation.Interpolate => Interpolation.Interpolate,
                RigidbodyInterpolation.Extrapolate => Interpolation.Extrapolate,
                _                                  => Interpolation.None,
            };
            ctx.body.AppendLine($"interpolation:i={(int)interpolation}");
            ctx.body.AppendLine("}"); // RigidBody

        }


        // MESH
        var renderer = tm.GetComponent<MeshRenderer>();
        var mesh = tm.GetComponent<MeshFilter>();
        if (renderer && mesh)
        {
            int RendererVisibility(MeshRenderer r)
            {
                const int AllCameras            = 0x00FF; // Camera0..Camera7
                const int EditorCamera          = 1 << 8;
                const int CastShadowsFromSun    = 1 << 9;
                const int CastShadowsFromLights = 1 << 10;

                return r.shadowCastingMode switch
                {
                    ShadowCastingMode.Off         => AllCameras | EditorCamera,
                    ShadowCastingMode.ShadowsOnly => CastShadowsFromSun | CastShadowsFromLights,
                    _                             => AllCameras | EditorCamera | CastShadowsFromSun | CastShadowsFromLights,
                };
            }

            var meshData = mesh.sharedMesh;
            ulong meshId = 0;
            if (FindMeshAsset(ctx, meshData, out var path))
            {
                ctx.copyAssets.Add(path);

                var guid = AssetDatabase.AssetPathToGUID(path);
                meshId = ctx.RegisterResourceRef(guid, ResourceFabriqueType.Mesh, meshData.name);

                var meshMeta = new MetaAsset(path, AssetFabriqueType.Model);
                meshMeta.content.AppendLine($"sceneScale:r=1");
                ctx.metaAssets.Add(meshMeta);
            }
            else if (meshData != null)
            {
                switch (meshData.name)
                {
                    case "Cube":
                        meshId = ctx.RegisterResourceRefByEdenGuid("0193c180-91e6-7806-87dd-19e8d41cd80f", ResourceFabriqueType.Mesh);
                        break;
                    default:
                        break;
                }
            }

            var materialId = ExportMaterial(renderer.sharedMaterial, ctx);

            ctx.body.AppendLine("Mesh{");
            ctx.body.AppendLine($"__meshId:i64={meshId}");
            ctx.body.AppendLine($"__materialId:i64={materialId}");
            ctx.body.AppendLine($"visibility:i={RendererVisibility(renderer)}");
            ctx.body.AppendLine("isStatic:b=no");
            ctx.body.AppendLine("}"); // Mesh
        }

        ctx.body.AppendLine("}"); // node

        foreach (Transform child in tm)
        {
            ExportTransform(child, ctx, uid);
        }
    }
}

}
