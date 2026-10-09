/* 01-basics.rex: .NET from Rexx in a nutshell.
   .net is the root of .NET's namespaces: going down by name reaches a
   namespace, then a type. A type's messages go to its static members; new
   makes an instance; a message to an instance is a method call, a property
   read or, with "=", a property write. Names are caseless.                */

say "Max:   " .net~System~Math~Max(3, 7)
say "Sqrt:  " .net~System~Math~Sqrt(2)
say "Pi:    " .net~System~Math~PI

-- a type kept in a variable, then used for several things
dt = .net~System~DateTime
d = dt~new(2026, 10, 9, 14, 30, 0)
say "Date:  " d~ToString("yyyy-MM-dd HH:mm") "is a" d~DayOfWeek
say "+100d: " d~AddDays(100)~ToString("dddd, d MMMM yyyy")
say "Days to 2027:" dt~new(2027, 1, 1)~Subtract(d)~Days

-- an object, its properties and methods; method calls chain
sb = .net~System~Text~StringBuilder~new("Hello")
sb~Append(", ")~Append("world")~Append("!")
sb~Capacity = 100
say "Text:  " sb~ToString "(length" sb~Length", capacity" sb~Capacity")"

-- the machine
env = .net~System~Environment
say "OS:    " env~OSVersion~ToString
say "CPUs:  " env~ProcessorCount
say ".NET:  " env~Version~ToString

-- a Guid, a random number, an environment variable
say "Guid:  " .net~System~Guid~NewGuid~ToString
say "Dice:  " .net~System~Random~new~Next(1, 7)
say "PATH has" env~GetEnvironmentVariable("PATH")~countStr(.net~System~IO~Path~PathSeparator) + 1 "entries"

::requires "net.cls"
