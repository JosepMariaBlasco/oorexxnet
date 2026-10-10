/* forms-extend.rex: a window that is a Rexx class extending Form.
   .net~extend makes a .NET subclass of System.Windows.Forms.Form whose
   protected virtual members OnPaint, OnResize, ProcessDialogKey and
   OnFormClosed are the Rexx methods of the same names: Windows Forms calls
   them as it calls a C# subclass's overrides. The window shows a clock,
   repainted each second by a Timer; Escape closes it (ProcessDialogKey);
   self~base.OnPaint(e) is C#'s base.OnPaint(e), and self~DoubleBuffered,
   a protected property, is reached only from the object's own methods.
   "rexx forms-extend.rex auto" closes by itself after a few ticks.        */

.net~System~Windows~Forms~Application~EnableVisualStyles
clock = .Clock~new(arg(1)~strip~caselessEquals("auto"))
.net~System~Windows~Forms~Application~Run(clock)
say "Painted" clock~paints "time(s); closed by" clock~closedBy"."
exit

::requires "net.cls"

::class Clock subclass NetObject
::method activate class
  .net~extend(self, "System.Windows.Forms.Form")

::attribute paints get
::attribute closedBy get
::method init
  expose paints closedBy ticks auto timer
  use strict arg auto
  paints = 0; ticks = 0; closedBy = "the user"
  self~init:super                                 -- new Form()
  self~Text = "A Rexx class extending Form (Escape closes)"
  self~ClientSize = .net~System~Drawing~Size~new(420, 200)
  self~StartPosition = "CenterScreen"
  self~DoubleBuffered = .true                     -- protected
  timer = .net~System~Windows~Forms~Timer~new
  timer~Interval = 500
  timer~Tick += .net~handler(self, "TICK")
  timer~Start

::method tick                                     -- the Timer: repaint; in auto mode, close after a while
  expose ticks auto closedBy
  ticks += 1
  self~Invalidate
  if auto & ticks >= 4 then do
    closedBy = "the program"
    self~Close
  end

::method OnPaint                                  -- protected virtual void OnPaint(PaintEventArgs e)
  expose paints
  use arg e
  paints += 1
  drawing = .net~System~Drawing
  g = e~Graphics
  g~SmoothingMode = "AntiAlias"
  size = self~ClientSize
  rect = drawing~Rectangle~new(0, 0, size~Width, size~Height)
  brush = .net~System~Drawing~Drawing2D~LinearGradientBrush~new(rect, drawing~Color~LightYellow, drawing~Color~Khaki, 90.0)
  g~FillRectangle(brush, rect)
  brush~Dispose
  font = drawing~Font~new("Segoe UI", 36.0)
  text = time()
  measure = g~MeasureString(text, font)
  g~DrawString(text, font, drawing~Brushes~DarkSlateBlue, (size~Width - measure~Width) / 2, (size~Height - measure~Height) / 2)
  font~Dispose
  self~base.OnPaint(e)                            -- base.OnPaint(e): the Paint event's handlers, if any

::method OnResize                                 -- protected virtual void OnResize(EventArgs e)
  use arg e
  self~Invalidate
  self~base.OnResize(e)

::method ProcessDialogKey                         -- protected virtual bool ProcessDialogKey(Keys keyData)
  use arg key
  if key = "Escape" then do
    self~Close
    return .true
  end
  return self~base.ProcessDialogKey(key)

::method OnFormClosed                             -- protected virtual void OnFormClosed(FormClosedEventArgs e)
  expose timer
  use arg e
  timer~Stop
  self~base.OnFormClosed(e)
