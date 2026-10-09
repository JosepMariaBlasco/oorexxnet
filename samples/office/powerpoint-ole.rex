/* powerpoint-ole.rex: PowerPoint in a nutshell, with ooRexx's .OLEObject
   (COM). Its twin, powerpoint-net.rex, does the same through the .NET
   bridge. A title slide and a bulleted slide; saved as
   powerpoint-sample.pptx in the temporary folder. "auto": no window.      */
ppt = .OLEObject~new("PowerPoint.Application")
withWindow = -1                                              -- msoTrue (Office's TriState: -1, not 1)
if arg(1)~strip~caselessEquals("auto") then withWindow = 0  -- (PowerPoint itself cannot be hidden)
pres = ppt~Presentations~Add(withWindow)

slide = pres~Slides~Add(1, 1)                                -- ppLayoutTitle
slide~Shapes~Item(1)~TextFrame~TextRange~Text = "ooRexx and PowerPoint"
slide~Shapes~Item(2)~TextFrame~TextRange~Text = "Written by a Rexx program," date()

slide = pres~Slides~Add(2, 2)                                -- ppLayoutText
slide~Shapes~Item(1)~TextFrame~TextRange~Text = "Why Rexx"
bullets = .array~of("Easy to read and write", "Objects, messages, classes", "Bridges to Java and .NET")
slide~Shapes~Item(2)~TextFrame~TextRange~Text = bullets~makeString("L", "0d"x)   -- a paragraph each

say "Slides:" pres~Slides~Count
file = value("TEMP", , "ENVIRONMENT") || "\powerpoint-sample.pptx"
pres~SaveAs(file)
say "Saved" file
pres~Close
ppt~Quit
