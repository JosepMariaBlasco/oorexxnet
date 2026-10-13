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
 * A simple dialog to demonstrate a .ScriptMenu.
 *
 * (.NET version of ooDialog's menus\ScriptMenuBar.rex, on Windows Forms
 * through oodnet.cls: ScriptMenuBar.rc's dialogs and its menu are classes of
 * ScriptMenuBarrc.cls (rc2oodnet.rex -cls), the menu a NetMenuBar
 * (ScriptMenuBar_IDR_MENU_LV): attachTo, then connectAllCommandEvents in
 * place of ooDialog's constructor arguments (connect, attachTo), each item
 * to the method named as its text ("Open List-View" runs 'openList-View').
 * The list view is .NET's: its Columns, Items, and CheckBoxes, GridLines,
 * FullRowSelect, Activation in place of ooDialog's extended styles.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  -- ooDialog: .application~useGlobalConstDir("O", sd"ScriptMenuBar.h"): here the ids are names

  dlg = .SimpleDialog~new                                -- ooDialog: .SimpleDialog~new(sd"ScriptMenuBar.rc", IDD_SCRIPTMENUBAR_DLG)
  if dlg~initCode <> 0 then do
    return 99
  end

  dlg~execute("SHOWTOP")

return 0

::requires "ScriptMenuBarrc.cls"

::class 'SimpleDialog' subclass ScriptMenuBar_IDD_SCRIPTMENUBAR_DLG

::method initDialog
  expose menuBar lv

  menuBar = .ScriptMenuBar_IDR_MENU_LV~new                -- ooDialog: .ScriptMenuBar~new(sd"ScriptMenuBar.rc", IDR_MENU_LV, , , .true, self)
  menuBar~attachTo(self)
  menuBar~connectAllCommandEvents

  lv = self~newListView(IDC_LV)
  lv~Columns~Add("First Name", 70, "Left")                       -- ooDialog: lv~insertColumnPX(0, "First Name", 70)
  lv~Columns~Add("Last Name", 90, "Left")
  lv~Columns~Add("Profession", 120, "Left")

  do row over .array~of(.array~of("Bill", "Gates", "Philanthropist"), .array~of("Steve", "Jobs", "Salesman"), -
                        .array~of("Ron", "McCarthy", "Plumber"), .array~of("Greg", "Allen", "Truck Driver"))
    lv~Items~Add(.net~System~Windows~Forms~ListViewItem~new(row))   -- ooDialog: lv~addRow( , , "Bill", "Gates", "Philanthropist")
  end

::method addItemsFromFile
  self~notImplemented("File -> Add Items")

::method 'openList-View'
  expose lv menuBar

  lv~Visible = .true                                     -- ooDialog: lv~show
  menuBar~check(IDM_OPEN_LIST_VIEW)
  menuBar~disable(IDM_OPEN_LIST_VIEW)

  menuBar~unCheck(IDM_CLOSE_LIST_VIEW)
  menuBar~enable(IDM_CLOSE_LIST_VIEW)

::method 'closeList-View'
  expose lv menuBar

  lv~Visible = .false                                    -- ooDialog: lv~hide
  menuBar~enable(IDM_OPEN_LIST_VIEW)
  menuBar~unCheck(IDM_OPEN_LIST_VIEW)

  menuBar~check(IDM_CLOSE_LIST_VIEW)
  menuBar~disable(IDM_CLOSE_LIST_VIEW)

::method checkBoxes
  expose lv menuBar

  if menuBar~isChecked(IDM_CHECKBOXES) then do
    lv~CheckBoxes = .false                               -- ooDialog: lv~removeExtendedStyle("CHECKBOXES")
    menuBar~unCheck(IDM_CHECKBOXES)
  end
  else do
    lv~CheckBoxes = .true                                -- ooDialog: lv~addExtendedStyle("CHECKBOXES")
    menuBar~check(IDM_CHECKBOXES)
  end


::method gridLines
  expose lv menuBar

  if menuBar~isChecked(IDM_GRID_LINES) then do
    lv~GridLines = .false
    menuBar~unCheck(IDM_GRID_LINES)
  end
  else do
    lv~GridLines = .true
    menuBar~check(IDM_GRID_LINES)
  end


::method fullRowSelect
  expose lv menuBar

  if menuBar~isChecked(IDM_FULL_ROW_SELECT) then do
    lv~FullRowSelect = .false
    menuBar~unCheck(IDM_FULL_ROW_SELECT)
  end
  else do
    lv~FullRowSelect = .true
    menuBar~check(IDM_FULL_ROW_SELECT)
  end


::method underLineWhenHot
  expose lv menuBar

  if menuBar~isChecked(IDM_UNDERLINE_HOT) then do
    lv~Activation = "Standard"                           -- ooDialog: lv~removeExtendedStyle("ONECLICKACTIVATE UNDERLINEHOT")
    menuBar~unCheck(IDM_UNDERLINE_HOT)
  end
  else do
    lv~Activation = "OneClick"                           -- (.NET: one click, the item hot under the mouse)
    menuBar~check(IDM_UNDERLINE_HOT)
  end

::method insertItem
  self~notImplemented("Operartions -> Insert Item")

::method deleteItem
  self~notImplemented("Operartions -> Delete Item")

::method EditItem
  self~notImplemented("Operartions -> Edit Item")

::method capitalizeItem
  self~notImplemented("Operartions -> Capitalize Item")

::method contents
  self~notImplemented("Help -> Contents")

::method index
  self~notImplemented("Help -> Index ...")

::method search
  self~notImplemented("Help -> Search ...")

::method about unguarded

  dlg = .AboutDialog~new                                 -- ooDialog: .AboutDialog~new(.application~srcDir"ScriptMenuBar.rc", IDD_ABOUT_DIALOG)

  dlg~execute("SHOWTOP", IDI_DLG_DEFAULT)


::method notImplemented private
  use strict arg title

  msg = title "has not been implemented yet."
  ret = MessageDialog(msg, self~hwnd, title, "OK", "INFORMATION")

::method autoRun unguarded                               -- (.NET version) unattended: the menus' items, then Exit
  expose lv menuBar
  say "(auto) menu bar:" menuBar~strip~Items~Count "popups; Open List-View checked" menuBar~isChecked(IDM_OPEN_LIST_VIEW) -
      "enabled" menuBar~isEnabled(IDM_OPEN_LIST_VIEW)
  do id over .array~of(IDM_CHECKBOXES, IDM_GRID_LINES, IDM_FULL_ROW_SELECT, IDM_UNDERLINE_HOT)
    menuBar~item(id)~PerformClick
  end
  say "(auto) list view: check boxes" lv~CheckBoxes "grid lines" lv~GridLines "full row" lv~FullRowSelect "activation" lv~Activation
  menuBar~item(IDM_GRID_LINES)~PerformClick
  say "(auto) grid lines again:" lv~GridLines "checked" menuBar~isChecked(IDM_GRID_LINES)
  menuBar~item(IDM_CLOSE_LIST_VIEW)~PerformClick
  say "(auto) closed: visible" lv~Visible", Open enabled" menuBar~isEnabled(IDM_OPEN_LIST_VIEW)
  menuBar~item(IDM_OPEN_LIST_VIEW)~PerformClick
  say "(auto) opened: visible" lv~Visible", Close enabled" menuBar~isEnabled(IDM_CLOSE_LIST_VIEW)
  do id over .array~of(IDM_ADD_ITEMS, IDM_DELETE_ITEM, IDM_INDEX, IDM_ABOUT)
    menuBar~item(id)~PerformClick
  end
  menuBar~item(IDOK)~PerformClick


::class 'AboutDialog' subclass ScriptMenuBar_IDD_ABOUT_DIALOG

::method initDialog
   expose font

   sd = filespec("location", .context~package~name)      -- ooDialog: .application~srcDir
   picture = self~newStatic(IDC_ST_BITMAP)
   bitmap = .net~System~Drawing~Image~FromFile(sd"resources\UserMenuBar.bmp")   -- ooDialog: .Image~getImage(...)
   picture~FlatStyle = "Standard"   -- (.NET version) an image: Windows Forms' drawing
   picture~Image = .net~System~Drawing~Bitmap~new(bitmap, picture~Size)        -- ooDialog: setImage (SS_REALSIZECONTROL: to the control's size)

   font = self~createFontEx("Ariel", 14)
   self~newStatic(IDC_ST_ABOUT)~Font = font              -- ooDialog: ~setFont(font)

::method leaving
   expose font
   self~deleteFont(font)
