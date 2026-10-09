/* 02-collections.rex: .NET collections from Rexx.
   A List or a Dictionary is used as .NET documents it ([] with 0-based
   positions for a List, keys for a Dictionary); DO OVER and
   DO WITH INDEX ... ITEM work on anything enumerable. A .NET array is a
   Rexx Array (from 1). A Rexx method becomes a .NET delegate with
   .net~handler: here, a comparison for Sort.                             */

text = "the quick brown fox jumps over the lazy dog and the quick cat"

-- word counts in a Dictionary<string, int>
counts = .net~type("System.Collections.Generic.Dictionary<string, int>")~new
do w over text~makeArray(" ")
  if counts~ContainsKey(w) then counts[w] = counts[w] + 1
  else counts[w] = 1
end
say counts~Count "different words; 'the' appears" counts["the"] "times"

-- the words in a List<string>, sorted by .NET, then by a Rexx comparison
words = .net~type("System.Collections.Generic.List<string>")~new
do with index w item n over counts
  words~Add(w)
end
words~Sort
say "Sorted:     " .net~System~String~Join(" ", words)
words~Sort(.net~handler(.ByLength~new, "COMPARE"))
say "By length:  " .net~System~String~Join(" ", words)
say "First, last:" words[0] words[words~Count - 1]

-- a .NET array is a Rexx Array: from 1, with items, [], DO OVER
bytes = .net~System~Text~Encoding~UTF8~GetBytes("Rexx")
say "UTF-8 bytes:" bytes~items "->" bytes[1] bytes[2] bytes[3] bytes[4]
linq = .net~System~Linq~Enumerable
nums = linq~ToArray(linq~Range(1, 5))         -- an int[] (extension methods: through their class)
.net~System~Array~Reverse(nums)                -- reversed by .NET, in place: the same array
say "Reversed:   " .net~System~String~Join(" ", nums) "(first:" nums[1]")"
-- (a .NET string comes back as a Rexx string: "abc"~reverse, not ToCharArray)

-- a Rexx Array goes to .NET as the array a method wants
say "Joined:     " .net~System~String~Join(", ", .array~of("one", "two", "three"))

-- a HashSet, a Queue, a Stack
set = .net~type("System.Collections.Generic.HashSet<int>")~new
do i = 1 to 20; set~Add(i // 7); end
say "Remainders: " set~Count "distinct"
q = .net~type("System.Collections.Generic.Queue<string>")~new
q~Enqueue("first"); q~Enqueue("second")
say "Queue:      " q~Dequeue "then" q~Peek

::requires "net.cls"

::class ByLength
::method compare                      -- shorter first, then alphabetical
  use arg a, b
  if a~length \= b~length then return a~length - b~length
  return .net~System~String~CompareOrdinal(a, b)
