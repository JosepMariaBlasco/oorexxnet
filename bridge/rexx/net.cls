/*----------------------------------------------------------------------------*/
/* ooRexx/.NET: .NET objects as Rexx objects (prototype, phase 3).            */
/* Design: notes/netobject-design.md (ooRexx/.NET project).                   */
/*----------------------------------------------------------------------------*/
/*
 *    say .net~System~Math~Max(3, 7)                          -- 7
 *    sb = .net~System~Text~StringBuilder~new
 *    sb~Append("a")~Append(42); say sb~ToString              -- a42
 *    l = .net~type("System.Collections.Generic.List<int>")~new; l~Add(3)
 *    ::requires "net.cls"
 *
 * .net is the root of .NET's namespaces (.net~System~IO is a namespace,
 * .net~System~IO~File a type) and holds the bridge's helpers. Every .NET
 * object is a .NetObject (by reference, never copied); a type is a .NetType,
 * whose messages go to its static members and which understands NEW.
 * Messages to a .NetObject:
 *   o~Name          property or field, or method called with no arguments
 *   o~Name(a, b)    method (the overload whose parameters accept a, b)
 *   o~Name = v      property or field set
 * Names are caseless (ooRexx uppercases them); exact: .net~invoke(o, "Name",
 * args...), .net~get(o, "Name"), .net~set(o, "Name", v). START, SEND, COPY,
 * RUN, REQUEST and STRING go to the .NET member of that name when there is
 * one (Process~Start, .net~System~String), else to Rexx's Object; say and
 * concatenation show a proxy through MAKESTRING.
 *
 * Collections: o[i], o[i, j] = v are array elements and indexers, 0-based
 * as in C# (list[0], dict["key"], grid[1, 2]). DO x OVER o gives the items
 * of any IEnumerable (a dictionary's KeyValuePairs, as C#'s foreach); DO
 * WITH INDEX i ITEM v OVER o gives keys and values of a dictionary, the
 * 0-based positions of an array or list, 1..n otherwise. Both take a
 * snapshot when the loop starts; an enum type gives its names (DO OVER) or
 * names and values (DO WITH).
 *
 * Generic methods: type arguments inferred from the arguments (a Rexx string
 * counts as a System.String: .net~int32(5) for an int), or given in the name:
 * .net~invoke(o, "Make<int>"), o~"Make<int>". ref / out / in parameters take
 * a .NetRef: r = .net~ref; d~TryGetValue("k", r); say r~value. A Task or
 * ValueTask: o~await waits (blocking this thread) and gives its result.
 * Structs come as a boxed copy: setting a field changes that copy.
 *
 * Values: .NET strings, numbers, bools (1/0), chars and enums (their names)
 * come back as Rexx strings, null as .nil, anything else as a .NetObject.
 * A Rexx string goes as the type of the parameter it is for ("007" stays
 * "007" for a string, is 7 for an int); .net~int16(x) ... .net~decimal(x),
 * .net~bool(x), .net~char(x), .net~string(x), .net~as(x, type) and .net~null
 * force a type; a Rexx Array goes as an array or List (a copy); any other
 * Rexx object (a Directory, a Stem, an instance of a Rexx class...) goes by
 * reference, a Rexx.Net.RexxObject that .NET can keep and send messages to,
 * and comes back as itself. A .NET exception is SYNTAX 98.900 ".NET error:
 * Type: message"; the exception is condition("O")~additional[2]. A Rexx
 * error in Rexx code that the .NET code called, which that code lets
 * through, is raised again here as it was.
 *
 * Callbacks and events: .net~handler(object, message [, options]) is a
 * .NetHandler. Where .NET wants a delegate (an Action, a Func, a Comparison,
 * an EventHandler, any delegate type) it becomes one of that exact type
 * (the same one each time, so -= works):
 *
 *    list~Sort(.net~handler(self, "COMPARE"))       -- a Comparison<T>
 *    button~Click += .net~handler(self, "CLICKED")  -- an event
 *    button~Click -= .net~handler...                -- the same handler object
 *    ::method clicked
 *      use arg sender, e                            -- the delegate's arguments
 *
 * By default a call runs at once, on the thread .NET calls it on (attached
 * to the interpreter; on a Rexx thread inside .NET, nested), and what the
 * method returns goes back to .NET as the delegate's return type (a sort
 * comparator, a Func, e~Cancel = 1 in a handler all work). A Rexx error in
 * the method is a RexxException in .NET; if it comes back out of .NET to
 * Rexx, it is raised again as it was. On a thread where no Rexx code waits
 * for .NET (a timer, the thread pool) the error is reported on .error, as
 * Rexx reports an untrapped error, the call returns its delegate's default,
 * and the program goes on. A handler fits a delegate returning
 * nothing before one returning a value (Task.Run(Action)); force another
 * with .net~as(h, "System.Func<int>"). Methods called from other threads
 * while the object is busy in a guarded method wait for it: make such
 * handler methods UNGUARDED.
 *
 * Option "queued": the call is queued and the delegate returns at once (its
 * type's default); a Rexx thread takes the calls: .net~nextEvent([seconds])
 * gives the next one (a .NetCall; .nil when the time is over), call~dispatch
 * sends the message with the call's arguments; .net~eventLoop does that
 * until .net~stopEventLoop. Option "latest" (implies "queued") keeps at most
 * one call of the handler waiting, the newest. handler~release: its later
 * calls do nothing (queued ones are dropped).
 */
