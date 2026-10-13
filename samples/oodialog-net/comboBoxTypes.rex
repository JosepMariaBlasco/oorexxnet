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
 *  There are 3 types of combo boxes: simple, drop down, and drop down list.
 *  This example shows a dialog with 3 combo boxes, one of each kind.  It is
 *  mostly meant to show the difference in the 3 types to allow an ooDialog
 *  programmer to pick the type to use for a program.
 *
 *  One thing about combo boxes is that a combo box is not a single control.  It
 *  is a mix of several controls, an edit control and a listbox and a button.
 *  For the combo box, ooDialog provides the setFullColor() method which sets
 *  the color for the entire combo box.  This example also demonstrates that
 *  method, along with the removeFullColor() method.
 *
 * (.NET version of ooDialog's controls\ComboBox\comboBoxTypes.rex, on Windows
 * Forms through oodnet.cls: comboBoxTypes.rc's dialog is
 * ComboBoxTypes_IDD_COMBOBOX_TYPES, from comboBoxTypesrc.cls. A .NET ComboBox
 * is one control: its BackColor and ForeColor colour all of it
 * (setFullColor), ResetBackColor and ResetForeColor give it its own back
 * (removeFullColor); a colour is a System.Drawing.Color (.Image~colorRef).
 * selectIndex(1) is SelectedIndex 0 (.NET counts from 0); openDropDown and
 * closeDropDown are DroppedDown. A clicked radio button is its event's
 * sender, whose Name is its id.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .ComboBoxTypes~new           -- ooDialog: .ComboBoxTypes~new(sd"comboBoxTypes.rc", IDD_COMBOBOX_TYPES)
    if dlg~initCode = 0 then do
      dlg~execute("SHOWTOP")
    end
    else do
      say "Problem creating the dialog.  Init code:" dlg~initCode
      return 99
    end

    return 0
-- End of entry point.

::requires "comboBoxTypesrc.cls"

::class 'ComboBoxTypes' subclass ComboBoxTypes_IDD_COMBOBOX_TYPES

-- Normally an init() method for a RcDialog subclass is not used, it is really
-- not needed.  Here though it is used to do some set up stuff.  Everything done
-- here could just as well have been done in initDialog()
::method init
    expose mediumSpringGreen gold midnightBlue fireBrickRed colors animals fruits
    forward class (super) continue

    -- Create the color values to be used by the setFullColor() (.NET version:
    -- BackColor and ForeColor)
    C = .net~System~Drawing~Color
    mediumSpringGreen =  C~FromArgb(0, 238, 118)    -- ooDialog: .Image~colorRef(0, 238, 118)
    gold              =  C~FromArgb(255, 215, 0)
    midnightBlue      =  C~FromArgb(47, 47, 79)
    fireBrickRed      =  C~FromArgb(205, 38, 38)

    -- Connect the button clicks
    self~connectButtonEvent(IDC_PB_DROP, 'CLICKED', onDrop)
    self~connectButtonEvent(IDC_PB_CLOSE, 'CLICKED', onClose)

    self~connectButtonEvent(IDC_RB_NONE, 'CLICKED', onSchemeChange)
    self~connectButtonEvent(IDC_RB_RAINBOW, 'CLICKED', onSchemeChange)
    self~connectButtonEvent(IDC_RB_TEXTONLY, 'CLICKED', onSchemeChange)
    self~connectButtonEvent(IDC_RB_FIREBRICK, 'CLICKED', onSchemeChange)

    -- Create arrays of the items to be inserted into each combo box.
    colors  = .array~of("Green", "Blue", "Yellow", "Orange", "Red", "Pink")
    animals = .array~of("Horse", "Cow", "Dog", "Pig", "Cat", "Sheep")
    fruits  = .array~of("Apple", "Peach", "Pear", "Cherry", "Raspberry", "Banna")


-- Typical initDialog() method.  We just populate the combo boxes and check the
-- radio button that matches how we start up, no colors set for the combo boxes.
::method initDialog
    expose cbSimple cbDropDown cbDropDownList colors animals fruits

    cbSimple = self~newComboBox(IDC_CB_SIMPLE)          -- ooDialog: self~getComboBox(IDC_CB_SIMPLE)
    do c over colors
      cbSimple~Items~Add(c)                             -- ooDialog: cbSimple~add(c)
    end
    cbSimple~SelectedIndex = 0                          -- ooDialog: cbSimple~selectIndex(1)

    cbDropDown = self~newComboBox(IDC_CB_DROPDOWN)
    do a over animals
      cbDropDown~Items~Add(a)
    end
    cbDropDown~SelectedIndex = 0

    cbDropDownList = self~newComboBox(IDC_CB_DROPDOWNLIST)
    do f over fruits
      cbDropDownList~Items~Add(f)
    end
    cbDropDownList~SelectedIndex = 0

    self~newRadioButton(IDC_RB_NONE)~Checked = .true


-- This is the event handler for the radio buttons that select the color scheme.
-- We just check which radio button was clicked and do the appropriate thing.
::method onSchemeChange unguarded
    expose mediumSpringGreen gold midnightBlue fireBrickRed cbSimple cbDropDown cbDropDownList
    use arg sender, e                                   -- (.NET version) ooDialog: use arg id

    caseOf = sender~Name
    select case caseOf                                   -- (not the expression itself: ooRexx bug, SELECT CASE: #2114)
      when "IDC_RB_NONE" then do
          do cb over .array~of(cbSimple, cbDropDown, cbDropDownList)   -- ooDialog: removeFullColor
            cb~ResetBackColor
            cb~ResetForeColor
          end
      end

      when "IDC_RB_RAINBOW" then do
          call setFullColor cbSimple, midnightBlue, gold
          call setFullColor cbDropDown, mediumSpringGreen, fireBrickRed
          call setFullColor cbDropDownList, fireBrickRed, gold
      end

      when "IDC_RB_TEXTONLY" then do
          call setFullColor cbSimple, , gold
          call setFullColor cbDropDown, , mediumSpringGreen
          call setFullColor cbDropDownList, , fireBrickRed
      end

      when "IDC_RB_FIREBRICK" then do
          call setFullColor cbSimple, fireBrickRed, gold
          call setFullColor cbDropDown, fireBrickRed, gold
          call setFullColor cbDropDownList, fireBrickRed, gold
      end

      otherwise nop
    end
    -- End select

    return 0

-- This is the event handler for the Close Up push button.  It is meant to close
-- the opened combo boxes.  The reality is, as soon as a combo box loses the
-- focus it closes up.
::method onClose
    expose cbDropDown cbDropDownList

    cbDropDown~DroppedDown = .false                     -- ooDialog: cbDropDown~closeDropDown
    cbDropDownList~DroppedDown = .false
    return 0

-- This is the event handler for th Drop Down push button.  It is meant to drop
-- down both combo boxes.  Only one combo box can be dropped down at any time.
::method onDrop
    expose cbDropDown cbDropDownList

    cbDropDown~DroppedDown = .true                      -- ooDialog: cbDropDown~openDropDown
    cbDropDownList~DroppedDown = .true
    return 0

::method autoRun                       -- (.NET version) unattended: each scheme, a drop down, then Done
    expose cbSimple cbDropDown cbDropDownList
    do id over .array~of(IDC_RB_RAINBOW, IDC_RB_TEXTONLY, IDC_RB_FIREBRICK, IDC_RB_NONE)
      rb = self~newRadioButton(id)
      rb~PerformClick
      say "(auto)" rb~Text":" cbSimple~BackColor~Name"/"cbSimple~ForeColor~Name cbDropDownList~BackColor~Name"/"cbDropDownList~ForeColor~Name
    end
    self~onDrop
    say "(auto) dropped:" cbDropDownList~DroppedDown "-" cbSimple~Text cbDropDown~Text cbDropDownList~Text
    self~onClose
    self~ok

/* (.NET version) setFullColor([back] [, fore]): a combo box's colours, as
   ooDialog's method; an omitted one stays */
::routine setFullColor
    use arg cb, back, fore
    if arg(2, "E") then cb~BackColor = back
    if arg(3, "E") then cb~ForeColor = fore
