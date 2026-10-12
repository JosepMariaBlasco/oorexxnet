/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2014 Rexx Language Association. All rights reserved.    */
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
 *  oowalk2.rex  Animation demonstration (using a compiled binary resource
 *  for the dialog template.  A DLL file.)
 *
 *  The only real difference between this sample and the oowalker.rex sample is
 *  the way the bitmaps for the animation are loaded.  Look at the initDialog()
 *  method of the .WalkerDialog to see this difference.
 *
 *  An animated button is used to simulate a man walking across the dialog.  The
 *  user can adjust the pace of the waling by setting the amount the man is
 *  moved each time the button is redrawn and the delay between redrawing the
 *  button.  The button is drawn using a sequence of bitmaps that show the man
 *  with different leg and arm positions.  The user can also set how the man
 *  'walking' off the edge of the dialog is handled, smoothly or bouncy, by
 *  using the "smooth corner wrap" check box.
 *
 *  A 'got cha' point (!!!) is periodically drawn and if the man is close enough
 *  to this 'danger,' the man is 'gotten' and the animation is stopped.  Each
 *  time the button is drawn, the !!! is over-drawn, so the !!! is only seen
 *  as a flicker.
 *
 *  Normally the dialog ends when the walker is gotten.  However there is a
 *  check box that allows the user to cancel this behavior and then restart the
 *  animation.
 *
 *  (.NET version, on Windows Forms through oodnet.cls: the dialog of
 *  rc\walker.rc (which the original loads from its compiled oowalk2.dll) is
 *  a class of walkerrc.cls (rc2oodnet.rex -cls); there being no DLL, its
 *  BITMAP resources ID_BMP_FIG1 to ID_BMP_FIG8 are their files, in
 *  resources\, loaded into an Array as oowalker.rex loads them. The
 *  animated button is ooDialog's AnimatedButton class (AnimatedButton.cls
 *  here, unchanged), on oodnet.cls's bitmap button. As the original's, the
 *  walker runs on a thread of its own: the dialog methods it calls run on
 *  the dialog's thread, as oodnet.cls sends them there; from there the
 *  controls are read and set with getControlText, setControlText,
 *  getControlData, setControlData, enableControl and disableControl.)
 */

 .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
 srcDir = filespec("location", .context~package~name)   -- ooDialog: locate()
 -- ooDialog: .application~setDefaults('O', srcDir'rc\walker.h', .false): here the ids are names

 dlg = .WalkerDialog~new                                 -- ooDialog: .WalkerDialog~new(srcDir'res\oowalk2.dll', IDD_WALKER)

 if dlg~initCode \= 0 then do
   mgr~goBack
   return 99
 end
 dlg~execute("SHOWTOP")

 return

/*---------------------------- requires -----------------------------*/

::requires "samplesSetup.rex"   -- (ooDialog: "ooDialog.cls" too)
::requires "walkerrc.cls"
::requires "AnimatedButton.cls"

/*---------------------------- walker dialog ------------------------*/

::class 'WalkerDialog' subclass Walker_IDD_WALKER   -- ooDialog: subclass ResDialog

