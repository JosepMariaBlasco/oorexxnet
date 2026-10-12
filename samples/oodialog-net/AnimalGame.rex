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

/**
 * samples\oodialog\AnimalGame.rex    Animal Riddles (bitmaps come from a DLL.)
 *
 * This example is based on the original oopet1.rex example.  However, rather
 * than use the installBitmapButton() method it uses a Windows feature that
 * allows the programmer to assign an image list to a button.  The images in the
 * image list are bitmaps that the operating system uses to paint the button
 * face.
 *
 * This is a better way to get the same effect as installBitmapButton() because
 * the OS draws the button with the same look and feel of other buttons.  On
 * Windows 7, the buttons look like Windows 7 buttons.  Whereas with
 * installBitmapButton() the buttons look like Windows 95 buttons.
 *
 * Note: this program uses the public routine, locate(), to get the full path
 * name to the directory this source code file is located. In places, the
 * variable holding this value has been callously abbreviated to 'sd' which
 * stands for source directory.
 *
 * (.NET version, on Windows Forms through oodnet.cls: rc\AnimalGame.rc's
 * dialog (which the original loads from its compiled AnimalGame.dll) is a
 * class of AnimalGamerc.cls (rc2oodnet.rex -cls); its BITMAP resources are
 * the bitmaps of resources\ here, loaded as .NET Images. The ids are names,
 * not the .h's numbers: the edit controls, which the original counts from
 * the first id to the last, are an Array, and the data stem's tails are
 * their names. A button's image list is its Image, made transparent where
 * the original masks it; the chihuahua's pressed image is set on MouseDown
 * and put back on MouseUp. The sounds are in resources\ (samplesSetup.rex,
 * ported, puts it on the sound path).)
 *
 */

 .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
 -- Ensure this program can be executed from any directory.
 prgDir = filespec("location", .context~package~name)   -- ooDialog: locate()

 -- ooDialog: .application~useGlobalConstDir('O', prgDir'rc\AnimalGame.h'): here the ids are names

 editIDs = .array~of(IDC_EDIT_RHINO, IDC_EDIT_TIGER, IDC_EDIT_ELEPHANT, IDC_EDIT_MOOSE, -   -- ooDialog: firstEditID = .constDir[IDC_EDIT_RHINO]
                     IDC_EDIT_GOAT, IDC_EDIT_DOG, IDC_EDIT_SEAL, IDC_EDIT_HORSE)          --          lastEditID = .constDir[IDC_EDIT_HORSE]
 do i over editIDs                                     -- ooDialog: do i = firstEditID to lastEditID
    b.i = "unknown animal"
 end

 dlg = .AnimalDialog~new(b., editIDs)                  -- ooDialog: .AnimalDialog~new(prgDir"res\AnimalGame.dll", IDD_ANIMALS, b., firstEditID, lastEditID)

 if dlg~initCode \= 0 then do
   msg   = 'Failed to create dialog, aborting'
   title = 'Unexpected Error'
   ret = MessageDialog(msg, , title, 'OK', 'WARNING')
   mgr~goBack
   return 99
 end

 dlg~execute("SHOWTOP")

 return 0

/*------------------------------- requires ---------------------------*/

::requires "samplesSetup.rex"  -- Sets up the sound path (ooDialog: "ooDialog.cls" too)
::requires "AnimalGamerc.cls"

/*------------------------------- dialog class -----------------------*/

::class 'AnimalDialog' subclass AnimalGame_IDD_ANIMALS   -- ooDialog: subclass Resdialog

-- (.NET version: no EDIT_CONTROL_ID_OFFSET: the edit controls are an Array.)

-- The pixel width and height of our bitmaps.
::constant BITMAP_WIDTH              152
::constant BITMAP_HEIGHT             178

