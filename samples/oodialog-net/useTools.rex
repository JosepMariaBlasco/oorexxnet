/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2011-2014 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                                        */
/*                                                                            */
/* Redistribution and use in source and binary forms, with or                 */
/* without modification, are permitted provided that the following            */
/* conditions are met:                                                        */
/*                                                                            */
/* Redistributions of source code must retain the above copyright             */
/* notice, this list of conditions and the following disclaimer.              */
/* Redistributions in binary form must reproduce the above copyright          */
/* notice, this list of conditions and the following disclaimer in            */
/* the documentation and/or other materials provided with the distribution.   */
/*                                                                            */
/* Neither the name of Rexx Language Association nor the names                */
/* of its contributors may be used to endorse or promote products             */
/* derived from this software without specific prior written permission.      */
/*                                                                            */
/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        */
/* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT          */
/* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,      */
/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   */
/* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,        */
/* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY     */
/* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING    */
/* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         */
/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               */
/*                                                                            */
/*----------------------------------------------------------------------------*/

/** Owned window example
 *
 * This example demonstrates how to make a dialog window owned by another dialog
 * window.  It simulates a tool palette, which is owned by the main dialog.
 *
 * Windows that are owned by another window have several constraints.  The owned
 * window is always above its owner window.  If the owner window is minimized,
 * the owned window is hidden.  When the owner window is destroyed, its owned
 * windows are also destroyed.
 *
 * The programmer creates an owned window by setting its ownerDialog attribute
 * to the owner window.
 *
 * (.NET version of ooDialog's examples\useTools.rex, on Windows Forms through
 * oodnet.cls. ownerDialog is the form's Owner. The main dialog runs with
 * execute and pops up the first tool palette once it shows (ooDialog:
 * executeAsync, then popup, then endAsyncExecution); a palette is a modeless
 * form (popup). Its buttons are sized in pixels, which is what Windows Forms
 * works in (ooDialog: pixel2dlgUnit), and each shows its bitmap, black
 * transparent, as the original's image list (the button's Image). A clicked
 * button is its event's sender, whose Name is its id. The ids are names, so
 * no useTools.h; the bitmaps are the original's, in resources\.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

  dlg = .MainDialog~new
  dlgTool = .ToolPaletteDlg~new

  dlgTool~ownerDialog = dlg
  dlg~palette = dlgTool                 -- (.NET version) popped up when the main dialog shows

  dlg~execute("SHOWTOP")

::requires "oodnet.cls"

::class 'MainDialog' subclass NetDialog

::method init
  forward class (super) continue

  self~create(30, 30, 466, 323, "Main Dialog", "CENTER MINIMIZEBOX MAXIMIZEBOX")


::method defineDialog

  self~createStaticText(IDC_ST_TOOL_SIMULATOR, 50, 50, 366, 223, "CENTER", "")
  self~createPushButton(IDC_PB_SHOW_PALETTE, 20, 299, 50, 14, "HIDDEN", "Show Palette", onShowPalette)
  self~createPushButton(IDOK, 342, 299, 50, 14, "DEFAULT", "Ok")
  self~createPushButton(IDCANCEL, 397, 299, 50, 14, , "Cancel")


::method initDialog
  expose font toolText

  d = .directory~new
  d~weight = 700
  d~quality = 2
  font = self~createFontEx("Arial", 40, d)

  toolText = self~newStatic(IDC_ST_TOOL_SIMULATOR)
  toolText~Font = font                                  -- ooDialog: toolText~setFont(font)
  self~form~Shown += .net~handler(self, "SHOWN")        -- (.NET version) the first palette, then

::method "PALETTE="                    -- (.NET version) the first tool palette
  expose dlgTool
  use strict arg dlgTool

::method shown unguarded               -- (.NET version) the main dialog shows: its tool palette too
  expose dlgTool
  use arg sender, e
  dlgTool~popup("SHOWTOP")

-- The event handling method for the Show Palette button click.  We hide the
-- button and execute a new tool palette dialog.  The button is always hidden
-- while a tool palette dialog is executing and is only visible when the user
-- has closed the currently executing tool palette dialog.
::method onShowPalette unguarded
  expose dlgTool

  self~paletteButton(.false)

  dlgTool = .ToolPaletteDlg~new
  dlgTool~ownerDialog = self
  dlgTool~popup("SHOWTOP")


-- The leaving method is invoked automatically when the dialog is being
-- closed.  (.NET version) .NET frees the font itself.
::method leaving
  expose font

  self~deleteFont(font)


-- The following methods just display the tool being used to simulate the
-- tool the user selected.  A real program would need code to actually use
-- the selected tool.
::method lockModule
  expose toolText
  toolText~Text = 'Running lockModule tool'             -- ooDialog: toolText~setText(...)

::method lockProject
  expose toolText
  toolText~Text = 'Running lockProject tool'

::method splitModule
  expose toolText
  toolText~Text = 'Running splitModule tool'

::method saveModule
  expose toolText
  toolText~Text = 'Running saveModule tool'

::method saveProject
  expose toolText
  toolText~Text = 'Running saveProject tool'

::method saveAll
  expose toolText
  toolText~Text = 'Running saveAll tool'

::method checkIn
  expose toolText
  toolText~Text = 'Running checkIn tool'

::method linkToWeb
  expose toolText
  toolText~Text = 'Running linkToWeb tool'

::method codeReview
  expose toolText
  toolText~Text = 'Running codeReview tool'

::method update
  expose toolText
  toolText~Text = 'Running update tool'

::method projectReview
  expose toolText
  toolText~Text = 'Running projectReview tool'


-- Invoked by the tool palette dialog when the user presses the close tool
-- button.  That is the only way for the user to close the tool palette.  Here
-- we set the tool text to the empty string and then make the Show Palette
-- button visible.  This allows the user to click on the button and reshow a
-- tool palette.
::method closePalette
  expose toolText

  toolText~Text = ''
  self~paletteButton(.true)


-- This private method either hides or makes visible the Show Palette button
-- depending on the value of the argument.
::method paletteButton private
  use strict arg showButton

  self~newPushButton(IDC_PB_SHOW_PALETTE)~Visible = showButton   -- ooDialog: ~show / ~hide

::method autoRun                       -- (.NET version) unattended: three tools, the palette closed and shown again, then Ok
  expose dlgTool toolText
  do id over .array~of(IDC_PB_SAVEALL, IDC_PB_CHECKIN, IDC_PB_UPDATE)
    dlgTool~control(id)~PerformClick
    say "(auto)" toolText~Text
  end
  say "(auto) palette owned by" dlgTool~form~Owner~Text
  dlgTool~control(IDC_PB_CLOSE)~PerformClick
  say "(auto) palette closed; Show Palette visible:" self~newPushButton(IDC_PB_SHOW_PALETTE)~Visible
  self~newPushButton(IDC_PB_SHOW_PALETTE)~PerformClick
  say "(auto) a new palette:" dlgTool~form~Visible", Show Palette visible:" self~newPushButton(IDC_PB_SHOW_PALETTE)~Visible
  self~ok                              -- (the palette closes with its owner)


::class 'ToolPaletteDlg' subclass NetDialog

::method init
  expose buttonIDs
  forward class (super) continue

  -- Populate the buttonIDs and buttonNames arrays.
  self~populateButtons()

  -- (.NET version) the size comes in defineDialog, in pixels: one 40 x 40
  -- button for each tool, a gap of one, the close button
  self~create(0, 30, 10, 10, "Tool Palette", "NOMENU")


::method defineDialog
  expose buttonIDs buttonNames

  -- Create all our tool buttons and connect their button click event with the
  -- onToolClick method in this dialog.  (.NET version) Each is 40 x 40
  -- pixels, its 32 x 32 bitmap in the middle: a 4 pixel margin, so that the
  -- button high-lighting for hot, pressed, default, etc., shows.
  D = .net~System~Drawing
  s = 40
  do i = 1 to buttonIDs~items
    x = (i - 1) * s
    if i == buttonIDs~items then x += s
    self~createPushButton(buttonIDs[i], 0, 0, 1, 1, 'BITMAP', , onToolClick)
    b = self~newPushButton(buttonIDs[i])
    b~Bounds = D~Rectangle~new(x, 0, s, s)
    b~FlatStyle = "Standard"            -- (a button drawn by Windows shows no image)
    image = D~Bitmap~new(buttonNames[i])                 -- ooDialog: .Image~getImage(file, 'BITMAP'), and an
    image~MakeTransparent(D~Color~Black)                 -- image list of it, masked by black (.Image~colorRef(0, 0, 0))
    b~Image = image
  end
  self~form~ClientSize = D~Size~new((buttonIDs~items + 1) * s, s)


-- The event handler for the button click event.  We map which button was
-- clicked to the proper method in the parent / owner dialog and invoke that
-- method.  (.NET version) The button is the sender; its Name is its id.
::method onToolClick unguarded
   use arg sender, e

   caseOf = sender~Name
   select case caseOf                                    -- (not the expression itself: ooRexx bug, SELECT CASE: #2114)
      when "IDC_PB_LOCKMODULE"    then self~ownerDialog~lockModule
      when "IDC_PB_LOCKPROJECT"   then self~ownerDialog~lockProject
      when "IDC_PB_SPLITMODULE"   then self~ownerDialog~splitModule
      when "IDC_PB_SAVEMODULE"    then self~ownerDialog~saveModule
      when "IDC_PB_SAVEPROJECT"   then self~ownerDialog~saveProject
      when "IDC_PB_SAVEALL"       then self~ownerDialog~saveAll
      when "IDC_PB_CHECKIN"       then self~ownerDialog~checkIn
      when "IDC_PB_LINKTOWEB"     then self~ownerDialog~linkToWeb
      when "IDC_PB_CODEREVIEW"    then self~ownerDialog~codeReview
      when "IDC_PB_UPDATE"        then self~ownerDialog~update
      when "IDC_PB_PROJECTREVIEW" then self~ownerDialog~projectReview
      when "IDC_PB_CLOSE"         then do
        self~cancel:super
        self~ownerDialog~closePalette
      end
      otherwise nop
   end
   -- End select


-- Over-riding the ok and cancel methods, but not doing anything, prevents the
-- user from closing the tool palette unless she uses the close tool button.
::method ok
::method cancel


-- Private method to fill 2 arrays with the button IDs and the button bitmap
-- names.
::method populateButtons private
  expose buttonIDs buttonNames

  srcDir = filespec("location", .context~package~name)   -- (.NET version) ooDialog: .application~srcDir

  buttonIDs   = .array~of(IDC_PB_LOCKMODULE,    -
                          IDC_PB_LOCKPROJECT,   -
                          IDC_PB_SPLITMODULE,   -
                          IDC_PB_SAVEMODULE,    -
                          IDC_PB_SAVEPROJECT,   -
                          IDC_PB_SAVEALL,       -
                          IDC_PB_CHECKIN,       -
                          IDC_PB_LINKTOWEB,     -
                          IDC_PB_CODEREVIEW,    -
                          IDC_PB_UPDATE,        -
                          IDC_PB_PROJECTREVIEW, -
                          IDC_PB_CLOSE          -
                          )

  buttonNames = .array~of(srcDir'resources\LockModule.bmp',     -
                          srcDir'resources\LockProject.bmp',    -
                          srcDir'resources\SplitModule.bmp',    -
                          srcDir'resources\SaveModule.bmp',     -
                          srcDir'resources\SaveProject.bmp',    -
                          srcDir'resources\SaveAll.bmp',        -
                          srcDir'resources\CheckIn.bmp',        -
                          srcDir'resources\LinkToWeb.bmp',      -
                          srcDir'resources\CodeReview.bmp',     -
                          srcDir'resources\Update.bmp',         -
                          srcDir'resources\ProjectReview.bmp',  -
                          srcDir'resources\ClosePalette.bmp'    -
                          )
