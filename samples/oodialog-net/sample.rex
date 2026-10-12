/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2014 Rexx Language Association. All rights reserved.    */
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
/*--------------------------------------------------------------------------*/
/*                                                                          */
/* samples\ooDialog\sample.rex    ooDialog Samples - Main                   */
/*                                                                          */
/*--------------------------------------------------------------------------*/
/*                                                                          */
/* (.NET version, on Windows Forms through oodnet.cls: rc\sample.rc's       */
/* dialog is a class of samplerc.cls (rc2oodnet.rex -cls); its owner-drawn  */
/* buttons are oodnet.cls's bitmap buttons (installBitmapButton). The       */
/* programs it starts are this directory's ports, which are all here (the   */
/* original's ticketWizard, oodListViews, PropertySheetDemo and             */
/* treeViewCustomDraw are in subdirectories); unattended, they run so too.  */
/* The bitmaps and sounds are in resources\.)                               */
/*--------------------------------------------------------------------------*/


  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  -- Ensure we can find our resource files.
  srcDir = filespec("location", .context~package~name)   -- ooDialog: locate()

  d = .SampleDlg~new                                      -- ooDialog: .SampleDlg~new(srcDir"rc\sample.rc", 100)
  if d~initCode <> 0 then do
     return 99
  end
  d~execute("SHOWTOP")
  return 0


/*---------------------------- requires ------------------------------*/

::requires 'samplesSetup.rex'   -- (ooDialog: "ooDialog.cls" too)
::requires "samplerc.cls"

/*---------------------------- main dialog ---------------------------*/

::class 'SampleDlg' subclass Sample_100   -- ooDialog: subclass RcDialog

::method initDialog
   sd = filespec("location", .context~package~name)"resources\"   -- ooDialog: .application~srcDir (its bitmaps in bmp\)
   self~installBitmapButton(101, "VIDEO",    sd"s2arch.bmp"  ,,,,"FRAME STRETCH")
   self~installBitmapButton(102, "PET",      sd"s2anim.bmp"  ,,,,"FRAME STRETCH")
   self~installBitmapButton(103, "PHIL",     sd"s2philf.bmp" ,,,,"FRAME STRETCH")
   self~installBitmapButton(104, "GRAPHD",   sd"s2scroll.bmp",,,,"FRAME STRETCH")
   self~installBitmapButton(105, "WALKER",   sd"s2walker.bmp",,,,"FRAME STRETCH")
   self~installBitmapButton(106, "BANDIT",   sd"s2jack.bmp"  ,,,,"FRAME STRETCH")
   self~installBitmapButton(107, "USER",     sd"s2input.bmp" ,,,,"FRAME STRETCH")
   self~installBitmapButton(108, "WIZ97",    sd"s2mov.bmp"   ,,,,"FRAME STRETCH")
   self~installBitmapButton(109, "TREE",     sd"s2tree.bmp"  ,,,,"FRAME STRETCH")
   self~installBitmapButton(110, "LIST",     sd"s2list.bmp"  ,,,,"FRAME STRETCH")
   self~installBitmapButton(111, "PROGRESS", sd"s2prog.bmp"  ,,,,"FRAME STRETCH")
   self~installBitmapButton(112, "PROPERTY", sd"s2prop.bmp"  ,,,,"FRAME STRETCH")
   self~backgroundBitmap(sd"s2backg.bmp", "USEPAL")

::method video
   self~loadApp("oovideo.rex")

::method pet
   self~loadApp("AnimalGame.rex", 3000)

::method phil
   self~loadApp("oophil.rex")

::method walker
   self~loadApp("oowalk2.rex")

::method bandit
   self~loadApp("oobandit.rex", 3300)

::method graphd
   self~loadApp("oograph.rex", 3000)

::method user
   self~loadApp("oodStandardDialogs.rex", 2800)

::method wiz97
   self~loadApp("ticketWizard.rex")                       -- ooDialog: .application~srcDir"propertySheet.tabControls\ticketWizard.rex"

::method tree
   self~loadApp("treeViewCustomDraw.rex")                 -- ooDialog: .application~srcDir"controls\TreeView\treeViewCustomDraw.rex"

::method list
   self~loadApp("oodListViews.rex")                       -- ooDialog: .application~srcDir"propertySheet.tabControls\oodListViews.rex"

::method progress
   self~loadApp("oodpbar.rex")

::method property
   self~loadApp("PropertySheetDemo.rex")                  -- ooDialog: .application~srcDir"propertySheet.tabControls\PropertySheetDemo.rex"


::method cancel
   call play "byebye.wav"
   self~cancel:super
   return 0

::method ok
   self~cancel

::method help                               /* About button */
   call play "sample.wav", "YES"
   d = .TimedMessage~new("Illustration of ooDialog Function", ,
                         "Open Object Rexx ooDialog Samples", 5000)
   d~execute
   return 0

::method loadApp
   use arg appname, pauseTime = 2000
   ret = play("start.wav", "yes")
   d = .TimedMessage~new("Application will be started, please wait","Samples", pauseTime)
   d~execute

   call (filespec("location", .context~package~name)appname) .NetDialog~auto~?("auto", "")   -- ooDialog: call (appname) (.NET version: unattended, it too)

   /* make sure main window is enabled and the topmost window */
   self~enable
   self~toTheTop

::method autoRun unguarded             -- (.NET version) unattended: About, two programs, Exit
   p = self~newPushButton(101)
   say "(auto) the buttons are bitmaps:" self~getBitmapSizeX(101) "x" self~getBitmapSizeY(101) "in" p~Width "x" p~Height"; the background" (self~form~BackgroundImage \== .nil)
   self~help
   self~video
   self~progress
   say "(auto) back: enabled" self~form~Enabled
   self~cancel
