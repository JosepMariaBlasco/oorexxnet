/* 03-files.rex: files and directories through System.IO.
   Static methods of File, Directory and Path; a Rexx Array goes to .NET as
   the string[] WriteAllLines wants, and the string[] ReadAllLines gives back
   is a Rexx Array.                                                        */

io = .net~System~IO
dir = io~Path~Combine(io~Path~GetTempPath, "rexxnet-sample-" || .net~System~Guid~NewGuid~ToString("N")~left(8))
io~Directory~CreateDirectory(dir)
say "Working in" dir

-- write three files, one of them with lines from a Rexx Array
io~File~WriteAllLines(io~Path~Combine(dir, "fruit.txt"), .array~of("apple", "pear", "fig"))
io~File~WriteAllText(io~Path~Combine(dir, "note.md"), "# A note" || .endOfLine || "Written from Rexx.")
io~File~WriteAllText(io~Path~Combine(dir, "empty.txt"), "")

-- read one back: a Rexx Array of lines
lines = io~File~ReadAllLines(io~Path~Combine(dir, "fruit.txt"))
say "fruit.txt has" lines~items "lines; the second is" lines[2]

-- list the directory with FileInfo objects
say "Files:"
do f over io~DirectoryInfo~new(dir)~GetFiles("*")
  say "  " f~Name~left(12) right(f~Length, 4) "bytes," f~Extension "file, written" f~LastWriteTime~ToString("HH:mm:ss")
end

-- only the .txt files: GetFiles gives a string[], a Rexx Array of paths
names = .array~new
do path over io~Directory~GetFiles(dir, "*.txt")
  names~append(io~Path~GetFileName(path))
end
say "Text files:" names~sort~makeString("L", ", ")

-- clean up
io~Directory~Delete(dir, .true)
say "Deleted:" (\io~Directory~Exists(dir))

::requires "net.cls"
