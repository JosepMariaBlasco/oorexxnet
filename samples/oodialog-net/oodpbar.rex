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
/****************************************************************************/
/* Name: oodpbar.rex                                                        */
/* Type: Open Object Rexx Script using ooDialog                             */
/* Resource: oodpbar.rc                                                     */
/*                                                                          */
/****************************************************************************/

/* (.NET version, on Windows Forms through oodnet.cls: rc\oodpbar.rc's
   dialog is a class of oodpbarrc.cls (rc2oodnet.rex -cls), the program's
   RcDialog its subclass. A progress bar is .NET's ProgressBar: setRange,
   setStep and setPos are its Minimum and Maximum, Step and Value; step is
   Windows' own PBM_STEPIT (sendWinIntMsg), which starts over when the bar
   is full, as ooDialog's does: .NET's PerformStep stops at the maximum.) */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
-- ooDialog: .application~useGlobalConstDir('O'): here the ids are names

myDialog = .MyDialogClass~new                           -- ooDialog: sd = locate(), .MyDialogClass~new(sd"rc\oodpbar.rc")
if myDialog~initCode = 0 then do
  rc = myDialog~execute("SHOWTOP")
end

/* Add program code here */

exit   /* leave program */


::requires "oodpbarrc.cls"   /* ooDialog: "ooDialog.cls" */

/* ---------------------------- Directives ---------------------------------*/

::class 'MyDialogClass' subclass Oodpbar_IDD_ONE   -- ooDialog: subclass RcDialog

::method init
  forward class (super) continue /* call parent constructor */
  initRet = Result

  /* Connect dialog control items to class methods. Ok, Cancel, and Help are
   * already connected by the super class init()
   */

  /* Initial values that are assigned to the object attributes */

  /* Add your initialization code here */
  return initRet


::method initDialog

  /* Initialize progress bar IDC_PBAR_A */
  curPB = self~newProgressBar("IDC_PBAR_A")
  if curPB \= .nil then do
     curPB~Minimum = 0; curPB~Maximum = 100              -- ooDialog: curPB~setRange(0,100)
     curPB~Step = 50                                     -- ooDialog: curPB~setStep(50)
     curPB~Value = 10                                    -- ooDialog: curPB~setPos(10)
  end

  /* Initialize progress bar IDC_PBAR_B */
  curPB = self~newProgressBar("IDC_PBAR_B")
  if curPB \= .nil then do
     curPB~Minimum = 0; curPB~Maximum = 100              -- ooDialog: curPB~setRange(0,100)
     curPB~Step = 40                                     -- ooDialog: curPB~setStep(40)
     curPB~Value = 20                                    -- ooDialog: curPB~setPos(20)
  end

  /* Initialize progress bar IDC_PBAR_C */
  curPB = self~newProgressBar("IDC_PBAR_C")
  if curPB \= .nil then do
     curPB~Minimum = 0; curPB~Maximum = 100              -- ooDialog: curPB~setRange(0,100)
     curPB~Step = 30                                     -- ooDialog: curPB~setStep(30)
     curPB~Value = 30                                    -- ooDialog: curPB~setPos(30)
  end

  /* Initialize progress bar IDC_PBAR_D */
  curPB = self~newProgressBar("IDC_PBAR_D")
  if curPB \= .nil then do
     curPB~Minimum = 0; curPB~Maximum = 100              -- ooDialog: curPB~setRange(0,100)
     curPB~Step = 20                                     -- ooDialog: curPB~setStep(20)
     curPB~Value = 40                                    -- ooDialog: curPB~setPos(40)
  end

  /* Initialize progress bar IDC_PBAR_E */
  curPB = self~newProgressBar("IDC_PBAR_E")
  if curPB \= .nil then do
     curPB~Minimum = 0; curPB~Maximum = 100              -- ooDialog: curPB~setRange(0,100)
     curPB~Step = 10                                     -- ooDialog: curPB~setStep(10)
     curPB~Value = 50                                    -- ooDialog: curPB~setPos(50)
  end

  /* Othe initialization Code (e.g. fill list and combo boxes) */
  return 0


::method defineDialog

  if self~initCode = 0 then do
     -- Additional dialog control items could be added here.  e.g.
     -- createEditInputGroup(), createDateTimePicker(), etc..  However, that is
     -- rarely done with a RcDialog.  It makes more sense to simply have all the
     -- controls in the resource script file.
  end


/* --------------------- event handler(s) ------------------------------------*/

  -- Method 0k is automatically connected to the button CLICK event with the
  -- resource ID of IDOK by the ooDialog framework.  In the resource script
  -- file: "rc\oodpbar.rc" the button with ID of IDOK is labeled 'step'
::method ok unguarded
  /* step each progress bar by the step set with the setStep method */
  curPB = self~newProgressBar("IDC_PBAR_A")
  call sendWinIntMsg curPB, 1029, 0, 0                   -- ooDialog: curPB~step (PBM_STEPIT)
  curPB = self~newProgressBar("IDC_PBAR_B")
  call sendWinIntMsg curPB, 1029, 0, 0                   -- ooDialog: curPB~step (PBM_STEPIT)
  curPB = self~newProgressBar("IDC_PBAR_C")
  call sendWinIntMsg curPB, 1029, 0, 0                   -- ooDialog: curPB~step (PBM_STEPIT)
  curPB = self~newProgressBar("IDC_PBAR_D")
  call sendWinIntMsg curPB, 1029, 0, 0                   -- ooDialog: curPB~step (PBM_STEPIT)
  curPB = self~newProgressBar("IDC_PBAR_E")
  call sendWinIntMsg curPB, 1029, 0, 0                   -- ooDialog: curPB~step (PBM_STEPIT)
  return 0

::method autoRun unguarded               -- (.NET version) unattended: Step three times, Help, Cancel
  do 3
    self~ok
    s = ""
    do id over .array~of("IDC_PBAR_A", "IDC_PBAR_B", "IDC_PBAR_C", "IDC_PBAR_D", "IDC_PBAR_E")
      s = s sendWinIntMsg(self~newProgressBar(id), 1032, 0, 0)   -- (PBM_GETPOS)
    end
    say "(auto) Step:" s~strip
  end
  self~help
  self~cancel

  -- Method cancel is automatically connected to resource ID IDCANCEL by the
  -- ooDialog framework.
::method cancel unguarded
  /* Calling the superclass cancel will *always* close the dialog. If you want
   * to over-ride that behavior, for example to ask the user if she is sure she
   * wants to cancel, do not call the super class cancel first.  Here, commented
   * out, is one possible over-ride.
   */

  /*
  text = 'There are unsaved changes, are you'.endOfLine'sure you want to cancel?'
  title = "Abort All Changes !"
  ret = MessageDialog(text, self~hwnd, title, "YESNO", "WARNING", "DEFBUTTON2")
  say 'ret' ret 'self~IDYES:' self~IDYES
  if ret == self~IDYES then return self~cancel:super
  else return 1
  */

  return self~cancel:super

  -- Method help() is automatically connected to resource ID IDHELP by the
  -- ooDialog framework. The super class does nothing, you need to over-ride
  -- this method to actually do anything.
::method help unguarded

  text = "There is no help for oodpbar.rex"
  title = "The ooDialog ProgressBar Example"

  ret = MessageDialog(text, self~hwnd, title, "OK", "EXCLAMATION")

  return 0

