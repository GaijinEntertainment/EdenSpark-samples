using System.Collections.Generic;
using System.Text;
using UnityEngine;

namespace Eden
{

public class DataBlock
{
    private static readonly System.Globalization.CultureInfo Inv = System.Globalization.CultureInfo.InvariantCulture;

    public static string Float(float v) => v.ToString("g6", Inv);
    public static string Vec3(Vector3 v) => $"{Float(v.x)}, {Float(v.y)}, {Float(v.z)}";
    public static string Quat(Quaternion q) => $"{Float(q.x)}, {Float(q.y)}, {Float(q.z)}, {Float(q.w)}";

    public static string EscapeStr(string s)
    {
        if (s == null)
            return s;
        return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "\\r").Replace("\t", "\\t");
    }

    private class Frame
    {
        public StringBuilder buf = new StringBuilder();
        public int count = 0;
        public string name;
    }

    private Stack<Frame> frames = new Stack<Frame>();

    public DataBlock()
    {
        frames.Push(new Frame());
    }

    public void OpenBlock(string name) => frames.Push(new Frame { name = name });

    public void CloseBlock()
    {
        var child = frames.Pop();
        var parent = frames.Peek();
        if (child.count == 0)
        {
            parent.buf.AppendLine($"{child.name}{{}}");
        }
        else if (child.count == 1)
        {
            var line = child.buf.ToString().TrimEnd();
            if (line.Contains('\n'))
            {
                parent.buf.AppendLine($"{child.name}{{");
                parent.buf.Append(child.buf);
                parent.buf.AppendLine("}");
            }
            else
            {
                parent.buf.AppendLine($"{child.name}{{{line};}}");
            }
        }
        else
        {
            parent.buf.AppendLine($"{child.name}{{");
            parent.buf.Append(child.buf);
            parent.buf.AppendLine("}");
        }
        parent.count++;
    }

    private void AddRaw(string line)
    {
        var top = frames.Peek();
        top.buf.AppendLine(line);
        top.count++;
    }

    public void AddInt(string name, int value) => AddRaw($"{name}:i={value}");
    public void AddInt64(string name, ulong value) => AddRaw($"{name}:i64={value}");
    public void AddFloat(string name, float value) => AddRaw($"{name}:r={Float(value)}");
    public void AddBool(string name, bool value) => AddRaw($"{name}:b={(value ? "yes" : "no")}");
    public void AddString(string name, string value) => AddRaw($"{name}:t=\"{EscapeStr(value)}\"");
    public void AddVec3(string name, Vector3 v) => AddRaw($"{name}:p3={Vec3(v)}");
    public void AddQuat(string name, Quaternion q) => AddRaw($"{name}:p4={Quat(q)}");
    public void AddColor(string name, Color c) => AddRaw($"{name}:p4={Float(c.r)}, {Float(c.g)}, {Float(c.b)}, {Float(c.a)}");

    public override string ToString() => frames.Peek().buf.ToString();
}

}
