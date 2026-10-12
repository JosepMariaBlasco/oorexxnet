/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2013-2014 Rexx Language Association. All rights reserved.    */
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

/** toolBar.rex
 *
 * Very simple ToolBar example.  Just does the very minimum to show a tool bar.
 *
 * Note that most dialog editors do not have an option to add a tool bar.  This
 * can be overcome by editing the .rc file and manually adding the tool bar
 * control.  Which was done for this example.
 *
 * The tool bar is created not visible and shown after it has been set up.
 *
 * (.NET version of ooDialog's controls\ToolBar\toolBar.rex, on Windows Forms
 * through oodnet.cls: toolBar.rc's dialog is ToolBar_IDD_TBAR, from
 * toolBarrc.cls (the original uses the .rc compiled, toolBar.dll, as a
 * ResDialog). The tool bar is a .NET ToolStrip, its buttons
 * ToolStripButtons (ooDialog: TbButton), each with its Click event; a
 * ToolStrip sizes itself (autoSize) and shows tool tips by itself.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

  dlg = .ToolBarDlg~new                -- ooDialog: .ToolBarDlg~new(sd"rc\toolBar.dll", IDD_TBAR)
  dlg~execute("SHOWTOP")

return 0
-- End of entry point.

::requires "toolBarrc.cls"

::class 'ToolBarDlg' subclass ToolBar_IDD_TBAR

::method initDialog
  expose tb

  tb = self~newToolBar(IDC_TOOLBAR)

  TSB = .net~System~Windows~Forms~ToolStripButton
  tbb1 = TSB~new("Press Me Please")    -- ooDialog: .TbButton~new(IDB_PRESS, "Press Me Please", "BUTTON", "ENABLED")
  tbb2 = TSB~new("Where Am I?")
  tbb3 = TSB~new("Please Push Me")

  -- The buttons in a tool bar are just that, buttons.  (.NET version) Their
  -- Click events are connected to our methods (ooDialog:
  -- connectButtonEvent(IDB_PRESS, 'CLICKED', onPress)).
  tbb1~Click += .net~handler(self, "ONPRESS")
  tbb2~Click += .net~handler(self, "ONWHERE")
  tbb3~Click += .net~handler(self, "ONPUSH")

  -- (ooDialog: addButtons() takes an array of TbButton objects)
  tb~Items~AddRange(.array~of(tbb1, tbb2))

  -- insertButton() inserts the button to the left of the button index
  -- specified, the button with the index of 2 (ooDialog counts from 1:
  -- "Where Am I?"; .NET counts from 0)
  tb~Items~Insert(1, tbb3)             -- ooDialog: tb~insertButton(tbb3, 2)

  -- And show the tool bar (it has sized itself to its buttons).
  tb~Visible = .true                   -- ooDialog: tb~autoSize; tb~show
  tb~Focus                             -- ooDialog: tb~assignFocus

::method onPress unguarded
  title = 'ToolBar Example "Press Button"'
  msg   = 'Thanks for pressing me       '
  r = MessageDialog(msg, self~hwnd, title, 'OK', 'INFORMATION')
  return 0

::method onPush unguarded
  title = 'ToolBar Example "Push Button"'
  msg   = 'Glad you pushed me.           '
  r = MessageDialog(msg, self~hwnd, title, 'OK', 'INFORMATION')
  return 0

::method onWhere unguarded
  expose tb

  count = tb~Items~Count               -- ooDialog: tb~buttonCount
  title = 'ToolBar Example "Where Button"'
  msg   = 'I am here, the button on the far right.' || .endOfLine~copies(2) || -
          'There are' count 'buttons.  I am button 3.'
  r = MessageDialog(msg, self~hwnd, title, 'OK', 'INFORMATION')
  return 0

::method autoRun                       -- (.NET version) unattended: each button, then OK
  expose tb
  do i = 0 to tb~Items~Count - 1
    say "(auto) button" i + 1":" tb~Items[i]~Text
    tb~Items[i]~PerformClick
  end
  self~ok
