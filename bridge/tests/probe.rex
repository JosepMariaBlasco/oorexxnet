/* The conversion probe as a test: runs probe/edges.rex with the rexx that
   runs this, and compares its output with probe/edges.out, line by line.
   Fails (exit 1) on any difference, and shows them. The probe is the
   bridge's column of the ooRexx bridges' conversion table
   (JosepMariaBlasco/oorexx-bridges, topics/conversion-rules; the decision:
   topics/probes-in-ci.md): a change to its output is a change to that
   column, made on purpose, with edges.out updated in the same commit.
   Run from the build folder, as run.sh and run.ps1 do (the argument, the
   test library, is not used).                                             */
parse source . . me
dir = me~left(me~lastPos(.File~separator))
probe = dir"probe"   ||.File~separator"edges.rex"
expected = dir"probe"||.File~separator"edges.out"

address system 'rexx "'probe'"' with output stem got. error stem err.
want = .array~new
s = .Stream~new(expected)
if s~open("read") \= "READY:" then do
  say "probe: cannot read" expected
  exit 1
end
do while s~lines > 0; want~append(s~linein); end
s~close

diffs = 0
do i = 1 to max(got.0, want~items)
  g = ""; w = ""
  if i <= got.0 then g = got.i~strip("T")
  if i <= want~items then w = want[i]~strip("T")
  if g == w then iterate
  diffs += 1
  if diffs <= 20 then do
    say "probe: line" i "differs"
    say "  expected:" w
    say "  got:     " g
  end
end
do i = 1 to err.0; say "probe: stderr:" err.i; end
if diffs = 0 & err.0 = 0 then do
  say "probe: the conversion probe's" got.0 "lines match"
  exit 0
end
say "probe:" diffs "lines differ from probe/edges.out"
exit 1
