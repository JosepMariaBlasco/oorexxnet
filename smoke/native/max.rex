say "System.Math.Max(3, 7) ="    NetStatic("System.Math", "Max", 3, 7)
say "System.Math.Sqrt(2) ="      NetStatic("System.Math", "Sqrt", 2)
say "Environment.ProcessorCount =" NetStatic("System.Environment", "get_ProcessorCount")
say "String.Concat(a, b) ="      NetStatic("System.String", "Concat", "Rexx ", ".NET")
signal on syntax
say NetStatic("System.Math", "NoSuchMethod", 1)
syntax: say "error:" condition("O")~message
::routine NetStatic external "LIBRARY netprobe NetStatic"
