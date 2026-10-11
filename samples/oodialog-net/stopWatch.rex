/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2013-2014 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                         */
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
/* ========================================================================= */
/* Stopwatch    a Rexx Stopwatch                                             */
/*                                                                           */
/* (.NET version of ooDialog's examples/stopWatch.rex, on Windows Forms      */
/* through oodnet.cls. The original runs its display loop on a thread of its */
/* own (REPLY, then SysSleep): here a Windows Forms timer updates the        */
/* display on the dialog's thread, and a .NET Stopwatch keeps the time. The  */
/* menu is a MenuStrip; the clipboard, .NET's Clipboard.)                    */
/* ========================================================================= */

   .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
   dlg = .StopWatchCls~new      /* Create the dialog                         */
   dlg~execute('ShowTop')       /* Create, show and run the Windows Object   */

EXIT                                                                       -->|
/* ========================================================================= */
::requires "oodnet.cls"
/* ========================================================================= */
::class StopWatchCls subclass NetDialog
/* ------------------------------------------------------------------------- */
::attribute state   unguarded           /* [Stopped,Running,Split,Splitting] */
::attribute session unguarded           /* session number                    */
::attribute events  unguarded           /* event record for clipboard        */
/* ------------------------------------------------------------------------- */
::method Init
/* ------------------------------------------------------------------------- */
   self~Init:super
   rc = self~CreateCenter(160,62,'Stopwatch -   - Stopped',,,'MS Sans Serif',8)
   self~InitCode  = (rc\=0)
   self~state     = 'Stopped'
   self~Session   = 0
   self~events    = .array~new
/* ------------------------------------------------------------------------- */
::method DefineDialog
/* ------------------------------------------------------------------------- */
   /* (.NET version) ooDialog's dlgAreaU (the whole dialog, in percentages),
      worked out: x 5, y 5, width 150, height 52                              */
   self~createEdit(      10,  5,  5, 150, 16, 'readonly center')
   self~createPushButton(11,  5, 26,  67, 20, , 'Start', 'ButtonPress')
   self~createPushButton(12, 87, 26,  67, 20, , 'Exit',  'ButtonPress')
/* ------------------------------------------------------------------------- */
::method InitDialog
/* ------------------------------------------------------------------------- */
expose el b1 b2 copyItem watch ticker
  menuBar = .net~System~Windows~Forms~MenuStrip~new
  file = self~menuItem("&File")
  file~DropDownItems~Add(self~menuItem("E&xit", "CANCEL"))
  edit = self~menuItem("&Edit")
  copyItem = self~menuItem("&Copy", "Copy2CB")
  copyItem~Enabled = .false             /* GRAYED                            */
  edit~DropDownItems~Add(copyItem)
  menuBar~Items~Add(edit)               /* the original's order: Edit, File   */
  menuBar~Items~Add(file)
  self~attachMenu(menuBar)

  b1 = self~newPushButton(11)
  b2 = self~newPushButton(12)
  /* (.NET version) MS Sans Serif, a bitmap font, shows bold in buttons;
     .NET's substitute does not                                              */
  bold = .net~System~Drawing~Font~new(b1~Font, "Bold")
  b1~Font = bold; b2~Font = bold
  el = self~newEdit(10)
  el~Text = '00:00:00.00'
  el~BackColor = .net~System~Drawing~Color~Black
  el~ForeColor = .net~System~Drawing~Color~Red  /* ooDialog's colour 13    */
  el~Font = .net~System~Drawing~Font~new('Lucida Console', .net~single(18), "Bold")
  watch = .net~System~Diagnostics~Stopwatch~new
  ticker = self~startTimer(40, 'Tick')  /* the display, 25 times a second    */
/* ------------------------------------------------------------------------- */
::Method ButtonPress UnGuarded
/* Pressing either button runs this method (.NET: the button is the sender)  */
/* ------------------------------------------------------------------------- */
expose events state session copyItem watch
   use arg button
   action = button~Text                            /* pressed button title   */
   Select
      when action='Start'  then do
         watch~Restart                             /* RESET the clock        */
         session += 1
         events~append(session '0909'x 'Start' '09'x date('s',,,'-') time())
         self~SetStateButtonsAndTitle('Running','Stop','Split','Running')
         copyItem~Enabled = .true
      end /* DO */
      when action='Stop'   then do
         events~append(session '09'x self~FormatTime(watch~Elapsed~TotalSeconds) '09'x 'Stop')
         watch~Stop
         self~SetStateButtonsAndTitle('Stopped','Start','Exit','Stopped')
      end
      when action='Resume'
         then self~SetStateButtonsAndTitle('Running','Stop','Split','Running')
      when action='Split'
         then self~SetStateButtonsAndTitle('Splitting','Resume','Split','Split Time')
      when action='Exit'   then do
         State='Stopped'
         self~OK                                             -- EXIT Dialog ->|
      end
      otherwise
   end /* select */
return
/* ------------------------------------------------------------------------- */
::method Tick UnGuarded       /* (.NET version) what the original's loop did */
/* ------------------------------------------------------------------------- */
expose el events state session watch
   if State='Running' | State='Splitting'
   then do
      ftime=self~FormatTime(watch~Elapsed~TotalSeconds)
      el~Text = ftime
      if State='Splitting'
      then do
         State='Split'
         events~append(session '09'x ftime '09'x 'Split')
      end /* DO */
   end
/* ------------------------------------------------------------------------- */
::method SetStateButtonsAndTitle private
/* ------------------------------------------------------------------------- */
expose b1 b2 state session
   use arg state, t1, t2, title
   b1~Text = t1
   b2~Text = t2
   self~SetTitle('Stopwatch -' session '-' title)
/* ------------------------------------------------------------------------- */
::method FormatTime private
/* ------------------------------------------------------------------------- */
  numeric digits 12
  t = arg(1)
  parse value format(t, , 2) with t'.'ms                  /* take off the ms */
  hh = t % 3600
  t  = t // 3600
  mm = t %  60
  ss = t // 60
return hh~right(2,'0')||':'||mm~right(2,'0')||':'ss~right(2,'0')||'.'ms~left(2)
/* ------------------------------------------------------------------------- */
::Method Cancel UnGuarded            /* stop the display on exit            */
/* ------------------------------------------------------------------------- */
expose ticker
   self~state='Stopped'
   ticker~Stop
   return self~Cancel:Super                            -- Leave the dialog -->|
/* ------------------------------------------------------------------------- */
::method Leaving                     /* (.NET version) the timer, also on OK */
/* ------------------------------------------------------------------------- */
expose ticker
   ticker~Stop
/* ------------------------------------------------------------------------- */
::method Copy2CB UnGuarded
/* ------------------------------------------------------------------------- */
expose events
  .net~System~Windows~Forms~Clipboard~SetText(events~makeString('l',.endofline))
/* ------------------------------------------------------------------------- */
::method autoRun                 /* (.NET version) unattended: start, split, stop */
/* ------------------------------------------------------------------------- */
expose b1 b2 events
  b1~PerformClick                                    /* Start                */
  call SysSleep 0.3
  self~Tick
  b2~PerformClick                                    /* Split                */
  self~Tick
  b1~PerformClick                                    /* Resume               */
  call SysSleep 0.2
  b1~PerformClick                                    /* Stop                 */
  say "Events:"; do e over events; say "  " e~changeStr('09'x, ' '); end
  b2~PerformClick                                    /* Exit                 */
