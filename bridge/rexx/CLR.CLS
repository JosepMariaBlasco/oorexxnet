/*----------------------------------------------------------------------------*/
/* ooRexx/.NET: a CLR.CLS compatibility package on top of net.cls.            */
/* Design: notes/clr-compat.md (ooRexx/.NET project).                         */
/*----------------------------------------------------------------------------*/
/*
 * Programs written for BSF4ooRexx's CLR.CLS (ooRexx.NET, through Java and
 * jni4net) run on this bridge with their ::REQUIRES CLR.CLS unchanged:
 *
 *    console = clr.import("System.Console")
 *    console~WriteLine("Hello World")
 *    file = .clr~new("System.IO.StreamWriter", "out.txt")
 *    file~WriteLine("a line"); file~Close
 *    ::requires CLR.CLS
 *
 * The public interface of CLR.CLS: the class CLR (.clr~new(typeName,
 * args...), .clr~clr.import(typeName [, name4local]), o~clr.dispatch(name,
 * args...), o~clr.object, o~clr.type), the routines clr.import,
 * clr.createEventHandler, clr.createArray, clr.wrap, clr.box, clr.unbox,
 * clr.addAssembly, the classes CLRThread and CLRLogger, and BSF.CLS's pp().
 *
 * What CLR.CLS did that net.cls alone does not, and this package does for
 * the objects it makes (.clr~new, clr.import, and every .NET object they
 * return):
 *   - a whole number argument goes as an Int32 (an Int64 past its range), as
 *     clr.wrap made it; other arguments convert as net.cls converts them;
 *   - a message to an object looks at its instance and static members
 *     together, as CLR.CLS did (.clr~new("System.DateTime")~Now,
 *     process~clr.dispatch("Start", file) for the static Process.Start); a
 *     message to an imported type that names no static member reaches the
 *     members of the System.Type object (clr.import("System.String")~Name);
 *   - .NET objects come back as CLR proxies (isA(.CLR)); strings, numbers,
 *     enums (net.cls's .NetEnum: = compares caselessly, as CLR_Enum) and
 *     arrays (net.cls's .NetArray, from 1) as net.cls gives them.
 * Everything else is net.cls's: events (o~Click += h), properties
 * (o~Text = "x", enums from a name), START, SEND, COPY... going to .NET
 * members of that name when there is one (o~clr.dispatch("Start") works too).
 */

