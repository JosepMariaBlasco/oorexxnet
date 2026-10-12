/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2012-2021 Rexx Language Association. All rights reserved.    */
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

/**
 * ToolTip control example.
 *
 * This example demonstrates some fundemental use of the TooTip control.  It
 * creates a tool tip for each push button in the dialog and tool tips for some
 * rectangular areas in the dialog itself.
 *
 * There is a 'Test' push button in the dialog.  When this button is pushed,
 * several short demonstrations are executed that show some of the additional
 * ToolTip methods at work.  These demonstrations print to the screen using say
 * statements.  Therefore it is best to run this example program from a standard
 * console window so that the output can be seen.
 *
 * (.NET version of ooDialog's controls\ToolTip\toolTip.rex, on Windows Forms
 * through oodnet.cls. A .NET ToolTip has a text for each control
 * (SetToolTip), shown and positioned by itself; a tip can also be shown by
 * the program where it wants (Show(text, window, x, y)), which is what the
 * original's SHOW event handler does. The dialog's four quadrants, tools of
 * a rectangle in ooDialog, are the dialog's MouseMove here: a new quadrant
 * hides the tip, and after the ToolTip's InitialDelay onShow shows the
 * quadrant's text at its top left corner. NEEDTEXT is asked when the mouse
 * first comes onto the Test button (MouseEnter), and the text kept (the
 * handler's .true). A .NET ToolTip has no maximum width: the Cancel button's
 * text is broken into lines as wide as "Press Cancel"; a balloon has one of
 * Windows' icons, not a file's, and no close button. .NET does not list a
 * ToolTip's tools: the program remembers them, for the Test button.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    -- (.NET version) No .constDir: the ids are names.

    -- Instantiate our dialog and execute it.
    dlg = .ToolTipDialog~new
    dlg~execute("SHOWTOP")

    return 0


::requires "oodnet.cls"

::class 'ToolTipDialog' subclass NetDialog


/** init()
 *
 * Usual init() method for a UserDialog subclass.  We initialize the super class
 * and then create the dialog frame to get things started.
 *
 * (.NET version) The original loads an icon here for the balloon ToolTip: a
 * .NET ToolTip shows only Windows' own icons (ToolTipIcon).
 */
::method init
    forward class (super) continue

    self~create(30, 30, 257, 123, "ToolTip Example Dialog", "CENTER")


/** defineDialog()
 *
 *  Usual defineDialog() method.  We add 3 push buttons to the dialog template.
 */
::method defineDialog

    self~createPushButton(IDC_PB_TEST, 10, 99, 50, 14, , "Test", onTest)
    self~createPushButton(IDOK, 142, 99, 50, 14, "DEFAULT", "Ok")
    self~createPushButton(IDCANCEL, 197, 99, 50, 14, , "Cancel")


/** initDialog()
 *
 * Usual initDialog() method.  ToolTips are created once the dialog's
 * controls exist.
 */