::method init
  expose editIDs bitmaps buttonIDs
  use arg dataStem., editIDs                            -- ooDialog: resFile, id, dataStem., firstEditID, lastEditID

  self~init:super(dataStem.)                           -- ooDialog: (resFile, id, dataStem.)

  imageIDs = .array~of(IDBMP_RHINO, IDBMP_TIGER, IDBMP_ELEPHANT, IDBMP_MOOSE,  -
                       IDBMP_GOAT,  IDBMP_DOG,   IDBMP_SEAL,     IDBMP_HORSE,  -
                       IDBMP_KANGURU)

  buttonIDs = .array~of(IDC_PB_RHINO, IDC_PB_TIGER, IDC_PB_ELEPHANT, IDC_PB_MOOSE,  -
                        IDC_PB_GOAT,  IDC_PB_DOG,   IDC_PB_SEAL,     IDC_PB_HORSE)

  -- Load all our bitmaps from a resource only DLL.  Since the .Size argument is
  -- omitted from the getImages() method, the operating system uses the actual
  -- size of the bitmap.
  -- (.NET version: the .rc's BITMAP files, from resources\.)
  sd = filespec("location", .context~package~name)     -- ooDialog: locate()
  files = .array~of("rhinoce", "tiger", "eleph2", "moose", "goat", "chihuahu", "sealion", "horse", "kanguru")   -- (the .rc's, in imageIDs' order)
  bitmaps = .array~new                                  -- ooDialog: .ResourceImage~new(sd'res\AnimalGame.dll')~getImages(imageIDs)
  do i = 1 to imageIDs~items
    bitmaps~append(.net~System~Drawing~Bitmap~new(sd"resources\"files[i]".bmp"))
  end

  -- Connect each button to a method with the same name as the symbolic ID of
  -- the button
  do i = 1 to buttonIDs~items
    self~connectButtonEvent(buttonIDs[i], 'CLICKED', buttonIDs[i])
  end


::method initDialog
   expose correct beenHelped bitmaps buttonIDs

   ret = Play("guess.wav", yes)

   self~configButtons(bitmaps, buttonIDs)

   correct = .array~of("rhinoceros", "tiger", "elephant", "moose", "goat", "chihuahua", "seal", "horse")
   beenHelped = .false


-- (.NET version: a button's Image, its mask colour made transparent; the
-- image list's states: the pressed image on MouseDown, the normal one back
-- on MouseUp. BS_BITMAP: the image, not the text.)
::method configButtons private
  use strict arg bitmaps, buttonIDs

  C = .net~System~Drawing~Color
  cRef   = C~FromArgb(255, 255, 153)                    -- ooDialog: .Image~colorRef(255, 255, 153)

  do i = 1 to buttonIDs~items
    button = self~newPushButton(buttonIDs[i])
    button~FlatStyle = "Standard"                       -- (an image needs it)
    button~Text = ""                                    -- (BS_BITMAP)
    button~Padding = .net~System~Windows~Forms~Padding~new(2)   -- ooDialog: margin = .Rect~new(2)
    normal = bitmaps[i]
    normal~MakeTransparent(cRef)                        -- ooDialog: il~addMasked(bitmaps[i], cRef)
    button~Image = normal                               -- ooDialog: ~setImageList(il, margin)
    if i = 6 then do
      press = bitMaps[9]
      press~MakeTransparent(C~White)                    -- ooDialog: il~addMasked(press, whiteCRef), the pressed state
      states = .NetAnimalStates~new(button, normal, press)
      button~MouseDown += .net~handler(states, "DOWN")
      button~MouseUp += .net~handler(states, "UP")
    end
  end


::method validate
   expose correct beenHelped editIDs

   -- (.NET version: no edit control ID offset: the edit controls are an Array.)

   -- Disable the Ok button until we are through.
   self~newPushButton(IDOK)~Enabled = .false             -- ooDialog: ~disable

   self~getDataStem(A.)
   wrongstr = ''

   do n = 1 to editIDs~items                             -- ooDialog: do i = firstEditID to lastEditID
      i = editIDs[n]
      if \ A.i~strip~caseLessEquals(correct[n]) then do
         wrongstr ||= '09'x || n": "A.i || .endOfLine
      end
   end
   if wrongstr = '' then do
      if \ beenHelped then ret = Play("clap.wav")

      ret = Play("yourgood.wav", "YES")

      -- Put the timed message in the center of the dialog.
      p = self~getRealPos                               -- (a NetPoint)
      s = self~getRealSize                              -- (a NetSize)
      p~incr(s~width % 2, s~height % 2)

      if beenHelped then
         ret = TimedMessage("You got them all right.... with my help ","E N D", 3000, , p)
      else
        ret = TimedMessage("You got them all right","B R A V O", 3000, , p)
      return .true
   end
   else do
      ret = Play("nope.wav")

      msg = "The following answer(s) is/are incorrect:" || .endOfLine~copies(2) || wrongstr
      title = "Incorrect Answers for the ooRexx Animal Game"
      ret = MessageDialog(msg, self~hwnd, title, 'OK', 'WARNING', 'DEFBUTTON1')

      -- We are through
      self~newPushButton(IDOK)~Enabled = .true          -- ooDialog: ~enable

      return .false
   end


::method IDC_PB_RHINO unguarded
   ret = Play("RHINO.WAV","YES")
   return self~giveHint("I only fear the 2 guys on my right", "I am strong", 2000)


::method IDC_PB_TIGER unguarded
   ret = Play("TIGER.WAV","YES")
   return self~giveHint("Hold that t...., hold that .i...", "A song about me", 2000)


::method IDC_PB_ELEPHANT unguarded
   ret = Play("ELEPHANT.WAV","YES")
   return self~giveHint("I blow my nose like a trumpet", "African Heavy Weight", 2000)


::method IDC_PB_MOOSE unguarded
   ret = Play("MOOSE.WAV","YES")
   return self~giveHint("My name rhymes with a sweet brown dessert", "Chocolate ......", 2000)


::method IDC_PB_GOAT unguarded
   ret = Play("GOAT.WAV","YES")
   return self~giveHint("My relatives climb the Matterhorn", "Mountain ....", 2000)


::method IDC_PB_DOG unguarded
   ret = Play("TAKE.WAV","YES")


::method IDC_PB_SEAL unguarded
   ret = Play("SEALION.WAV","YES")
   return self~giveHint("I am slick in the water","Hint 4 you",2000)


::method IDC_PB_HORSE unguarded
   ret = Play("HORSE.WAV","YES")
   return self~giveHint("My son won the Kentucky Derby", "Giddyup 'N Go Pony", 2000)


::method giveHint unguarded private
   use strict arg msg, title, ms

   c = .net~System~Windows~Forms~Cursor~Position
   pos = .NetPoint~new(c~X, c~Y)                         -- ooDialog: .Mouse~new(self)~getCursorPos
   pos~incr(10, 10)
   ret = TimedMessage(msg, title, ms, .true, pos)
   return 0


::method help unguarded
   expose correct beenHelped editIDs

   -- Disable the help button so that it can not be clicked until we are through
   -- here.
   self~newPushButton(IDHELP)~Enabled = .false           -- ooDialog: ~disable

   beenHelped = .true
   ret = Play("help.wav")

   do n = 1 to editIDs~items                             -- ooDialog: do i = firstEditID to lastEditID
      i = editIDs[n]
      A.i = correct[n]                                   -- ooDialog: correct[i - eos]
   end

   self~setDataStem(A.)

   -- Now enable Help again.
   self~newPushButton(IDHELP)~Enabled = .true            -- ooDialog: ~enable

::method autoRun unguarded             -- (.NET version) unattended: hints, OK (wrong), Help, OK
   expose editIDs
   say "(auto) the edit controls:" self~getControlText(editIDs[1])"; the rhino's image" self~newPushButton(IDC_PB_RHINO)~Image~Width "x" self~newPushButton(IDC_PB_RHINO)~Image~Height
   self~IDC_PB_RHINO
   self~IDC_PB_DOG
   self~setControlText(IDC_EDIT_TIGER, "Tiger")
   self~ok
   say "(auto) OK refused, still open:" self~isDialogActive
   self~help
   say "(auto) Help: the dog is a" self~getControlText(IDC_EDIT_DOG)
   self~ok

/* (.NET version) the chihuahua's button: the pressed image while pressed */
::class NetAnimalStates
::method init
   expose button normal press
   use arg button, normal, press
::method down
   expose button press
   button~Image = press
::method up
   expose button normal
   button~Image = normal
