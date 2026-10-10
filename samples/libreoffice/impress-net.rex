/* impress-net.rex: LibreOffice Impress in a nutshell, through the .NET bridge.
   The same program as impress-ole.rex, with .net~createObject in place of
   .OLEObject~new; the file's URL from .NET's Uri, the objects released at
   the end. Saved as impress-sample-net.odp in the temporary folder.
   "auto": LibreOffice stays hidden.                                        */
auto = arg(1)~strip~caselessEquals("auto")
sm = .net~createObject("com.sun.star.ServiceManager")
desktop = sm~createInstance("com.sun.star.frame.Desktop")
doc = desktop~loadComponentFromURL("private:factory/simpress", "_blank", 0, -
                                   .array~of(property(sm, "Hidden", auto)))
pages = doc~getDrawPages

page = pages~getByIndex(0)                                  -- from 0, as UNO counts
page~setPropertyValue("Layout", 0)                          -- a title slide
page~getByIndex(0)~setString("ooRexx and LibreOffice")      -- its shapes: title, subtitle
page~getByIndex(1)~setString("Written by a Rexx program on" date() "at" time())

page = pages~insertNewByIndex(0)                            -- a new slide after the first
page = pages~getByIndex(1)
page~setPropertyValue("Layout", 1)                          -- title and content
page~getByIndex(0)~setString("Through COM")
list = page~getByIndex(1)
items = .array~of("0 LibreOffice's automation bridge", "1 com.sun.star.ServiceManager", -
                  "1 the whole UNO API", "0 Any COM client", "1 ooRexx's .OLEObject", "1 the .NET bridge")
do i = 1 to items~items
  parse value items[i] with level text
  range = list~getEnd
  range~setPropertyValue("NumberingLevel", level)           -- the outline level, from 0
  if i < items~items then text = text || "0a"x              -- a new paragraph
  range~setString(text)
end

page = pages~insertNewByIndex(1)
page = pages~getByIndex(2)
page~setPropertyValue("Layout", 19)                         -- title only
page~getByIndex(0)~setString("A shape")
box = doc~createInstance("com.sun.star.drawing.RectangleShape")
page~add(box)                                               -- add it first, then shape it
size = sm~Bridge_GetStruct("com.sun.star.awt.Size")
size~Width = 12000; size~Height = 5000                      -- 1/100 mm
box~setSize(size)
where = sm~Bridge_GetStruct("com.sun.star.awt.Point")
where~X = 7000; where~Y = 7000
box~setPosition(where)
box~setPropertyValue("FillColor", 3381759)                  -- RGB 0x3399FF, as a number
box~setString("Drawn by Rexx")

say "Slides:" pages~getCount
file = .net~System~IO~Path~Combine(.net~System~IO~Path~GetTempPath, "impress-sample-net.odp")
doc~storeAsURL(.net~System~Uri~new(file)~AbsoluteUri, .array~of(property(sm, "Overwrite", .true)))
say "Saved" file
slides = pages~getCount
doc~close(.true)
if \desktop~getComponents~createEnumeration~hasMoreElements then desktop~terminate   -- not if you have documents open
.net~releaseObject(sm)
exit slides \= 3                                            -- (for check-samples.rex)

::routine property                                           -- a com.sun.star.beans.PropertyValue
  use arg sm, name, value
  p = sm~Bridge_GetStruct("com.sun.star.beans.PropertyValue")
  p~Name = name
  p~Value = value
  return p

::requires "net.cls"