::requires "net.cls"
::requires "rexxnet" LIBRARY          -- NetRequest (net.cls's requests to the bridge)

/* ------------------------------------------------------------------ CLR */

/** A .NET object made or imported through CLR.CLS's interface. */
::class CLR public subclass NetObject

::method init                        -- .clr~new(typeName, args...), or (a .NetObject): a proxy for it
  use arg what
  signal on syntax
  if arg() = 0 then raise syntax 93.901 array(1)
  if what~isA(.NetObject) then do
    if arg() > 1 then raise syntax 93.902 array(1)
    self~init:super(what)
    return
  end
  if \what~isA(.String) then raise syntax 40.900 array("CLR.CLS/CLR::INIT: the type name must be a string, found" what~class~id)
  if clr.isBoxable(what) then do     -- .clr~new("System.Int16", 5): a boxed value, as clr.box
    if arg() \= 2 then raise syntax 40.900 array("CLR.CLS/CLR::INIT, wrapping a primitive value: exactly one value needed")
    self~init:super(.net~box(what, arg(2)))
    return
  end
  type = .net~type(what)
  self~init:super(type~sendWith("NEW", clr.args(arg(2, "A"))))
  return
syntax: raise propagate

::method unknown                     -- its instance and static members together, as CLR.CLS found them
  use arg name, args
  signal on syntax
  if name~right(1) == "=" then do      -- o~Name = value
    if args~items \= 1 | args[1]~isA(.NetEvent) then forward class (super)   -- (o~Click += h: net.cls checks it)
    call NetRequest "set", self, name~left(name~length - 1), "b", clr.args(args)[1]
    return
  end
  call NetRequest "send", self, name, "b", clr.args(args)
  if var("RESULT") then return clr.result(result)
  return
syntax: raise propagate

::method clr.dispatch                -- o~clr.dispatch("Start", args...): a .NET member, whatever its name
  use arg name
  forward message "UNKNOWN" arguments (.array~of(name, arg(2, "A")))

::method clr.object                  -- the .NET object (this proxy: there is no Java peer any more)
  return self

::method clr.type                    -- its System.Type
  return .net~typeObject(self)

::method clr.import class            -- .clr~clr.import(typeName [, name4local]): also in .local (default: the type name)
  use strict arg typeName, name4local = (typeName)
  signal on syntax
  type = clr.import(typeName)
  if arg() > 1 & (name4local == .nil | name4local == "") then return type
  .local~setEntry(name4local, type)
  return type
syntax: raise propagate

/** A .NET object returned through a CLR proxy (CLR.CLS's CLR_Proxy). */
::class CLR_Proxy subclass CLR public

/** An imported .NET type (CLR.CLS's CLR_Class): static members, NEW, then the System.Type's members. */
::class CLR_Class public subclass NetType
::method new unguarded
  signal on syntax
  if clr.isBoxable(.net~typeOf(self)) & arg() = 1 then return .CLR_Proxy~new(.net~box(self, arg(1)))
  forward class (super) arguments (clr.args(arg(1, "A"))) continue
  return clr.result(result)
syntax: raise propagate
::method unknown                     -- static members, else the members of the System.Type object
  use arg name, args
  signal on syntax name staticFailed
  forward class (super) arguments (.array~of(name, clr.args(args))) continue
  if var("RESULT") then return clr.result(result)
  return
staticFailed:
  c = condition("O")
  if c~code \== "97.1" | c~additional[1] \== self then raise propagate
  signal on syntax name failed
  forward to (.net~typeObject(self)) message (name) arguments (clr.args(args)) continue
  if var("RESULT") then return clr.result(result)
  return
failed: raise propagate
::method clr.dispatch
  use arg name
  forward message "UNKNOWN" arguments (.array~of(name, arg(2, "A")))
::method clr.object
  return self
::method clr.type
  return .net~typeObject(self)
::method clr.typeName
  return .net~typeOf(self)

/* ------------------------------------------------------------- routines */

/** clr.import(typeName [, name4local]): the type, which understands NEW (not put in .local unless named). */
::routine clr.import public
  use strict arg typeName, name4local = .nil
  signal on syntax
  type = .CLR_Class~new(.net~type(typeName))
  if name4local \== .nil & name4local \== "" then .local~setEntry(name4local, type)
  return type
syntax: raise propagate

/** clr.createEventHandler(rexxObject [, userData]): a handler whose calls go to rexxObject~invoke(sender,
    eventArgs, slotDir), slotDir a Directory with USERDATA (as BSF4ooRexx appends it). */
::routine clr.createEventHandler public
  use strict arg target, userData = .nil
  return .net~handler(.CLR_EventAdapter~new(target, userData), "INVOKE")

/** clr.createArray(typeName, capacity): a one-dimensional .NET array (a .NetArray, from 1). */
::routine clr.createArray public
  use strict arg typeName, capacity
  signal on syntax
  if \datatype(capacity, "W") | capacity < 0 then
    raise syntax 40.900 array("CLR.CLS/clr.createArray, argument 'capacity'" pp(capacity) "is not a non-negative whole number")
  return .net~System~Array~CreateInstance(.net~type(typeName), .net~int32(capacity))
syntax: raise propagate

/** clr.box(typeIndicator, value): a .NET object holding value as that type (CLR.CLS's indicators, any type name). */
::routine clr.box public
  use strict arg type, value
  signal on syntax
  if value == .nil then return .nil
  return .CLR_Proxy~new(.net~box(type, value))
syntax: raise propagate

/** clr.unbox(o): a boxed primitive, string or enum as a Rexx string; anything else unchanged. */
::routine clr.unbox public
  use strict arg o
  return .net~unbox(o)

/** clr.wrap(value): a CLR proxy; a Rexx number boxed as Int32, Int64 or Decimal, any other string as a String. */
::routine clr.wrap public
  use strict arg value
  signal on syntax
  if value~isA(.CLR) then return value
  if value~isA(.NetObject) then return .CLR_Proxy~new(value)
  if \value~isA(.String) then raise syntax 40.900 array("CLR.CLS/clr.wrap, argument 'value'" pp(value) "cannot be wrapped for CLR")
  numeric digits 30
  if datatype(value, "N") then do
    if datatype(value, "W") then do
      if value >= -2147483648 & value <= 2147483647 then return clr.box("Int32", value)
      if value >= -9223372036854775808 & value <= 9223372036854775807 then return clr.box("Int64", value)
    end
    return clr.box("Decimal", value)
  end
  return clr.box("String", value)
syntax: raise propagate

/** clr.addAssembly(name): loads an assembly (its types become reachable by name). */
::routine clr.addAssembly public
  use strict arg name
  signal on syntax
  x = .net~load(name)
  return
syntax: raise propagate

/** BSF.CLS's pp(): "[" value "]". */
::routine pp public
  return "[" || arg(1)~string || "]"

/* ------------------------------------------------------------- internals */

-- The arguments of a CLR.CLS call: whole numbers as Int32 (Int64 past its range), as clr.wrap made them.
::routine clr.args private
  use arg args
  out = .array~new(args~size)
  numeric digits 30
  do i = 1 to args~size
    if \args~hasIndex(i) then iterate
    a = args[i]
    if a~isA(.String), datatype(a, "W") then do
      if a >= -2147483648 & a <= 2147483647 then a = .net~int32(a)
      else if a >= -9223372036854775808 & a <= 9223372036854775807 then a = .net~int64(a)
    end
    out[i] = a
  end
  return out

-- A result: a plain .NetObject as a CLR proxy; anything else as net.cls gives it.
::routine clr.result private
  use arg r
  if r~isA(.NetObject), r~class == .NetObject then return .CLR_Proxy~new(r)
  return r

-- A type name of CLR.CLS's boxable wrapper types (System.Int16, ..., System.String).
::routine clr.isBoxable private
  use arg name
  return wordPos(name~upper, "SYSTEM.BOOLEAN SYSTEM.BYTE SYSTEM.CHAR SYSTEM.DECIMAL SYSTEM.DOUBLE SYSTEM.INT16" -
    "SYSTEM.UINT16 SYSTEM.INT32 SYSTEM.UINT32 SYSTEM.INT64 SYSTEM.UINT64 SYSTEM.SBYTE SYSTEM.SINGLE SYSTEM.STRING") > 0

/** The Rexx side of clr.createEventHandler: calls target~invoke(args..., slotDir). */
::class CLR_EventAdapter
::method init
  expose target slotDir
  use strict arg target, userData
  slotDir = .directory~new
  slotDir~userData = userData
::method invoke unguarded
  expose target slotDir
  args = arg(1, "A")~~append(slotDir)
  if var("RESULT") then drop result
  target~sendWith("INVOKE", args)
  if var("RESULT") then return result

/* ------------------------------------------------------------- CLRThread */

/** Subclass it and define RUN; ~start(rexxData) runs RUN on a new Rexx thread, with a slotDir whose
    USERDATA is rexxData (CLR.CLS used a java.lang.Thread; a Rexx thread reaches .NET as well). */
::class CLRThread public
::method start
  use strict arg rexxData = .nil
  slotDir = .directory~new
  slotDir~userData = rexxData
  self~start:super("RUN", slotDir)
::method run abstract

/* ------------------------------------------------------------- CLRLogger */

/** CLR.CLS's logger: .CLRLogger~logLevel = "DEBUG"; .CLRLogger~debug("text"). This package logs nothing
    itself; the class is here for programs that use it. */
::class CLRLogger public
::method init private abstract
::method init class
  expose levels level doLogging
  levels = .directory~new
  levels~off = 70; levels~fatal = 60; levels~error = 50; levels~warn = 40
  levels~info = 30; levels~debug = 20; levels~trace = 10
  level = 70; doLogging = .false
::attribute doLogging get class
::method logLevels class
  expose levels
  return levels~copy
::method logLevel class
  expose levels level
  return levels~index(level)
::method "logLevel=" class
  expose levels level doLogging
  parse arg wanted
  if \levels~hasEntry(wanted) then raise syntax 40.900 array("CLR.CLS/CLRLogger/LOGLEVEL=: unknown level" pp(wanted))
  level = levels~entry(wanted)
  doLogging = wanted~upper \== "OFF"
::method unknown class
  expose levels level
  use arg name, args
  if \levels~hasEntry(name) then raise syntax 97.1 array(self, name)
  if levels~entry(name) >= level then .error~say(pp(.dateTime~new) "|" pp(left(name, 5)) "|" pp(args[1]))
