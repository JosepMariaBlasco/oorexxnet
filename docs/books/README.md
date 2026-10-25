# The books

Two books document the bridge, in the format and with the tools of ooRexx's
own books (DocBook 4.5, built as PDF and HTML with `docs/trunk/tools/bldoc_orx`
of ooRexx's SVN, whose highlighting of Rexx listings is the Rexx Parser's).
The CI builds them on every push (artifact `books`), and a release carries
them; the Windows installer puts the PDFs in ooRexx's `doc` folder and its
Start menu.

- `dotnetref/` — **ooRexx and .NET: Reference**, in the style of ooRexx's
  `rexxref`: names and messages, values, collections, the classes of
  `net.cls` (each method with its syntax diagram), callbacks and events, the
  event thread, errors, Rexx classes extending .NET classes, COM objects; the
  `Rexx.Net` API for .NET programs (C# signatures); both ways in one process;
  `CLR.CLS`; and appendices (platforms, pitfalls, guarantees, the relation to
  BSF4ooRexx and the sister bridges).
- `dotnetcookbook/` — **ooRexx and .NET: Cookbook**: recipes, each a
  complete program, what it prints, how it works, and the reference's
  sections to read next.

## Kept true

- Every `<example>` of the books that holds a program (`language="rexx"` or
  `"csharp"`) and a `<screen>` is run by `docs/check-books.rex`, and its
  output compared with the screen, on Linux, macOS and Windows (the CI's
  test jobs). An example with `condition="windows"` runs on Windows only,
  `condition="office"` only with the argument `office`; an example without a
  screen (it opens windows, or its output depends on the machine) is shown,
  not run.
- The syntax diagrams are made from `dotnetref/en-US/images/dotnetref.ebnf`
  (the Railroad Diagram Generator's EBNF, as ooRexx's books): after changing
  it, build with `DIAGRAMS=1` and commit the SVGs.

## Building

```bash
svn co https://svn.code.sf.net/p/oorexx/code-0/docs/trunk docSVN   # next to the clone
# the Rexx Parser, its latest release, unzipped as rexx-parser:
#   https://rexx.epbcn.com/rexx-parser/Rexx-Parser-latest.zip
sudo apt install xsltproc docbook-xml docbook-xsl fop fonts-liberation
oorexxnet/scripts/build-books.sh        # -> books/<book>.pdf, books/<book>-html/ (and .zip)
rexx oorexxnet/docs/check-books.rex     # the examples (the bridge built first)
```

`scripts/build-books.sh` explains its options (`BOOKS=`, `DIAGRAMS=1`,
`DOCS_SVN=`, `REXX_PARSER=`, `OUT=`).

Licensed under the Apache License, Version 2.0.