.environment~net = .NetGlobal~new("")

::requires "rexxnet" LIBRARY

/** A .NET object. */
::class NetObject public
::method init
  expose netid netdisplay
  use strict arg netid, netdisplay
::method netId unguarded             -- the handle, for the bridge
  expose netid
  return netid
::method makeString unguarded        -- a NetObject (System.Text.StringBuilder #12), a NetType (System.Math)
  expose netid netdisplay                -- (say and concatenation use makeString; STRING is free for .NET)
  if self~isA(.NetType) then return "a NetType ("netdisplay")"
  return "a NetObject ("netdisplay "#"netid")"
::method string unguarded            -- a .NET member String if there is one, else makeString
  if NetRequest("has", self, "STRING") then forward message "UNKNOWN" arguments (.array~of("STRING", arg(1, "A")))
  return self~makeString
::method "==" unguarded              -- the same .NET object
  expose netid
  use strict arg other
  if \other~isA(.NetObject) then return .false
  return other~netId == netid
::method "\==" unguarded
  use strict arg other
  return \(self == other)
::method "=" unguarded
  forward message "=="
::method "\=" unguarded
  forward message "\=="
::method "<>" unguarded
  forward message "\=="
::method "><" unguarded
  forward message "\=="
::method hashCode unguarded
  expose netid
  return netid~hashCode
::method makeArray unguarded         -- DO x OVER o: the items of an IEnumerable (a snapshot)
  signal on syntax
  return NetRequest("items", self)
syntax: raise propagate
::method supplier unguarded          -- DO WITH INDEX i ITEM v OVER o (indexes: see the header)
  signal on syntax
  pairs = NetRequest("pairs", self)
  return .supplier~new(pairs[2], pairs[1])
syntax: raise propagate
::method "[]" unguarded              -- o[i, ...]: an array element or the indexer (0-based)
  signal on syntax
  return NetRequest("index", self, arg(1, "A"))
syntax: raise propagate
::method "[]=" unguarded             -- o[i, ...] = value (Rexx sends the value first)
  signal on syntax
  use arg value
  call NetRequest "setIndex", self, value, arg(2, "A")
  return
syntax: raise propagate
::method await unguarded             -- a Task / ValueTask: wait, its result (none for a plain Task)
  signal on syntax
  call NetRequest "await", self
  if var("RESULT") then return result
  return
syntax: raise propagate
::method unknown unguarded           external "LIBRARY rexxnet net_unknown"
::method uninit unguarded            external "LIBRARY rexxnet net_uninit"
-- Rexx's Object methods whose names .NET uses often: the .NET member wins.
::method start unguarded
  if NetRequest("has", self, "START") then forward message "UNKNOWN" arguments (.array~of("START", arg(1, "A")))
  forward class (super)
::method send unguarded
  if NetRequest("has", self, "SEND") then forward message "UNKNOWN" arguments (.array~of("SEND", arg(1, "A")))
  forward class (super)
::method copy unguarded
  if NetRequest("has", self, "COPY") then forward message "UNKNOWN" arguments (.array~of("COPY", arg(1, "A")))
  forward class (super)
::method run unguarded
  if NetRequest("has", self, "RUN") then forward message "UNKNOWN" arguments (.array~of("RUN", arg(1, "A")))
  forward class (super)
::method request unguarded
  if NetRequest("has", self, "REQUEST") then forward message "UNKNOWN" arguments (.array~of("REQUEST", arg(1, "A")))
  forward class (super)

/** A .NET type: its messages go to its static members; NEW makes an instance. */
::class NetType public subclass NetObject
::method new unguarded
  signal on syntax
  return NetRequest("new", self, arg(1, "A"))
syntax: raise propagate

/** A .NET namespace: ~Name is a sub-namespace or a type in it. */
::class NetNamespace public
::method init
  expose netns
  use strict arg netns
::method makeString unguarded
  expose netns
  return "a NetNamespace ("netns")"
::method string unguarded            -- .net~System~String is the type System.String
  expose netns
  signal on syntax
  return NetRequest("ns", netns, "String")
syntax: return self~makeString
::method unknown unguarded
  expose netns
  use arg name, args
  signal on syntax
  if args~items > 0 then raise syntax 98.900 array("a .NET namespace takes no arguments:" netns"."name)
  return NetRequest("ns", netns, name)
syntax: raise propagate

/** .net: the root namespace and the bridge's helpers. */
::class NetGlobal public subclass NetNamespace
::method makeString unguarded
  return "the .NET root namespace (.net)"
::method string unguarded            -- .net~string(x): x forced to System.String
  if arg() = 0 then return self~makeString
  use strict arg x
  return .NetTyped~new("System.String", x)
::method namespace unguarded         -- .net~namespace("System.IO"): exact
  signal on syntax
  use strict arg name
  return NetRequest("nsname", name)
syntax: raise propagate
::method type unguarded              -- .net~type("System.Collections.Generic.List<int>"), or (open generic, type args...)
  signal on syntax
  return NetRequest("type", arg(1, "A"))
syntax: raise propagate
::method load unguarded              -- .net~load(assembly name or .dll path): its full name
  signal on syntax
  use strict arg name
  return NetRequest("load", name)
syntax: raise propagate
::method new unguarded               -- .net~new(type, args...)
  signal on syntax
  use arg type
  if \type~isA(.NetType) then raise syntax 98.900 array(".net~new: the type must be a .NetType, found" type)
  return NetRequest("new", type, arg(2, "A"))
syntax: raise propagate
::method invoke unguarded            -- .net~invoke(o, "ExactName", args...)
  signal on syntax
  use arg o, name
  call NetRequest "send", o, name, "1", arg(3, "A")
  if var("RESULT") then return result
  return
syntax: raise propagate
::method get unguarded               -- .net~get(o, "ExactName")
  signal on syntax
  use strict arg o, name
  return NetRequest("send", o, name, "1", .array~new)
syntax: raise propagate
::method set unguarded               -- .net~set(o, "ExactName", value)
  signal on syntax
  use strict arg o, name, value
  call NetRequest "set", o, name, "1", value
  return
syntax: raise propagate
::method typeOf unguarded            -- the name of o's type
  signal on syntax
  use strict arg o
  return NetRequest("typeOf", o)
syntax: raise propagate
::method typeObject unguarded        -- o's System.Type, as a .NetObject
  signal on syntax
  use strict arg o
  return NetRequest("typeObject", o)
syntax: raise propagate
::method isInstance unguarded        -- .net~isInstance(o, type or "name")
  signal on syntax
  use strict arg o, type
  return NetRequest("isInstance", o, type)
syntax: raise propagate
::method members unguarded           -- the names of o's public members (an Array)
  signal on syntax
  use strict arg o
  return NetRequest("members", o)
syntax: raise propagate
::method handleCount unguarded       -- live handles (diagnostics)
  return NetRequest("count")
::method handler unguarded           -- .net~handler(object, message [, options]): see the header
  signal on syntax
  use strict arg target, message, options = ""
  return .NetHandler~new(target, message, options)
syntax: raise propagate
::method nextEvent unguarded         -- the next queued call (a .NetCall), or .nil after seconds
  signal on syntax
  use strict arg seconds = (-1)
  if \datatype(seconds, "N") then raise syntax 98.900 array(".net~nextEvent: seconds must be a number, found" seconds)
  return NetNextCall(seconds, -1)
syntax: raise propagate
::method eventLoop unguarded         -- dispatch queued calls until .net~stopEventLoop
  generation = NetRequest("loopGeneration")
  do forever
    call = NetNextCall(-1, generation)
    if call == .nil then return
    call~dispatch
  end
::method stopEventLoop unguarded     -- end every .net~eventLoop running now
  call NetRequest "stopLoops"
::method queuedCalls unguarded       -- calls waiting in the queue (diagnostics)
  return NetRequest("queued")
-- Forced types.
::method int16 unguarded;   use strict arg x; return .NetTyped~new("System.Int16", x)
::method int32 unguarded;   use strict arg x; return .NetTyped~new("System.Int32", x)
::method int64 unguarded;   use strict arg x; return .NetTyped~new("System.Int64", x)
::method uint16 unguarded;  use strict arg x; return .NetTyped~new("System.UInt16", x)
::method uint32 unguarded;  use strict arg x; return .NetTyped~new("System.UInt32", x)
::method uint64 unguarded;  use strict arg x; return .NetTyped~new("System.UInt64", x)
::method byte unguarded;    use strict arg x; return .NetTyped~new("System.Byte", x)
::method sbyte unguarded;   use strict arg x; return .NetTyped~new("System.SByte", x)
::method single unguarded;  use strict arg x; return .NetTyped~new("System.Single", x)
::method double unguarded;  use strict arg x; return .NetTyped~new("System.Double", x)
::method decimal unguarded; use strict arg x; return .NetTyped~new("System.Decimal", x)
::method bool unguarded;    use strict arg x; return .NetTyped~new("System.Boolean", x)
::method char unguarded;    use strict arg x; return .NetTyped~new("System.Char", x)
::method null unguarded;    return .NetTyped~new("null", .nil)
::method ref unguarded               -- .net~ref([value]): a .NetRef, for ref / out parameters
  use strict arg value = .nil
  return .NetRef~new(value)
::method as unguarded                -- .net~as(x, type or "type name")
  use strict arg x, type
  if type~isA(.NetType) then return .NetTyped~new("#"type~netId, x)
  return .NetTyped~new(type, x)

/** A Rexx object and message for .NET to call (.net~handler). */
::class NetHandler public
::attribute target get
::attribute message get
::attribute options get
::attribute id get
::attribute released get
::method init
  expose target message options id released
  use strict arg target, message, options = ""
  released = .false
  message = message~upper
  known = "queued latest"
  opts = ""
  do word over options~space~makeArray(" ")
    if wordPos(word~lower, known) = 0 then raise syntax 98.900 array(".net~handler: unknown option" word "(known:" known")")
    if wordPos(word~lower, opts) = 0 then opts = opts word~lower
  end
  if wordPos("latest", opts) > 0 & wordPos("queued", opts) = 0 then opts = opts "queued"
  options = opts~strip
  id = NetHandlerNew()
::method release unguarded           -- no more calls from .NET (queued ones are dropped)
  expose id released
  released = .true
  call NetRequest "releaseHandler", id
  call NetHandlerDrop id
::method makeString unguarded
  expose target message options
  if options == "" then return "a NetHandler ("target"~"message")"
  return "a NetHandler ("target"~"message", "options")"

/** An event of a .NET object or type: o~Click += handler, o~Click -= handler. */
::class NetEvent public
::attribute owner get
::attribute name get
::method init
  expose owner name
  use strict arg owner, name
::method "+" unguarded
  expose owner name
  signal on syntax
  use strict arg handler
  call NetRequest "event", owner, name, "add", handler
  return self
syntax: raise propagate
::method "-" unguarded
  expose owner name
  signal on syntax
  use strict arg handler
  call NetRequest "event", owner, name, "remove", handler
  return self
syntax: raise propagate
::method makeString unguarded
  expose owner name
  return "a NetEvent ("name "of" owner~makeString")"

/** One queued call of a handler (.net~nextEvent). */
::class NetCall public
::attribute handler get
::attribute arguments get
::method init
  expose handler arguments
  use strict arg handler, arguments
::method target
  expose handler
  return handler~target
::method message
  expose handler
  return handler~message
::method dispatch                    -- the handler's message to its object, with the call's arguments
  expose handler arguments
  if var("RESULT") then drop result
  handler~target~sendWith(handler~message, arguments)
  if var("RESULT") then return result
::method makeString
  expose handler arguments
  return "a NetCall ("handler~target"~"handler~message", "arguments~items "arguments)"

/** The next queued call, as a .NetCall (.nil: time over, or the loop stopped). */
::routine NetNextCall
  use arg seconds, generation
  signal on syntax
  do forever
    r = NetRequest("nextEvent", seconds, generation)
    if r == .nil then return .nil
    handler = NetHandlerOf(r[1])
    if handler \== .nil then return .NetCall~new(handler, r[2])
  end
syntax: raise propagate

/** A holder for a ref / out argument: r = .net~ref; d~TryGetValue("k", r); say r~value */
::class NetRef public
::attribute value unguarded
::method init
  expose value
  use strict arg value = .nil
::method makeString unguarded
  expose value
  return "a NetRef (" || value~string || ")"

/** A Rexx value with a .NET type forced (.net~int16(x), ...). */
::class NetTyped public
::attribute kind get
::attribute value get
::method init
  expose kind value
  use strict arg kind, value
::method string
  expose kind value
  return "a" kind "(" || value~string || ")"
