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


/**
 * Very, very simple example of a BinaryMenuBar.  Please use the ooDialog
 * reference manual to look up the meaning of the arguments to the methods of
 * the menu objects.
 *
 * (.NET version of ooDialog's menus\BinaryMenuBar.rex, on Windows Forms
 * through oodnet.cls: the menu bar is a NetMenuBar (a .NET MenuStrip), with
 * ooDialog's methods. The ids are names, so .constDir is not needed. ooDialog
 * attaches the bar in its constructor, while it is still empty, and fills it
 * after; here it is filled, then attached (attachTo puts it on top of the
 * dialog, which grows by its height), then connectAllCommandEvents connects
 * each item to the method named as its text, as ooDialog's does.)
 */

   .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
   -- ooDialog: .application~useGlobalConstDir('O') and the ids in .constDir: here the ids are names

   dlg = .MenuDlg~new
   dlg~execute('ShowTop')

::requires 'oodnet.cls'

::class 'MenuDlg' subclass NetDialog

::method init
   forward class (super) continue

   self~createCenter(160, 80, 'Dialog with a menu')

::method defineDialog

   text = "Choosing the 'Leave' menu item will close the dialog " -
          "with 'Cancel', the 'Exit' menu item will close with 'Ok.'"

   self~createStaticText(IDC_STATIC, 10, 10, 140, 60, , text)


::method initDialog
   expose staticText menu

   -- A subtle point here.  We can either attach automatically, or connect menu
   -- items automatically, be we can not do both.  If we attach automatically,
   -- then the menu bar is empty at this point, so there are no menu items to
   -- automatically connect.  In this case, we attach automatically, then when
   -- the menu bar is populated, we automatically connect all menu items.
   -- (.NET version: the bar is filled first, then attached.)
   menu = .NetMenuBar~new                          -- ooDialog: .BinaryMenuBar~new(.nil, IDM_MENUBAR, , self)

   subMenu = .NetPopupMenu~new(IDM_POP_HELP)
   subMenu~insertItem(IDM_MI_ABOUT, IDM_MI_ABOUT, "About")

   menu~insertPopup(IDM_POP_HELP, IDM_POP_HELP, subMenu, "Help")

   subMenu = .NetPopupMenu~new(IDM_POP_FILE)
   subMenu~insertItem(IDOK, IDOK, "Exit")
   subMenu~insertItem(IDOK, IDM_MI_LEAVE, "Leave")
   subMenu~insertItem(IDM_MI_LEAVE, IDM_MI_TEST_ITEM, "Test Item")
   subMenu~insertItem(IDM_MI_LEAVE, IDM_MI_CONTEXT, "Context")
   subMenu~insertSeparator(IDM_MI_LEAVE, IDM_SEPARATOR)

   menu~insertPopup(IDM_POP_HELP, IDM_POP_FILE, subMenu, "File")

   menu~attachTo(self)                             -- (.NET version) ooDialog attached it in new
   menu~connectAllCommandEvents

   staticText = self~newStatic(IDC_STATIC)

::method about
   expose staticText

   staticText~Text = self~getMsg("About")          -- ooDialog: staticText~setText(...)

::method testItem
   expose staticText

   staticText~Text = self~getMsg("Test Item")

::method context
   expose staticText

   staticText~Text = self~getMsg("Context")

::method leave
   expose staticText

   -- User will probably not see this blur by, so we sleep for a second.
   staticText~Text = self~getMsg("Leave")
   j = msSleep(1000)                               -- ooDialog: SysSleep(1) (msSleep: the dialog painted meanwhile)

   self~cancel:super

::method getMsg private
   use strict arg item

   return "Menu item:".endOfLine~copies(2) || '9'x || item || -
          .endOfLine~copies(2) || "was last selected."


-- We over-ride the cancel method and do nothing so that the user can only
-- close the dialog through the menu.
::method cancel unguarded
   expose staticText

   msg = "You must use the 'Leave' or 'Exit' menu items to close the dialog."
   staticText~Text = msg

::method autoRun unguarded                         -- (.NET version) unattended: the menu's items, Cancel, Leave
   expose staticText menu
   say "(auto) menu:" menu~strip~Items~Count "popups, File has" menu~item(IDM_POP_FILE)~DropDownItems~Count "items:" -
       menu~item(IDM_MI_TEST_ITEM)~Text"," menu~item(IDM_MI_CONTEXT)~Text"," menu~item(IDM_MI_LEAVE)~Text"," menu~item(IDOK)~Text
   do id over .array~of(IDM_MI_TEST_ITEM, IDM_MI_CONTEXT, IDM_MI_ABOUT)
     menu~item(id)~PerformClick
     say "(auto)" staticText~Text~changeStr(.endOfLine, " ")~changeStr('9'x, "")~space
   end
   self~cancel
   say "(auto) Cancel:" staticText~Text
   menu~item(IDM_MI_LEAVE)~PerformClick
