/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2006-2014 Rexx Language Association. All rights reserved.    */
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
 *  DlgAreaDemoThree.Rex
 *
 *  Demonstrates a second approach to resizable dialogs.  Essentially what this
 *  approach does is to defer the redrawing of the dialog controls until the
 *  user has finished resizing the dialog.
 *
 *  This example is exactly like DlgAreaDemoTwo.rex, except it also demonstrates
 *  how to prevent the user from resizing the dialog smaller than a minimum
 *  size.  Look at the connectResizing() method in init() and the onResizing()
 *  method for the code that does this.
 *
 *  To better understand this example completely, please read the header
 *  comments in the DlgAreaDemoTwo.rex example.
 *
 *  (.NET version of ooDialog's resizableDialogs\DialogAreaU\dlgAreaUDemoThree.rex,
 *  on Windows Forms through oodnet.cls, whose DlgArea and DlgAreaU have
 *  ooDialog's methods and arithmetic. connectResize's method gets ooDialog's
 *  (sizingType, sizeInfo), connectSizeMoveEnded is .NET's ResizeEnd;
 *  connectResizing is WM_SIZING, seen by a NativeWindow on the form: its
 *  method gets a NetRect (ooDialog's .Rect) and the edge. The
 *  ids are names, so the .h is not needed. The buttons' methods (Button0...)
 *  are not defined: unknown gets them, as in ooDialog. A .NET TextBox does
 *  not resize itself inside: no disableInternalResize.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  -- ooDialog: .application~useGlobalConstDir("O", sd'dlgAreaUDemo.h'): here the ids are names

  dlg = .ResizableDialog~new
  dlg~execute('ShowTop')

  return 0

::requires "oodnet.cls"

::class 'ResizableDialog' subclass NetDialog

::method init

  forward class (super) continue
  success = self~createCenter(250, 250, 'My Flicker Free Resizable Dialog',     -
                                        'ThickFrame MinimizeBox MaximizeBox', , -
                                        'MS Sans Serif', 8)
  if \ success then do
    self~initCode = 1
    return
  end

  self~connectResize('onResize', .true)
  self~connectResizing('onResizing')
  self~connectSizeMoveEnded('onSizeMoveEnded')


::method defineDialog
  expose u sizing minMaximized

  u = .dlgAreaU~new(self)
  if u~lastError \= .nil then call errorDialog u~lastError

  -- Tell the DialogAreaU object to not invoke the update method.
  u~updateOnResize = .false

  -- We use these variables to track when to redraw, or not.
  sizing = .false
  minMaximized = .false

  u~noResizePut(IDC_PB_0)
  e = .dlgArea~new(u~x       , u~y       , u~w('70%'), u~h('90%'))   -- edit   area
  s = .dlgArea~new(u~x       , u~y('90%'), u~w('70%'), u~hr      )   -- status area
  b = .dlgArea~new(u~x('70%'), u~y       , u~wr      , u~hr      )   -- button area

  self~createEdit('IDC_EDIT', e~x, e~y, e~w, e~h, 'multiline')
  self~createStaticText('IDC_ST_STATUS', s~x, s~y, s~w, s~h, , 'Status info appears here')

  self~createPushButton('IDC_PB_0', b~x, b~y('00%'), b~w, b~h('9%'),          , 'Button' 0 , 'Button'||0)
  self~createPushButton('IDC_PB_1', b~x, b~y('10%'), b~w, b~h('9%'),          , 'Button' 1 , 'Button'||1)
  self~createPushButton('IDC_PB_2', b~x, b~y('20%'), b~w, b~h('9%'),          , 'Button' 2 , 'Button'||2)
  self~createPushButton('IDC_PB_3', b~x, b~y('30%'), b~w, b~h('9%'),          , 'Button' 3 , 'Button'||3)
  self~createPushButton('IDC_PB_4', b~x, b~y('40%'), b~w, b~h('9%'),          , 'Button' 4 , 'Button'||4)
  self~createPushButton('IDC_PB_5', b~x, b~y('50%'), b~w, b~h('9%'),          , 'Button' 5 , 'Button'||5)
  self~createPushButton('IDC_PB_6', b~x, b~y('60%'), b~w, b~h('9%'),          , 'Button' 6 , 'Button'||6)
  self~createPushButton('IDOK',     b~x, b~y('90%'), b~w, b~h('9%'), 'DEFAULT', 'Ok')


::method initDialog
  expose minWidth minHeight

  -- The underlying edit controls internally resize themselves as the dialog
  -- they are contained in is resized.  We don't want that, so we disable that
  -- behavior in the underlying edit control.
  -- (.NET version: nothing to disable) ooDialog: self~newEdit(IDC_EDIT)~disableInternalResize

  -- We will restrict the minimum width and minimum height to our original
  -- width and height
  minWidth = self~pixelCX
  minHeight = self~pixelCY


-- The RESIZING event happens when the user is resizing the dialog, but *before*
-- the size of the dialog is actually changed.  The first arg is a .RECT object
-- that describes the new size.  If we change the coordinates in the rectangle,
-- and reply .true.  The new size of the dialog will be our changed coordinates.
--
-- Here, if the new size is smaller than we want, we just change the rectangle
-- coordinates to our minimum size.  The 'direction' argument tells us which
-- edge of the dialog the user is dragging.  We use that to decide which
-- coordinate(s) to change.
--
-- A maximum size for the dialog could be enforced in a similar way.
::method onResizing unguarded
  expose minWidth minHeight
  use arg r, direction

  select
    when direction == 'TOP' then do
      if r~bottom - r~top < minHeight then do
        r~top = r~bottom - minHeight
        return .true
      end
    end
    when direction == 'BOTTOM' then do
      if r~bottom - r~top < minHeight then do
        r~bottom = r~top + minHeight
        return .true
      end
    end
    when direction == 'LEFT' then do
      if r~right - r~left < minWidth then do
        r~left = r~right - minWidth
        return .true
      end
    end
    when direction == 'RIGHT' then do
      if r~right - r~left < minWidth then do
        r~right = r~left + minWidth
        return .true
      end
    end
    when direction == 'BOTTOMLEFT' then do
      didChange = .false

      if r~bottom - r~top < minHeight then do
        r~bottom = r~top + minHeight
        didChange = .true
      end

      if r~right - r~left < minWidth then do
        r~left = r~right - minWidth
        didChange = .true
      end

      return didChange
    end
    when direction == 'BOTTOMRIGHT' then do
      didChange = .false

      if r~bottom - r~top < minHeight then do
        r~bottom = r~top + minHeight
        didChange = .true
      end

      if r~right - r~left < minWidth then do
        r~right = r~left + minWidth
        didChange = .true
      end

      return didChange
    end
    when direction == 'TOPLEFT' then do
      didChange = .false

      if r~bottom - r~top < minHeight then do
        r~top = r~bottom - minHeight
        didChange = .true
      end

      if r~right - r~left < minWidth then do
        r~left = r~right - minWidth
        didChange = .true
      end

      return didChange
    end
    when direction == 'TOPRIGHT' then do
      didChange = .false

      if r~bottom - r~top < minHeight then do
        r~top = r~bottom - minHeight
        didChange = .true
      end

      if r~right - r~left < minWidth then do
        r~right = r~left + minWidth
        didChange = .true
      end

      return didChange
    end
    otherwise
      nop
  end
  -- End select
  return .false

::method onResize unguarded
  expose u sizing minMaximized lastSizeInfo
  use arg sizingType, sizeinfo

  -- Save the size information so we know the final size of the dialog.
  lastSizeInfo = sizeInfo

  -- The size / move ended event does not occur when the user maximizes,
  -- minimizes, or restores from maximized / minimized.  Because of that, we
  -- need to redraw the client area under those conditions.

  if sizingType == self~SIZE_MAXIMIZED | sizingType == self~SIZE_MINIMIZED then do
    minMaximized = .true
    if sizingType == self~SIZE_MAXIMIZED then do
      u~resize(self, sizeinfo)
      self~redrawClient(.true)
    end
  end
  else if sizingType == self~SIZE_RESTORED, minMaximized then do
    minMaximized = .false
    u~resize(self, sizeinfo)
    self~redrawClient(.true)
  end
  else do
    -- We are resizing now.
    sizing = .true
  end

  return 0


::method onSizeMoveEnded unguarded
  expose u sizing lastSizeInfo

  -- If we were resizing, force the dialog controls to redraw themselves.
  if sizing then do
    u~resize(self, lastSizeInfo)
    self~redrawClient(.true)
  end

  -- We are not resizing anymore.
  sizing = .false
  return 0


::method unknown
  use arg msgName, args

  if msgName~abbrev("BUTTON") then
    self~newStatic(IDC_ST_STATUS)~Text = 'You Pressed Button' msgName~right(1)   -- ooDialog: ~setText(...)


::method autoRun unguarded                      -- (.NET version) unattended: too small (WM_SIZING), resized, maximized, restored
  expose u minWidth minHeight
  r = .NetRect~new(100, 100, 150, 150)
  say '(auto) at least' minWidth 'x' minHeight'; 50 x 50 dragged by the bottom right:' self~onResizing(r, 'BOTTOMRIGHT') r~left r~top r~right r~bottom
  M = .net~System~Runtime~InteropServices~Marshal  -- the same through the window: WM_SIZING, a RECT, the hook
  p = .net~as(M~AllocHGlobal(16), 'System.IntPtr')
  do i = 0 to 3; M~WriteInt32(p, 4 * i, .net~int32(200 + 10 * i)); end
  call sendWinIntMsg self~form, 532, 4, p          -- WMSZ_TOPLEFT
  say '(auto) WM_SIZING, 20 x 20 by the top left, became:' M~ReadInt32(p, 0) M~ReadInt32(p, 4) M~ReadInt32(p, 8) M~ReadInt32(p, 12)
  M~FreeHGlobal(p)
  f = self~form
  self~newPushButton(IDC_PB_2)~PerformClick
  say '(auto)' self~newStatic(IDC_ST_STATUS)~Text
  call show self, 'at first:'
  f~ClientSize = .net~System~Drawing~Size~new(f~ClientSize~Width * 3 % 2, f~ClientSize~Height * 3 % 2)
  call show self, '50% larger, still sizing:'
  self~onSizeMoveEnded
  call show self, 'the size ended:'
  f~WindowState = 'Maximized'
  call show self, 'maximized:'
  f~WindowState = 'Normal'
  call show self, 'restored:'
  self~ok

::routine show                                  -- (.NET version) the client area and some controls
  use arg dlg, title
  say '(auto)' title 'client' dlg~form~ClientSize~toString
  do id over .array~of(IDC_EDIT, IDC_PB_0, IDC_PB_1, IDOK)
    r = dlg~control(id)~Bounds
    say '(auto)  ' id~left(10) r~X r~Y r~Width r~Height
  end
