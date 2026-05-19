using UnityEngine;

namespace Eden
{

public class BlkTools
{
    private static readonly System.Globalization.CultureInfo Inv = System.Globalization.CultureInfo.InvariantCulture;

    public static string Float(float v) => v.ToString("g6", Inv);

    public static string Vec3(Vector3 v) =>
        $"{Float(v.x)}, {Float(v.y)}, {Float(v.z)}";

    public static string Quat(Quaternion q) =>
        $"{Float(q.x)}, {Float(q.y)}, {Float(q.z)}, {Float(q.w)}";

}

}
