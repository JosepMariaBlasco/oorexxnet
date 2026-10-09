/* 04-regex.rex: .NET's regular expressions from Rexx.
   Matches and their groups are .NET objects; Regex.Replace takes a Rexx
   method as its MatchEvaluator (.net~handler).                            */

regex = .net~System~Text~RegularExpressions~Regex
text = "Meetings: 2026-10-09 at 14:30, 2026-11-02 at 09:15, and 2027-01-15 at 17:00."

-- every date and time, with named groups
pattern = "(?<y>\d{4})-(?<m>\d\d)-(?<d>\d\d) at (?<time>\d\d:\d\d)"
do m over regex~Matches(text, pattern)
  g = m~Groups
  say "day" g["d"]~Value "of month" g["m"]~Value "of" g["y"]~Value "at" g["time"]~Value
end

-- a quick test, and a split
say "Has a 2027 date:" regex~IsMatch(text, "2027-\d\d-\d\d")
say "Words:" regex~Split("one, two;three  four", "[,;\s]+")~makeArray~makeString("L", "|")   -- a string[]: makeArray, then Rexx's makeString

-- replace with a pattern, then with a Rexx method deciding each replacement
say regex~Replace(text, "(\d{4})-(\d\d)-(\d\d)", "$3/$2/$1")
say regex~Replace(text, "\d\d:\d\d", .net~handler(.TwelveHour~new, "CONVERT"))

::requires "net.cls"

::class TwelveHour
::method convert                     -- a Match in, its replacement out
  use arg match
  parse value match~Value with h ":" m
  suffix = "am"
  if h >= 12 then suffix = "pm"
  if h > 12 then h -= 12
  return h + 0 || ":" || m || suffix