::method initDialog unguarded
    expose pbTest count ttTest ttEsc tools

    TT = .net~System~Windows~Forms~ToolTip
    tools = .array~new                                      -- (.NET version) the tools added, for onTest

    -- The main tool tip is set up in a private method, so that the code for it
    -- can be inspected without distraction.
    self~createMainToolTip

    -- Creat a somewhat fancy balloon tool tip for the Ok button.
    ttOk = TT~new                                           -- ooDialog: self~createToolTip(IDC_TT_OK, 'BALLOON CLOSE')
    ttOk~IsBalloon = .true
    ttOk~ToolTipTitle = "Important Message"                 -- ooDialog: ttOk~setTitle("Important Message", icon)
    ttOk~ToolTipIcon = "Info"

    text = 'Push the'.endOfLine'Ok button'.endOfLine'to end this'.endOfLine'foolishness'
    ttOk~SetToolTip(self~newPushButton(IDOK), text)         -- ooDialog: ttOk~addTool(self~newPushButton(IDOK), text)
    tools~append(.array~of(IDC_TT_OK, IDOK, text))

    -- Create a simple multiline tool tip for the Cancel push button.  (.NET
    -- version: no maximum tip width; the text in lines that wide.)
    ttEsc  = TT~new
    margins = 2 * 4
    s = .net~System~Windows~Forms~TextRenderer~MeasureText('Press Cancel', self~form~Font)   -- ooDialog: self~getTextSizePX
    text = wrapToWidth('Press Cancel to end the dialog', self~form~Font, s~width)   -- (the margins are the tip's own)
    ttEsc~SetToolTip(self~newPushButton(IDCANCEL), text)    -- ooDialog: ttEsc~setMaxTipWidth(s~width + margins)
    tools~append(.array~of(IDC_TT_CANCEL, IDCANCEL, text))

    -- Create a tool tip for the Test push button.
    pbTest = self~newPushButton(IDC_PB_TEST)

    ttTest = TT~new                                         -- ooDialog: ttTest~addTool(pbTest), with no text
    pbTest~MouseEnter += .net~handler(self, "ONTESTENTER")  -- ooDialog: self~connectToolTipEvent(IDC_TT_TEST, 'NEEDTEXT')

    count = 0


/** createMainToolTip()
 *
 * This is a private method we use to set up the main ToolTip.  We do the set
 * up here so that the code for the set up can be studied without any other
 * distractions.
 */
::method createMainToolTip private
    expose tt clRect1 clRect2 clRect3 clRect4 quadrant delay tools

    tt = .net~System~Windows~Forms~ToolTip~new              -- ooDialog: self~createToolTip(IDC_TT_MAIN)

    -- We divide the client area of the dialog into 4 quadrants and then add a
    -- tool for each quandrant to the main tool tip.

    clRect = self~form~ClientRectangle                      -- ooDialog: self~clientRect
    hMidpoint = trunc((clRect~right - clRect~left) / 2) + clRect~left
    vMidpoint = trunc((clRect~bottom - clRect~top) / 2) + clRect~top

    clRect1 = .array~of(clRect~left, clRect~top, hMidpoint, vMidpoint)   -- (.NET version) .Rect: left, top, right, bottom
    clRect2 = .array~of(hMidpoint + 1, clRect~top, clRect~right, vMidpoint + 1)
    clRect3 = .array~of(clRect~left, vMidpoint + 1, hMidpoint + 1, clRect~bottom)
    clRect4 = .array~of(hMidpoint + 1, vMidpoint + 1, clRect~right, clRect~bottom)

    texts = .array~of('Over main dialog, top left quadrant', 'Over main dialog, top right quadrant', -
                      'Over main dialog, bottom left quadrant', 'Over main dialog, bottom right quadrant')
    rects = .array~of(clRect1, clRect2, clRect3, clRect4)
    do i = 1 to 4                                           -- ooDialog: tt~addToolRect(self, IDTOOL_DLG_RECTi, clRecti, text, 'TRANSPARENT')
        tools~append(.array~of(IDC_TT_MAIN, "IDTOOL_DLG_RECT"i, texts[i], rects[i]))
    end

    -- (.NET version) The mouse over the dialog: which quadrant; a new one
    -- hides the tip and starts the delay, after which onShow shows it.
    quadrant = 0
    delay = .net~System~Windows~Forms~Timer~new
    delay~Interval = tt~InitialDelay
    delay~Tick += .net~handler(self, "ONDELAY")
    self~form~MouseMove += .net~handler(self, "ONDIALOGMOUSE")
    self~form~MouseLeave += .net~handler(self, "ONDIALOGLEAVE")


/** onDialogMouse(), onDialogLeave(), onDelay()
 *
 * (.NET version) What a ToolTip does for the tools of a rectangle: the mouse
 * in a new quadrant hides the tip and waits; the tip shows if it stays
 * there.
 */
::method onDialogMouse unguarded
    expose tt quadrant delay clRect1 clRect2 clRect3 clRect4
    use arg form, e

    q = 0
    do i = 1 to 4
        r = value("CLRECT"i)
        if e~X >= r[1], e~X < r[3], e~Y >= r[2], e~Y < r[4] then do; q = i; leave; end
    end
    if q == quadrant then return
    quadrant = q
    tt~Hide(form)
    delay~Stop
    if q > 0 then delay~Start

::method onDialogLeave unguarded
    expose tt quadrant delay
    use arg form, e
    delay~Stop
    tt~Hide(form)
    quadrant = 0

::method onDelay unguarded
    expose tt quadrant delay tools
    delay~Stop
    if quadrant == 0 then return
    self~onShow("IDTOOL_DLG_RECT"quadrant, tt)


/** onShow()
 *
 * One of the uses of a ToolTip's SHOW event is to customize the position of
 * the window.  (.NET version: the tip is shown here, where we want it, with
 * Show(text, window, x, y): the client coordinates of the window.)
 *
 * We use this event handler to place the text for each tool in the main ToolTip
 * at the top left-hand corner of its rectangle.
 */
::method onShow unguarded
    expose clRect1 clRect2 clRect3 clRect4 tools
    use arg toolID, toolTip

    -- Determine the position for the tool about to be displayed:
    select
      when toolID == IDTOOL_DLG_RECT1 then pos = .NetPoint~new(clRect1[1], clRect1[2])
      when toolID == IDTOOL_DLG_RECT2 then pos = .NetPoint~new(clRect2[1], clRect2[2])
      when toolID == IDTOOL_DLG_RECT3 then pos = .NetPoint~new(clRect3[1], clRect3[2])
      when toolID == IDTOOL_DLG_RECT4 then pos = .NetPoint~new(clRect4[1], clRect4[2])
      otherwise pos = .NetPoint~new
    end
    -- End select

    text = ''
    do t over tools
        if t[2] == toolID then text = t[3]
    end

    -- Position the ToolTip window where we want it:
    toolTip~Show(text, self~form, pos~x, pos~y, toolTip~AutoPopDelay)   -- ooDialog: client2screen, setWindowPos

    return .true


/** onTestEnter(), onNeedText()
 *
 * (.NET version) The mouse comes onto the Test button: if its tool has no
 * text yet, onNeedText gives it (ooDialog: the NEEDTEXT event); .true keeps
 * it, so it is not asked again.
 */
::method onTestEnter unguarded
    expose ttTest pbTest tools
    use arg button, e

    if ttTest~GetToolTip(pbTest) \== '' then return
    info = .directory~new
    if self~onNeedText(IDC_PB_TEST, ttTest, info) then do
        ttTest~SetToolTip(pbTest, info~text)
        tools~append(.array~of(IDC_TT_TEST, IDC_PB_TEST, info~text))
    end

::method onNeedText unguarded
    use arg id, toolTip, info

    info~text = 'Press Test to execute a ToolTip test'
    return .true


/** onTest()
 *
 * This is the event handler for the button CLICK event.  It is invoked when the
 * 'Test' push button is pressed or clicked.
 *
 * We use this to demonstrate some of the methods of the ToolTip class.
 *
 * (.NET version) No reply: the rest would run on another thread, and a
 * Windows Forms control is used from its own.
 */
::method onTest unguarded
    expose tt ttTest pbTest count tools

    count += 1

    select
        when count == 1 then do
            do toolInfo over tools                          -- ooDialog: tt~getToolCount, tt~enumTools(i)
                if toolInfo[1] \== IDC_TT_MAIN then iterate
                say 'Tool info  id:      ' toolInfo[2]
                say 'Tool info  text:    ' toolInfo[3]
                say 'Tool info  rect:    ' toolInfo[4]~makeString("L", " ")
                say
            end
        end

        when count == 2 then do
            time = tt~AutoPopDelay                          -- ooDialog: tt~getDelayTime
            say 'Time for autopop:' time
            say

            time = tt~AutoPopDelay                          -- ooDialog: tt~getDelayTime('AUTOPOP')
            say 'Time for autopop:' time
            say

            time = tt~InitialDelay
            say 'Time for initial:' time
            say

            time = tt~ReshowDelay
            say 'Time for reshow:' time
            say
        end

        when count == 3 then do
            pos = pbTest~PointToClient(.net~System~Windows~Forms~Cursor~Position)   -- ooDialog: .Mouse~new(self)~getCursorPos, screen2client

            if pbTest~ClientRectangle~Contains(pos), ttTest~GetToolTip(pbTest) \== '' then do   -- ooDialog: ttTest~hitTestInfo(hitTool, pos)
                say 'Got hit'
                say 'Tool info  id:      ' IDC_PB_TEST
                say 'Tool info  text:    ' ttTest~GetToolTip(pbTest)
                say 'Tool info  rect:    ' pbTest~ClientRectangle~toString
                say
            end
            else do
                say 'NO hit'
                say 'Mouse at:             ' pos~toString
                say 'Test push button hwnd:' pbTest~Handle~toString
                say
            end
        end

        otherwise do
            count = 0
            say 'No test for this push.  Going to recycle.'
            say
        end
    end
    -- End select

    return

::method autoRun                       -- (.NET version) unattended: a quadrant's tip, the Test button four times; Ok
    expose tt quadrant ttTest ttEsc pbTest
    WF = .net~System~Windows~Forms
    self~onDialogMouse(self~form, WF~MouseEventArgs~new("None", 0, self~form~ClientSize~Width - 5, 5, 0))
    say "(auto) quadrant" quadrant
    self~onDelay
    self~onTestEnter(pbTest, .nil)
    say "(auto) Test's tip:" ttTest~GetToolTip(pbTest)
    say "(auto) Cancel's tip, in lines:" ttEsc~GetToolTip(self~newPushButton(IDCANCEL))~changeStr(.endOfLine, " | ")
    do 4; self~onTest; end
    self~ok


/* (.NET version) the text broken into lines no wider than width pixels, at
   spaces (a word wider stays whole), as a ToolTip with a maximum width does */
::routine wrapToWidth
    use strict arg text, font, width
    TR = .net~System~Windows~Forms~TextRenderer
    out = ''; line = ''
    do w over text~makeArray(' ')
        try = (line == '')~?(w, line w)
        if line \== '', TR~MeasureText(try, font)~Width > width then do
            out = out || line || .endOfLine
            line = w
        end
        else line = try
    end
    return out || line