::method initDialog
   expose bitmaps spriteButton quitCheckBox restartButton okButton

   -- Make button IDC_DRAW_BUTTON a bitmap button.  Bitmap buttons are owner-
   -- drawn and ooDialog will manage the 'drawing' of the button by painting a
   -- series of bitmaps on the button, using the AnimatedButton class.
   self~installBitmapButton(IDC_DRAW_BUTTON, '', 0);

   -- The bitmaps are loaded from the resource DLL by specifying their resouce
   -- IDs in the DLL file, res\oowalk2.dll.
   --
   -- We use symbolic IDs for the  bitmaps, and we assigned the IDs in order.
   -- In the new() method, the 2nd arg is the first bitmap ID and the 3rd is the
   -- last bitmap ID and they are assumed to be in order.  The AnimatedButton
   -- class was never updated to accept symbolic IDs, so we need to convert the
   -- IDs to numeric IDs
   -- (.NET version: no DLL: walker.rc's BITMAP resources, ID_BMP_FIG1 to
   -- ID_BMP_FIG8, are its files, loaded into an Array, which AnimatedButton
   -- takes as well: ooDialog's bmpFirst = .constDir[ID_BMP_FIG1], bmpLast =
   -- .constDir[ID_BMP_FIG8], .WalkButton~new(IDC_DRAW_BUTTON, bmpFirst, bmpLast, ...))
   sd = filespec("location", .context~package~name)
   bitmaps = .array~new(8)
   do i = 1 to 8                                          -- ID_BMP_FIG1 BITMAP "..\bmp\wlkfig1.bmp" ...
      bitmaps[i] = self~loadBitmap(sd"resources\wlkfig"i".bmp")
   end
   spriteButton = .WalkButton~new(IDC_DRAW_BUTTON, bitmaps, 0, 10, 2, 70, 120, 60, 10, 10, self)

   -- Use 'bouncy' operation when hitting edges.
   spriteButton~setSmooth(.false)

   -- Size of the step through the bitmap IDs.
   spriteButton~setstep(1)

   -- Get things set up.
   self~connectButtonEvent(IDC_PB_RESTART, "CLICKED", onRestart)

   quitCheckBox  = self~newCheckBox(IDC_CB_GOTCHA)
   restartButton = self~newPushButton(IDC_PB_RESTART)
   okButton      = self~newPushButton(IDOK)

   quitCheckBox~Checked = .true                            -- ooDialog: ~check
   spriteButton~fillData(data.)
   spriteButton~suspendGotCha(.false)
   self~doValueStemSet(data.)
   ret = Play("tada.wav", n)                               -- ooDialog: Play(srcDir"tada.wav", n) (srcDir unset there: the sound path)

   -- Animate the button.
   spriteButton~run

-- (.NET version: called from the walker's thread: getControlText and kin,
-- which run on the dialog's, where the original uses the controls' getText...)
::method doValueStemGet unguarded
  use strict arg data.
  data.IDC_EDIT_MOVEX = self~getControlText(IDC_EDIT_MOVEX)   -- ooDialog: self~newEdit(IDC_EDIT_MOVEX)~getText
  data.IDC_EDIT_MOVEY = self~getControlText(IDC_EDIT_MOVEY)
  data.IDC_EDIT_DELAY = self~getControlText(IDC_EDIT_DELAY)
  if self~getControlData(IDC_CB_SMOOTH) == 1 then data.IDC_CB_SMOOTH = 1   -- ooDialog: ~checked
  else data.IDC_CB_SMOOTH = 0

::method doValueStemSet unguarded
  use strict arg data.
  self~setControlText(IDC_EDIT_MOVEX, data.IDC_EDIT_MOVEX)    -- ooDialog: self~newEdit(IDC_EDIT_MOVEX)~setText(...)
  self~setControlText(IDC_EDIT_MOVEY, data.IDC_EDIT_MOVEY)
  self~setControlText(IDC_EDIT_DELAY, data.IDC_EDIT_DELAY)
  if data.IDC_CB_SMOOTH == 1 then self~setControlData(IDC_CB_SMOOTH, 1)   -- ooDialog: ~check
  else self~setControlData(IDC_CB_SMOOTH, 0)              -- ooDialog: ~uncheck

