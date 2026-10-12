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


/**
 * A basic example of using the ResizingAdmin mixin class to produce a resizable
 * dialog.  The example shows that any dialog can be made resizable, simply by
 * inheriting ResizingAdmin, and doing nothing else.
 *
 * The defaults for ResizingAdmin will resize all controls in the dialog
 * proportionally.  This works well for any dialog, in that all controls will
 * show without overlap.
 *
 * (.NET version of ooDialog's resizableDialogs\ResizingAdmin\basicResize.rex,
 * on Windows Forms through oodnet.cls: rc\basicResize.rc's dialog is
 * BasicResize_IDD_RESIZABLE, from basicResizerc.cls (rc2oodnet.rex -cls), and
 * ResizingAdmin is oodnet.cls's, with ooDialog's arithmetic.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
    -- ooDialog: .application~setDefaults('O', sd'rc\basicResize.h', .false): here the ids are names

    dlg = .ResizableDlg~new                               -- ooDialog: .ResizableDlg~new(sd"rc\basicResize.rc", IDD_RESIZABLE)
    dlg~execute("SHOWTOP", IDI_DLG_OOREXX)

return 0
-- End of entry point.

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  Directives, Classes, or Routines.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::requires "basicResizerc.cls"

-- Inherit ResingAdmin, voila, the dialog is resizable.
::class 'ResizableDlg' subclass BasicResize_IDD_RESIZABLE inherit ResizingAdmin

::method autoRun unguarded                                -- (.NET version) unattended: 100 x 60 pixels larger, then back
  f = self~form
  say "(auto) resizable:" f~FormBorderStyle~string", at least" f~MinimumSize~toString
  before = self~bounds
  f~ClientSize = .net~System~Drawing~Size~new(f~ClientSize~Width + 100, f~ClientSize~Height + 60)
  say "(auto) larger:"
  do line over self~bounds; say "(auto)  " line; end
  f~ClientSize = .net~System~Drawing~Size~new(f~ClientSize~Width - 100, f~ClientSize~Height - 60)
  say "(auto) back as it was:" (self~bounds~makeString("L", "|") == before~makeString("L", "|"))
  self~ok

::method bounds private                                   -- (.NET version) each control's rectangle
  b = .array~new
  do id over .array~of(IDC_LV_MAIN, IDC_PB_TEST, IDC_GB_TEST, IDC_EDIT_NAMES, IDC_EDIT_LABELS, IDOK, IDCANCEL)
    r = self~control(id)~Bounds
    b~append(id~left(16) r~X r~Y r~Width r~Height)
  end
  return b
