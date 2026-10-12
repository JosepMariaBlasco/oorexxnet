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
/**
 * Name: employe7.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\employe7.rex, on Windows Forms through
 * oodnet.cls: employe8.rc's dialog is Employe8_100, from employe8rc.cls. The
 * Add button's image list is a .NET ImageList (white transparent), the
 * dialog's background bitmap the form's BackgroundImage; both bitmaps are the
 * original's, next to this program.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
dlg = .MyDialogClass~new                                 -- ooDialog: .MyDialogClass~new(sd"employe8.rc", 100)
if dlg~initCode <> 0 then exit
dlg~execute("SHOWTOP")

exit

::requires "employe8rc.cls"

::class MyDialogClass subclass Employe8_100

::attribute employees
::attribute empCount
::attribute empCurrent

::method init
    expose sd

    forward class (super) continue
    if self~initCode <> 0 then return self~initCode

    sd = filespec("location", .context~package~name)   -- ooDialog: .application~srcDir

    self~employees = .array~new(10)
    self~empCount = 1
    self~empCurrent = 1
    self~connectButtonEvent(10, "CLICKED", "print")
    self~connectUpDownEvent(11, "DELTAPOS", onEmpChange)

    -- The 'Add' button in this dialog will use an image list to display a
    -- bitmap for the surface of the button, rather than text.  The image list
    -- is created now and assigned to the button in initDialog()
    self~createImageList
    self~connectButtonEvent(12, "CLICKED", "add")

    -- Using a background bitmap for the dialog is a rather archic method, left
    -- over from the previous millenium.  It is seldom seen in modern dialogs.
    -- Most likely you will not find the appearance of this dialog very
    -- appealing.
    self~form~BackgroundImage = .net~System~Drawing~Image~FromFile(sd"logo.bmp")   -- ooDialog: self~backgroundBitmap(sd"logo.bmp")

    return self~initCode


::method createImageList private
    expose imageList sd

    imageList = .net~System~Windows~Forms~ImageList~new    -- ooDialog: .ImageList~create(.Size~new(45, 41), 'COLOR8 MASK', 1)
    imageList~ImageSize = .net~System~Drawing~Size~new(45, 41)
    imageList~ColorDepth = "Depth8Bit"

    imageList~TransparentColor = .net~System~Drawing~Color~White      -- ooDialog: .Image~colorRef(255, 255, 255)
    imageList~Images~Add(.net~System~Drawing~Image~FromFile(sd'add.bmp'))   -- ooDialog: addMasked(image, cRef)


::method initDialog
    expose imageList

    self~city = "New York"
    self~male = 1
    self~female = 0
    self~addComboEntry(22, "Munich")
    self~addComboEntry(22, "New York")
    self~addComboEntry(22, "San Francisco")
    self~addComboEntry(22, "Stuttgart")
    self~addListEntry(23, "Business Manager")
    self~addListEntry(23, "Software Developer")
    self~addListEntry(23, "Broker")
    self~addListEntry(23, "Police Man")
    self~addListEntry(23, "Lawyer")

    -- Assign the image list to the 'Add' button.
    button = self~newPushButton(12)                   -- ooDialog: setImageList(imageList, .Rect~new(2))
    button~Text = ""
    button~FlatStyle = "Standard"                      -- (oodnet's buttons are drawn by Windows, which shows no ImageList)
    button~ImageList = imageList
    button~ImageIndex = 0


::method onEmpChange
    use arg curPos, increment

    if increment > 0 then self~empNext
    else self~empPrev

    return 0                                          -- ooDialog: .UpDown~deltaPosReply


::method print
    self~getData

    if self~male = 1 then title = "Mr."
    else title = "Ms."
    if self~married = 1 then addition = " (married) "
    else addition = ""

    call infoDialog title self~name addition || "A"x || "City:" self~city || "A"x ||  -
                     "Profession:" self~name

::method add
    self~employees[self~empCount] = .directory~new
    self~employees[self~empCount]['NAME'] = self~getControlData(21)
    self~employees[self~empCount]['CITY'] = self~getControlData(22)
    self~employees[self~empCount]['PROFESSION'] = self~getControlData(23)

    if self~getControlData(31) = 1 then sex = 1
    else sex = 2
    self~employees[self~empCount]['SEX'] = sex

    self~employees[self~empCount]['MARRIED'] = self~getControlData(41)
    self~empCount = self~empCount + 1
    self~empCurrent = self~empCount
    self~setControlData(21, "");

    upDown = self~newUpDown(11)                       -- ooDialog: setRange(1, self~empCount)
    upDown~Minimum = 1
    upDown~Maximum = self~empCount
    upDown~Value = self~empCount                      -- ooDialog: setPosition(self~empCount)


::method set
    self~setControlData(21, self~employees[self~empCurrent]['NAME'])
    self~setControlData(22, self~employees[self~empCurrent]['CITY'])
    self~setControlData(23, self~employees[self~empCurrent]['PROFESSION'])

    if self~employees[self~empCurrent]['SEX'] = 1 then do
       self~setControlData(31, 1)
       self~setControlData(32, 0)
    end
    else do
       self~setControlData(31, 0)
       self~setControlData(32, 1)
    end

    self~setControlData(41, self~employees[self~empCurrent]['MARRIED'])

::method empPrev
   if self~empCount = 1 then return
   if self~empCurrent > 1 then do
       self~empCurrent = self~empCurrent - 1
       self~newUpDown(11)~Value = self~empCount       -- ooDialog: setPosition(self~empCount)
       self~set
   end
   else do
       call TimedMessage "You reached the bottom.", "Info", 1000
   end

::method empNext
   if self~empCount = 1 then return
   if self~empCurrent < self~empCount-1 then do
       self~empCurrent = self~empCurrent + 1
       self~newUpDown(11)~Value = self~empCount       -- ooDialog: setPosition(self~empCount)
       self~set
   end
   else do
       call TimedMessage "You reached the top.", "Info", 1000
   end

::method autoRun                         -- (.NET version) unattended: two employees, then back to the first
    self~name = "John Smith"; self~profession = "Broker"
    self~newPushButton(12)~PerformClick
    self~name = "Jane Doe"; self~city = "Munich"; self~female = 1
    self~newPushButton(12)~PerformClick
    self~onEmpChange(0, -1); self~onEmpChange(0, -1)
    say "(auto) showing" self~empCurrent":" self~name "of" self~city
    say "(auto) Add's image:" self~newPushButton(12)~ImageList~Images~Count "image," self~form~BackgroundImage~Width"x"self~form~BackgroundImage~Height "background"
    self~ok
