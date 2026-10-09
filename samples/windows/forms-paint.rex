/* forms-paint.rex: drawing with System.Drawing in a window's Paint event.
   The Rexx method gets the event's Graphics and draws circles, a gradient
   and text; resizing the window repaints it (the Resize event invalidates
   the window). "rexx forms-paint.rex auto" closes by itself.             */

forms = .net~System~Windows~Forms
drawing = .net~System~Drawing

form = forms~Form~new
form~Text = "Drawn by Rexx (resize me)"
form~ClientSize = drawing~Size~new(420, 260)
form~BackColor = drawing~Color~White
painter = .Painter~new
form~Paint += .net~handler(painter, "PAINT")
form~Resize += .net~handler(painter, "RESIZE")

if arg(1)~strip~caselessEquals("auto") then do
  timer = forms~Timer~new
  timer~Interval = 1000
  timer~Tick += .net~handler(.Closer~new(form, timer), "TICK")
  timer~Start
end
forms~Application~Run(form)
say "Painted" painter~paints "time(s)."
exit

::requires "net.cls"

::class Painter
::attribute paints get
::method init
  expose paints
  paints = 0
::method resize                                     -- repaint everything on resize
  use arg sender, e
  sender~Invalidate
::method paint
  expose paints
  use arg sender, e
  paints += 1
  drawing = .net~System~Drawing
  g = e~Graphics
  g~SmoothingMode = "AntiAlias"
  size = sender~ClientSize
  w = size~Width; h = size~Height
  -- a gradient background
  rect = drawing~Rectangle~new(0, 0, w, h)
  brush = .net~System~Drawing~Drawing2D~LinearGradientBrush~new(rect, drawing~Color~AliceBlue, drawing~Color~LightSteelBlue, 90.0)
  g~FillRectangle(brush, rect)
  brush~Dispose
  -- concentric circles in the middle
  colors = .array~of("SteelBlue", "Orange", "SeaGreen", "Crimson")
  r = min(w, h) % 2 - 20
  do i = 1 to colors~items
    pen = drawing~Pen~new(drawing~Color~FromName(colors[i]), 6)
    d = r * 2 * (colors~items - i + 1) / colors~items
    g~DrawEllipse(pen, (w - d) / 2, (h - d) / 2, d, d)
    pen~Dispose
  end
  -- text
  font = drawing~Font~new("Segoe UI", 14, "Bold")
  g~DrawString("ooRexx + .NET", font, drawing~Brushes~Black, 12, 10)
  font~Dispose

::class Closer
::method init
  expose form timer
  use arg form, timer
::method tick
  expose form timer
  timer~Stop
  form~Close
