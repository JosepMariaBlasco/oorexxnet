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
 * A simple application that shows how to create an UserMenuBar menu.  The
 * dialog contains an Edit control and an UpDown control.  The menu is used to
 * change styles or behaviour of the two controls.
 *
 * About half of the menu items pop up a dialog to collect user input needed to
 * carry out the menu item action.
 *
 * This example uses a number of up-down controls in the different dialogs,
 * making it a good example of how to use up-down controls in addition, to being
 * a menu bar example.
 *
 * (.NET version of ooDialog's menus\UserMenuBar.rex, on Windows Forms through
 * oodnet.cls: UserMenuBar.rc's dialogs are classes of UserMenuBarrc.cls
 * (rc2oodnet.rex -cls); the menu bar a NetMenuBar built with ooDialog's
 * UserMenuBar methods (addPopup, addItem, addSeparator, complete), attached,
 * then each item connected to the method named as its text. A RADIO item has
 * a check mark (.NET's menu items have no bullet); a DEFAULT one is bold. An
 * up down and its buddy edit control are one NumericUpDown (the routines at
 * the end give it ooDialog's UpDown methods); its range goes from the lower
 * end to the higher (Windows' can go down). The edit control's styles UPPER
 * and LOWER are its CharacterCasing; NUMBER, which .NET's TextBox has not, is
 * a KeyPress handler refusing anything but digits.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  -- ooDialog: .application~setDefaults("O", sd"UserMenuBar.h", .false): here the ids are names

  dlg = .SimpleDialog~new                                -- ooDialog: .SimpleDialog~new(sd"UserMenuBar.rc", IDD_MAIN_DIALOG)
  if dlg~initCode <> 0 then do
    return 99
  end

  dlg~execute("SHOWTOP")

return 0

::requires "UserMenuBarrc.cls"

-- We need 10 digits to work with the numbers in the full range of an up-down
-- control (-2147,483,648 to 2,147,483,647)
::options digits 10

::class 'SimpleDialog' subclass UserMenuBar_IDD_MAIN_DIALOG

::constant DEFAULT_TEXT   "1, 2, 3, the Edit control Menu actions work better with text in the 1st edit control."
::constant WICKED_TEXT    "The wicked flee when none pursueth ..."
::constant LOTUS_TEXT     "Lotus 123 had its ups and downs."
::constant IDES_TEXT      "Ides of March - name of March 15 in Roman calendar."
::constant TITANIC_TEXT   "472 lifeboat seats not used when 1,503 people died on the Titanic."

::method init
  expose srcDir

  forward class (super) continue

  -- Grab the source dir value here and save it in an instance variable for
  -- convenience.
  srcDir = filespec("location", .context~package~name)   -- ooDialog: .application~srcDir

  if \ self~createMenuBar then do
    self~initCode = 1
    return
  end


::method initDialog
  expose menuBar edit upDown filter

  upDown = self~newUpDown(IDC_UPD)                       -- (a NumericUpDown: the up down and its buddy, IDC_EDIT_BUDDY)
  call setRange upDown, 1, 20000
  call setPosition upDown, 1000

  if \ menuBar~attachTo(self) then do
    msg = "Failed to attach menu bar"
    z = MessageDialog(msg, self~hwnd, "Menu Error", "OK", "WARNING")
  end
  menuBar~connectAllCommandEvents                        -- (.NET version) ooDialog's autoConnect (.UserMenuBar~new's 4th argument)

  edit = self~newEdit(IDC_EDIT)
  edit~Text = .SimpleDialog~DEFAULT_TEXT                 -- ooDialog: edit~setText(...)
  filter = .DigitsOnly~new                               -- (.NET version) the NUMBER style
  edit~KeyPress += .net~handler(filter, "KEYPRESS")

  self~setRadioChecks(ID_EDITCONTROL_UNRESTRICTED)


-- Creates a UserMenuBar
::method createMenuBar private
  expose menuBar

  -- Create a menu bar that has a symbolic resource ID of IDM_MENUBAR, has no
  -- help ID, uses the default menu item count, and autoconnects all command
  -- menu items when it is attached to a dialog.
  menuBar = .NetMenuBar~new                              -- ooDialog: .UserMenuBar~new(IDM_MENUBAR, , , .true)

  -- Create the menu bar template.
  menuBar~addPopup(IDM_POP_FILES, "Files")
    menuBar~addItem(ID_FILES_HIDE_EDIT, "Hide Edit Control", "DEFAULT CHECK")
    menuBar~addItem(ID_FILES_HIDE_UPDOWN, "Hide UpDown Control", " CHECK")
    menuBar~addSeparator(IDM_SEP_FILES)
    menuBar~addItem(ID_FILES_EXIT, "Exit", "END")

  menuBar~addPopup(IDM_POP_EDITCONTROL, "Edit Control")
    menuBar~addItem(ID_EDITCONTROL_LOWER, "Lower Case Only", "CHECK RADIO")
    menuBar~addItem(ID_EDITCONTROL_NUMBER, "Numbers Only", "CHECK RADIO")
    menuBar~addItem(ID_EDITCONTROL_UPPER, "Upper Case Only", "CHECK RADIO")
    menuBar~addItem(ID_EDITCONTROL_UNRESTRICTED, "No Restriction", "CHECK RADIO DEFAULT")
    menuBar~addSeparator(IDM_SEP_EDITCONTROL)
    menuBar~addItem(ID_EDITCONTROL_INSERT, "Insert Text ...")
    menuBar~addItem(ID_EDITCONTROL_SELECT, "Select Text ...", "END")

  menuBar~addPopup(IDM_POP_UPDOWNCONTROL, "UpDown Control")
    menuBar~addItem(ID_UPDOWNCONTROL_HEXIDECIMAL, "Hexidecimal", "CHECK")
    menuBar~addSeparator(IDM_SEP_UPDOWNCONTROL)
    menuBar~addItem(ID_UPDOWNCONTROL_SET_ACCELERATION, "Set Acceleration ...")
    menuBar~addItem(ID_UPDOWNCONTROL_SET_RANGE, "Set Range ...")
    menuBar~addItem(ID_UPDOWNCONTROL_SET_POSITION, "Set Position ...", "END")

  menuBar~addPopup( IDM_POP_HELP, "Help", "END")
    menuBar~addItem(ID_HELP_ABOUT, "About User Menu Bar", "END")

  if \ menuBar~complete then do
    say 'User menu bar completion error'
    return .false
  end

  return .true


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
--  The methods below, up to the next dividing lines, are the implementation
--  for each of the menu item command events.
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::method hideEditControl unguarded
  expose menuBar edit

  if menuBar~isChecked(ID_FILES_HIDE_EDIT) then do
    menuBar~uncheck(ID_FILES_HIDE_EDIT)
    self~newStatic(IDC_ST_EDIT)~Visible = .true          -- ooDialog: ~show
    edit~Visible = .true
  end
  else do
    menuBar~check(ID_FILES_HIDE_EDIT)
    self~newStatic(IDC_ST_EDIT)~Visible = .false         -- ooDialog: ~hide
    edit~Visible = .false
  end

::method hideUpDownControl unguarded
  expose menuBar upDown

  if menuBar~isChecked(ID_FILES_HIDE_UPDOWN) then do
    menuBar~uncheck(ID_FILES_HIDE_UPDOWN)
    self~newStatic(IDC_ST_UPD)~Visible = .true
    self~newEdit(IDC_EDIT_BUDDY)~Visible = .true         -- (the same NumericUpDown as upDown)
    upDown~Visible = .true
  end
  else do
    menuBar~check(ID_FILES_HIDE_UPDOWN)
    self~newStatic(IDC_ST_UPD)~Visible = .false
    self~newEdit(IDC_EDIT_BUDDY)~Visible = .false
    upDown~Visible = .false
  end

::method exit unguarded
  self~cancel


::method lowerCaseOnly unguarded
  expose menuBar edit

  alreadyChecked = menuBar~isChecked(ID_EDITCONTROL_LOWER)

  self~setRadioChecks(ID_EDITCONTROL_LOWER)
  self~editStyle("LOWER")                                -- ooDialog: edit~replaceStyle("UPPER NUMBER", "LOWER")

  text = edit~Text
  edit~Text = text~lower

  if \ alreadyChecked then do
    edit~Focus                                           -- ooDialog: edit~assignFocus
    call editSelect edit, 1, 1                           -- ooDialog: edit~select(1, 1)

    msg = "You can only enter lower case letters in" || .endOfLine || -
          "the edit control now.  Try it."
    z = MessageDialog(msg, self~hwnd, 'Edit Control Style Change', "OK", "INFORMATION")
  end


::method numbersOnly unguarded
  expose menuBar edit

  alreadyChecked = menuBar~isChecked(ID_EDITCONTROL_NUMBER)

  self~setRadioChecks(ID_EDITCONTROL_NUMBER)
  self~editStyle("NUMBER")                               -- ooDialog: edit~replaceStyle("LOWER UPPER", "NUMBER")

  text = edit~Text
  edit~Text = text~translate("", xrange("00"X, "/") || xrange(":", "FF"X))~space(0)

  if \ alreadyChecked then do
    edit~Focus
    call editSelect edit, 1, 1

    msg = "You can only enter numbers in the" || .endOfLine || -
          "edit control now.  Try it."
    z = MessageDialog(msg, self~hwnd, 'Edit Control Style Change', "OK", "INFORMATION")
  end


::method upperCaseOnly unguarded
  expose menuBar edit

  alreadyChecked = menuBar~isChecked(ID_EDITCONTROL_UPPER)

  self~setRadioChecks(ID_EDITCONTROL_UPPER)
  self~editStyle("UPPER")                                -- ooDialog: edit~replaceStyle("LOWER NUMBER", "UPPER")

  text = edit~Text
  edit~Text = text~upper

  if \ alreadyChecked then do
    edit~Focus
    call editSelect edit, 1, 1

    msg = "You can only enter upper case letters in" || .endOfLine || -
          "the edit control now.  Try it."
    z = MessageDialog(msg, self~hwnd, 'Edit Control Style Change', "OK", "INFORMATION")
  end


::method noRestriction unguarded
  expose menuBar edit

  alreadyChecked = menuBar~isChecked(ID_EDITCONTROL_UNRESTRICTED)

  self~setRadioChecks(ID_EDITCONTROL_UNRESTRICTED)
  self~editStyle("")                                     -- ooDialog: edit~removeStyle("LOWER NUMBER UPPER")

  text = edit~Text
  edit~Text = .SimpleDialog~DEFAULT_TEXT

  if \ alreadyChecked then do
    edit~Focus
    call editSelect edit, 1, 1

    msg = "You can now enter unrestricted text in" || .endOfLine || -
          "the edit control.  Try it."
    z = MessageDialog(msg, self~hwnd, 'Edit Control Style Change', "OK", "INFORMATION")
  end


::method insertText unguarded
  expose edit srcDir

  dlg = .InsertDialog~new                                -- ooDialog: .InsertDialog~new(srcDir"UserMenuBar.rc", IDD_INSERT_DIALOG, , srcDir"UserMenuBar.h")

  if dlg~execute("SHOWTOP", IDI_DLG_OODIALOG) == .NetDialog~IDOK then do
    edit~Text = dlg~selectedText
  end


::method selectText unguarded
  expose edit srcDir

  dlg = .SelectDialog~new
  dlg~currentText = edit~Text
  call editSelect edit, 1, 1

  if dlg~execute("SHOWTOP", IDI_DLG_APPICON) == .NetDialog~IDOK then do
    s = dlg~selection
    edit~Focus                                           -- (.NET version: a TextBox shows its selection while it has the focus)
    call editSelect edit, s~x, s~y
  end


::method hexidecimal unguarded
  expose menuBar upDown

  if menuBar~isChecked(ID_UPDOWNCONTROL_HEXIDECIMAL) then do
    menuBar~uncheck(ID_UPDOWNCONTROL_HEXIDECIMAL)
    upDown~Hexadecimal = .false                          -- ooDialog: upDown~setBase(10)
  end
  else do
    menuBar~check(ID_UPDOWNCONTROL_HEXIDECIMAL)
    upDown~Hexadecimal = .true                           -- ooDialog: upDown~setBase(16)
  end


::method setAcceleration unguarded
  expose upDown srcDir

  dlg = .AccelDialog~new

  if dlg~execute("SHOWTOP", IDI_DLG_APPICON2) == .NetDialog~IDOK then do
    accel = dlg~acceleration
    call setAcceleration upDown, accel                   -- ooDialog: upDown~setAcceleration(accel)
  end


::method setRange unguarded
  expose upDown srcDir

  dlg = .RangeDialog~new

  if dlg~execute("SHOWTOP", IDI_DLG_OOREXX) == .NetDialog~IDOK then do
    r = dlg~range
    call setRange upDown, r~x, r~y                       -- ooDialog: upDown~setRange(r~x, r~y)

    -- If the current position was no longer within the new range, the up-down
    -- control will have internally reset its position so that it is within the
    -- new range.  But, the value displayed will still be the old value.  This
    -- forces the value displayed to match the current position.
    call setPosition upDown, upDown~Value                -- ooDialog: upDown~setPosition(upDown~getPosition)
  end


::method setPosition unguarded
  expose upDown srcDir

  dlg = .PositionDialog~new
  dlg~upDown = upDown

  if dlg~execute("SHOWTOP", IDI_DLG_DEFAULT) == .NetDialog~IDOK then do
    p = dlg~position
    call setPosition upDown, p
  end


::method aboutUserMenuBar unguarded
  expose srcDir

  dlg = .AboutDialog~new

  dlg~execute("SHOWTOP", IDI_DLG_DEFAULT)

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
--  End of the implementation methods for each of the menu item command events.
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/



-- Convenience method to set the radio button menu items.  The checkRadio()
-- method takes a start resource ID and an end resource, and the resource ID for
-- a single menu item within that range of IDs.  It removes the radio button
-- check mark from all the menu items in the range and adds the radio button
-- check mark to item specified by the third argument.
::method setRadioChecks private
  expose menuBar
  use strict arg item

  menuBar~checkRadio(ID_EDITCONTROL_LOWER, ID_EDITCONTROL_UNRESTRICTED, item)

-- (.NET version) the edit control's style: UPPER, LOWER, NUMBER, or none
::method editStyle private
  expose edit filter
  use strict arg style

  select case style
    when "UPPER" then edit~CharacterCasing = "Upper"
    when "LOWER" then edit~CharacterCasing = "Lower"
    otherwise edit~CharacterCasing = "Normal"
  end
  filter~on = (style == "NUMBER")

::method autoRun unguarded                               -- (.NET version) unattended: every item of the menu, then Exit
  expose menuBar edit upDown
  say "(auto) menu bar:" menuBar~strip~Items~Count "popups; No Restriction checked:" menuBar~isChecked(ID_EDITCONTROL_UNRESTRICTED)
  do id over .array~of(ID_FILES_HIDE_EDIT, ID_FILES_HIDE_UPDOWN)
    menuBar~item(id)~PerformClick
  end
  say "(auto) hidden: edit visible" edit~Visible", up down visible" upDown~Visible
  do id over .array~of(ID_FILES_HIDE_EDIT, ID_FILES_HIDE_UPDOWN)
    menuBar~item(id)~PerformClick
  end
  say "(auto) shown: edit visible" edit~Visible", up down visible" upDown~Visible
  do id over .array~of(ID_EDITCONTROL_UPPER, ID_EDITCONTROL_LOWER, ID_EDITCONTROL_NUMBER)
    menuBar~item(id)~PerformClick
    say "(auto)" menuBar~item(id)~Text":" edit~Text "(casing" edit~CharacterCasing"; checked:" -
        menuBar~isChecked(ID_EDITCONTROL_LOWER) menuBar~isChecked(ID_EDITCONTROL_NUMBER) -
        menuBar~isChecked(ID_EDITCONTROL_UPPER) menuBar~isChecked(ID_EDITCONTROL_UNRESTRICTED)")"
  end
  menuBar~item(ID_EDITCONTROL_INSERT)~PerformClick
  say "(auto) inserted:" edit~Text
  menuBar~item(ID_EDITCONTROL_SELECT)~PerformClick
  say "(auto) selected:" edit~SelectionStart edit~SelectionLength "-" edit~SelectedText
  menuBar~item(ID_EDITCONTROL_UNRESTRICTED)~PerformClick
  menuBar~item(ID_UPDOWNCONTROL_HEXIDECIMAL)~PerformClick
  say "(auto) hexadecimal:" upDown~Hexadecimal upDown~Text
  menuBar~item(ID_UPDOWNCONTROL_HEXIDECIMAL)~PerformClick
  menuBar~item(ID_UPDOWNCONTROL_SET_ACCELERATION)~PerformClick
  a = ""; do acc over upDown~Accelerations; a = a acc~Seconds || "s:" || acc~Increment; end
  say "(auto) accelerations:" a~strip
  menuBar~item(ID_UPDOWNCONTROL_SET_RANGE)~PerformClick
  say "(auto) range:" upDown~Minimum".."upDown~Maximum", at" upDown~Value
  menuBar~item(ID_UPDOWNCONTROL_SET_POSITION)~PerformClick
  say "(auto) position:" upDown~Value
  menuBar~item(ID_HELP_ABOUT)~PerformClick
  menuBar~item(ID_FILES_EXIT)~PerformClick


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
--  The following classes all implement a single dialog that is used to collect
--  information, from the user, needed to carry out one of the menu item
--  commands.
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

::class 'InsertDialog' subclass UserMenuBar_IDD_INSERT_DIALOG

::attribute selectedText

::method initDialog
  self~newRadioButton(IDC_RB_WICKED)~Checked = .true     -- ooDialog: ~check

::method ok unguarded

  select
    when self~newRadioButton(IDC_RB_WICKED)~Checked then self~selectedText = .SimpleDialog~WICKED_TEXT
    when self~newRadioButton(IDC_RB_LOTUS)~Checked then self~selectedText = .SimpleDialog~LOTUS_TEXT
    when self~newRadioButton(IDC_RB_IDES)~Checked then self~selectedText = .SimpleDialog~IDES_TEXT
    when self~newRadioButton(IDC_RB_TITANIC)~Checked then self~selectedText = .SimpleDialog~TITANIC_TEXT
    otherwise self~selectedText = ""
  end
  -- End select

  self~ok:super

::method autoRun unguarded                               -- (.NET version) unattended: the third text
  self~newRadioButton(IDC_RB_IDES)~Checked = .true
  self~ok


::class 'SelectDialog' subclass UserMenuBar_IDD_SELECT_DIALOG

::attribute selection
::attribute currentText

::method initDialog
  expose updStart updEnd currentText

  self~newStatic(IDC_ST_CURRENT_TEXT)~Text = currentText

  updStart = self~newUpDown(IDC_UPD_START)
  call setRange updStart, 0, currentText~length
  call setPosition updStart, 1

  updEnd = self~newUpDown(IDC_UPD_END)
  call setRange updEnd, 0, currentText~length
  call setPosition updEnd, 1

::method ok unguarded
  expose updStart updEnd

  self~selection = .NetPoint~new(updStart~Value, updEnd~Value)   -- ooDialog: .Point~new(updStart~getPosition, ...)
  self~ok:super

::method autoRun unguarded                               -- (.NET version) unattended: characters 6 to 12
  expose updStart updEnd
  call setPosition updStart, 6
  call setPosition updEnd, 13
  self~ok



::class 'AccelDialog' subclass UserMenuBar_IDD_ACCEL_DIALOG

::attribute acceleration

::method initDialog

  upd = self~newUpDown(IDC_UPD_ACCEL_SECONDS0)
  call setPosition upd, 0
  upd~Enabled = .false                                   -- ooDialog: upd~disable
  self~newEdit(IDC_EDIT_ACCEL_SECONDS0)~Enabled = .false  -- (the same NumericUpDown)

  upd = self~newUpDown(IDC_UPD_ACCEL0)
  call setPosition upd, 1
  upd~Enabled = .false
  self~newEdit(IDC_EDIT_ACCEL0)~Enabled = .false

  do i = 1 to 3
    upd = self~newUpDown(IDC_UPD_ACCEL_SECONDS || i)
    call setRange upd, i, 32
    call setPosition upd, i

    upd = self~newUpDown(IDC_UPD_ACCEL || i)
    call setRange upd, 2 ** i, 256
    call setPosition upd, 2 ** i
  end

  self~form~ActiveControl = self~newUpDown(IDC_UPD_ACCEL_SECONDS1)   -- ooDialog: ~assignFocus


::method ok unguarded

  a = .array~new(3)

  do i = 1 to 3
    d = .directory~new

    updS = self~newUpDown(IDC_UPD_ACCEL_SECONDS || i)
    updA = self~newUpDown(IDC_UPD_ACCEL || i)

    d~seconds = updS~Value                               -- ooDialog: updS~getPosition
    d~increment = updA~Value
    a[i] = d
  end

  -- Check that the user has an unique value for each acceleration entry.
  check = .set~of(a[1]~seconds, a[2]~seconds, a[3]~seconds)
  if check~items <> 3 then do
    msg = "For each of the 3 acceleration input" || .endOfLine || -
          "lines, you must use a unique value for" || .endOfLine || -
          "seconds.  Found:" a[1]~seconds',' a[2]~seconds', and' a[3]~seconds'.'

    z = MessageDialog(msg, self~hwnd, "Acceleration Input Error", "OK", "STOP")
    return .false
  end

  -- Sort the entries by seconds, ascending, using brute force.
  max = 0; min = 4
  do i = 1 to 3
    if a[i]~seconds > max then max = i
    if a[i]~seconds < min then min = i
  end

  -- The user only has 3 up-down pairs she can set.  But, we also have the
  -- first disabled up-down pair for seconds == 0, increment == 1
  aa = .array~new(4)
  aa[1] = .directory~new~~setEntry("SECONDS", 0)~~setEntry("INCREMENT", 1)

  aa[2] = a[min]
  aa[4] = a[max]

  do i = 1 to 3
    if i \== min, i \== max then do
      aa[3] = a[i]
      leave
    end
  end

  self~acceleration = aa
  self~ok:super


::class 'RangeDialog' subclass UserMenuBar_IDD_RANGE_DIALOG

::attribute range

::method initDialog
  expose updLow updHigh

  -- Set an acceleration that goes very fast if the user hold down the arrow
  -- keys, or holds down the mouse on the up / down arrows.
  accel = .array~new(4)
  accel[1] = .directory~new~~setEntry("SECONDS", 0)~~setEntry("INCREMENT", 1)
  accel[2] = .directory~new~~setEntry("SECONDS", 1)~~setEntry("INCREMENT", 32)
  accel[3] = .directory~new~~setEntry("SECONDS", 2)~~setEntry("INCREMENT", 64)
  accel[4] = .directory~new~~setEntry("SECONDS", 3)~~setEntry("INCREMENT", 256)

  updLow = self~newUpDown(IDC_UPD_LOW)
  call setRange updLow, -2147483648, 2147483647
  call setPosition updLow, 0
  call setAcceleration updLow, accel

  updHigh = self~newUpDown(IDC_UPD_HIGH)
  call setRange updHigh, -2147483648, 2147483647
  call setPosition updHigh, 0
  call setAcceleration updHigh, accel

::method ok unguarded
  expose updLow updHigh

  self~range = .NetPoint~new(updLow~Value, updHigh~Value)
  self~ok:super

::method autoRun unguarded                               -- (.NET version) unattended: 500 down to -5 (a range the other way round)
  expose updLow updHigh
  call setPosition updLow, 500
  call setPosition updHigh, -5
  self~ok


::class 'PositionDialog' subclass UserMenuBar_IDD_POSITION_DIALOG

::attribute position
::attribute upDown

::method initDialog
  expose upDown upd

  upd = self~newUpDown(IDC_UPD_POSITION)

  call setRange upd, upDown~Minimum, upDown~Maximum      -- ooDialog: upd~setRange(upDown~getRange)
  call setPosition upd, upDown~Value                     -- ooDialog: upd~setPosition(upDown~getPosition)

::method ok unguarded
  expose upd

  self~position = upd~Value
  self~ok:super

::method autoRun unguarded                               -- (.NET version) unattended: a position past the end
  expose upd
  call setPosition upd, upd~Maximum + 1000
  self~ok


::class 'AboutDialog' subclass UserMenuBar_IDD_ABOUT_DIALOG

::method initDialog
   expose font

   sd = filespec("location", .context~package~name)      -- ooDialog: .application~srcDir
   picture = self~newStatic(IDC_ST_BITMAP)
   bitmap = .net~System~Drawing~Image~FromFile(sd"resources\UserMenuBar.bmp")   -- ooDialog: .Image~getImage(...)
   picture~FlatStyle = "Standard"   -- (.NET version) an image: Windows Forms' drawing
   picture~Image = .net~System~Drawing~Bitmap~new(bitmap, picture~Size)        -- ooDialog: setImage (SS_REALSIZECONTROL: to the control's size)

   font = self~createFontEx("Ariel", 14)
   self~newStatic(IDC_ST_ABOUT)~Font = font

::method leaving
   expose font
   self~deleteFont(font)


/* (.NET version) the NUMBER style of an edit control: only digits typed */
::class DigitsOnly
::attribute on
::method init
  self~on = .false
::method keyPress
  use arg box, e
  if \self~on then return
  c = e~KeyChar
  if c~c2d < 32 then return                              -- (Backspace, Ctrl+C...)
  if \c~dataType("W") then e~Handled = .true

/* (.NET version) ooDialog's Edit select(start, end): from character start
   to before end (EM_SETSEL start - 1, end - 1) */
::routine editSelect
  use strict arg edit, start, end
  a = max(0, min(start, end) - 1)
  b = max(0, max(start, end) - 1)
  edit~Select(min(a, edit~TextLength), min(b, edit~TextLength) - min(a, edit~TextLength))
  return 0

/* (.NET version) ooDialog's UpDown methods on a NumericUpDown */
::routine setRange                      -- the lower end to the higher (a NumericUpDown cannot go down)
  use strict arg upd, a, b
  upd~Minimum = min(a, b)               -- (a value out of the range moves into it, as Windows')
  upd~Maximum = max(a, b)
  return 0

::routine setPosition                   -- as Windows': a position out of the range is the nearest end
  use strict arg upd, pos
  upd~Value = max(upd~Minimum, min(upd~Maximum, pos))
  return 0

::routine setAcceleration               -- an Array of Directories (SECONDS, INCREMENT)
  use strict arg upd, accel
  upd~Accelerations~Clear
  do a over accel
    upd~Accelerations~Add(.net~System~Windows~Forms~NumericUpDownAcceleration~new(a~seconds, a~increment))
  end
  return 0