::method onGotCha
   expose okButton
   use strict arg animatedButton, x, y
   self~disableControl(IDOK)                               -- ooDialog: okButton~disable (from the walker's thread)
   self~writetoButton(IDC_DRAW_BUTTON, x, y, "Got-cha", "Arial", 28, "BOLD")
   ret = play('gotcha.wav')
   animatedButton~stop
   call msSleep 1000

::method maybeQuit
   expose quitCheckBox restartButton okButton
   if quitCheckBox~Checked then return self~ok             -- ooDialog: ~checked

   self~enableControl(IDC_PB_RESTART)                      -- ooDialog: restartButton~enable (from the walker's thread)
   self~enableControl(IDOK)                                -- ooDialog: okButton~enable

::method onRestart
   expose spriteButton restartButton
   restartButton~Enabled = .false                          -- ooDialog: ~disable
   spriteButton~stopped = .false

   -- Suspend the 'GotCha' before we start the animated button.  Otherwise the
   -- walker will be 'gotten' as soon as he starts.
   spriteButton~suspendGotCha(.true)
   spriteButton~run

   -- Give the walker time to 'walk' out of the danger zone before reactivating
   -- the 'GotCha.'
   delay = self~newEdit(IDC_EDIT_DELAY)~Text              -- ooDialog: ~getText
   j = msSleep(2 * delay)
   spriteButton~suspendGotCha(.false)

::method ok unguarded
   self~stopAnimation
   return self~ok:super

::method cancel unguarded
   self~stopAnimation
   return self~cancel:super

::method autoRun unguarded             -- (.NET version) unattended: the walker walks, smoothly, then OK
   expose spriteButton
   call msSleep 2500
   p = .NetPoint~new; self~getBitmapPosition(IDC_DRAW_BUTTON, p)
   say "(auto) walking:" spriteButton~isRunning", at" p~x p~y"; move" self~getControlText(IDC_EDIT_MOVEX) self~getControlText(IDC_EDIT_MOVEY)", delay" self~getControlText(IDC_EDIT_DELAY)
   self~setControlData(IDC_CB_SMOOTH, 1)
   call msSleep 1500
   q = .NetPoint~new; self~getBitmapPosition(IDC_DRAW_BUTTON, q)
   say "(auto) smooth corner wrap: moved" (q~x \= p~x | q~y \= p~y)
   self~ok
   say "(auto) OK: running" spriteButton~isRunning

::method stopAnimation private
   expose bitmaps spriteButton
   spriteButton~stop

   -- Wait until the animation sequence is finished.
   do while spriteButton~isRunning
     j = msSleep(30)
   end


/*------------------------------ animated button --------------------*/

::class 'WalkButton' subclass AnimatedButton

::method run unguarded
   expose xDanger yDanger running
   xDanger = 300; yDanger = 70; running = .true

   reply 0

   do until self~stopped | self~parentStopped
      self~doAnimatedSequence
   end

   -- Have the walker do one more sequence, gives the appearance of walking 'in
   -- place.'
   self~doAnimatedSequence

   -- We are no longer running, tell the parent dialog to maybe quit.
   running = .false
   self~parentDlg~maybeQuit

::method doAnimatedSequence private unguarded
   expose xDanger yDanger

   self~parentDlg~doValueStemGet(data.)
   do k over data.
      if \ data.k~datatype('N') then data.k = 0
   end
   self~moveseq
   self~setmove(data.IDC_EDIT_MOVEX, data.IDC_EDIT_MOVEY)
   self~setdelay(data.IDC_EDIT_DELAY)
   self~setsmooth(data.IDC_CB_SMOOTH)
   if \ self~stopped then
      self~parentDlg~writetoButton(IDC_DRAW_BUTTON,xDanger,yDanger,"!!!","Arial",20,"BOLD")

::method isRunning unguarded
   expose running
   return running

::method suspendGotCha unguarded
   expose gotCha
   use strict arg suspend
   if suspend then gotCha = .false
   else gotCha = .true

::method hitright
   ret = play('ding.wav', 'YES')
   return 1

::method hitleft
   ret = play('ding.wav', 'YESY')
   return 1

::method hitbottom
   self~getsprite(s.)
   ret = play('chord.wav', 'YES')
   s.movey = -s.movey
   self~setsprite(s.)
   self~fillData(data.)
   self~parentDlg~doValueStemSet(data.)
   return 0

::method hittop
   expose sprite.
   self~getsprite(s.)
   ret = play('chimes.wav', 'YES')
   s.movey = -s.movey
   self~setsprite(s.)
   self~fillData(data.)
   self~parentDlg~doValueStemSet(data.)
   return 0

::method fillData
   expose quitCheckBox
   use arg data.
   if \ quitCheckBox~isA(.NetObject) then quitCheckBox = self~parentDlg~newCheckBox(IDC_CB_GOTCHA)   -- ooDialog: .CheckBox
   self~getSprite(msprite.)
   data.IDC_EDIT_MOVEX = msprite.movex
   data.IDC_EDIT_MOVEY = msprite.movey
   data.IDC_EDIT_DELAY = msprite.delay
   data.IDC_CB_SMOOTH = msprite.smooth

   if quitCheckBox~Checked then data.IDC_CB_GOTCHA = 1     -- ooDialog: ~checked
   else data.IDC_CB_GOTCHA = 0

::method movepos
   use arg px, py
   if \ self~stopped then do
      self~movepos:super(px,py)
      self~checkDanger
   end

::method checkDanger
   expose xDanger yDanger gotCha
   self~getpos(cur.)
   if abs(cur.x+10-xDanger) <= 10 & abs(cur.y+55-yDanger) <= 30 then do
      if gotCha then self~parentDlg~onGotCha(self, xDanger-50, yDanger)
   end
