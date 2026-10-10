// For tests/extend.rex: classes and interfaces for Rexx classes to extend.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace RexxNetTests;

/// An abstract class with a virtual call in its constructor and protected
/// members of every kind.
public abstract class Shape
{
    protected Shape(string name) { Name = name; Created = Describe(); }
    protected Shape() : this("shape") { }
    public string Name { get; }
    public string Created { get; }                      // Describe() as the constructor saw it
    public abstract double Area();
    public virtual string Describe() => $"{Name}: {Area()}";
    public string Report() => Describe();
    public int SidesSeen => Sides;
    public string Greet(string who) => Hello(who);

    protected int secret = 42;
    protected static string Kind = "shape";
    protected readonly string fixedName = "fixed";
    protected string Hidden() => "hidden " + Name;
    protected string Hidden(int n) => "hidden " + n;
    protected virtual int Sides => 0;
    protected virtual string Hello(string who) => "hello " + who;
    protected string Label { get; set; } = "none";
}

public interface IValue
{
    int Value { get; set; }
    string Describe(string prefix);
}

public interface ICounter : IValue
{
    int Next();
}

public static class ExtendProbe
{
    public static double TotalArea(IEnumerable<Shape> shapes) => shapes.Sum(s => s.Area());
    public static object Same(object o) => o;
    public static string OnAnotherThread(Shape s) => Task.Run(() => s.Describe()).Result;
    public static string UseValue(IValue v)
    {
        v.Value = v.Value + 10;
        return v.Describe("v=") + " " + v.Value;
    }
    public static string Count(ICounter c) => $"{c.Next()} {c.Next()} {((IValue)c).Value}";
    public static string Fail(Shape s)
    {
        try { return s.Report(); }
        catch (Exception e) { return e.GetType().Name; }
    }
}
