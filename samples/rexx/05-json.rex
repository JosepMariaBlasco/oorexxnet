/* 05-json.rex: JSON with System.Text.Json.
   Parse a document and walk it (JsonElement values, which are structs: each
   comes as a copy), then build a .NET dictionary and serialize it.        */

json = .net~System~Text~Json
text = '{ "name": "ooRexx", "version": 5.3, "platforms": ["Windows", "Linux", "macOS"],' -
       '  "bridge": { "dotnet": true, "since": 2026 } }'

doc = json~JsonDocument~Parse(text)
root = doc~RootElement
say "name:     " root~GetProperty("name")~GetString
say "version:  " root~GetProperty("version")~GetDouble
say "bridge:   " root~GetProperty("bridge")~GetProperty("since")~GetInt32
platforms = root~GetProperty("platforms")
say "platforms:" platforms~GetArrayLength
do p over platforms~EnumerateArray
  say "   -" p~GetString
end
say "kinds:   " root~ValueKind root~GetProperty("bridge")~GetProperty("dotnet")~ValueKind
doc~Dispose

-- the other way: a Dictionary<string, object> to JSON, indented
d = .net~type("System.Collections.Generic.Dictionary<string, object>")~new
d["language"] = "Rexx"
d["year"] = .net~int32(1979)
d["objects"] = .net~box("bool", .true)          -- for "object", a Rexx 1 would go as the string "1"
options = json~JsonSerializerOptions~new
options~WriteIndented = .true
say json~JsonSerializer~Serialize(d, options)

::requires "net.cls"
