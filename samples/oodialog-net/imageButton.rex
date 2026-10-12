/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2008-2014 Rexx Language Association. All rights reserved.    */
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
 * File:     imageButton.rex
 *
 * Category: ooDialog example
 *
 * Syntax:
 *   rc = imageButton
 *
 * Purpose:
 *   Provides some example code of new ooDialog feature introduced in 4.0.0
 *
 * Returns:
 *   0 on success, non-zero if the dialog could not be created for some reason.
 *
 * Notes:
 *   This is a short program written to amuse my niece.  Two of the button
 *   controls in the dialog use an image list.  The text for the buttons is 'Add
 *   Pictures' and 'View Pictures' with a picture of a camera on them.  When the
 *   user moves the mouse pointer over either one of the buttons, the picture
 *   changes to a skull and the text changes to 'Death if you touch me.' When
 *   the user pushes either of the buttons the picture changes to a giant bee.
 *
 *   My niece and I think this is hilarious.
 *
 * (.NET version of ooDialog's examples\imageButton.rex, on Windows Forms
 * through oodnet.cls: imageButton.rc's dialog is
 * ImageButton_IDD_IMAGELIST_BUTTON, from imageButtonrc.cls. A Win32 button
 * takes an image list with one image for each state (normal, hot, pushed,
 * disabled, default) and changes the picture itself; a .NET Button shows one
 * image of an ImageList, so the class ButtonStates below changes it on the
 * button's mouse and Enabled events. The image list's mask colour is the
 * ImageList's TransparentColor; setImageList's margins are the button's
 * Padding, its alignment its ImageAlign; the styles TOP and BOTTOM (text above
 * or below the picture) its TextImageRelation; getIdealSize is
 * GetPreferredSize. .NET frees the image list itself. The bitmaps are the
 * original's, in resources\.)
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
use arg
  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

  dlg = .ImageListDlg~new                                 -- ooDialog: .ImageListDlg~new(rcFile, IDD_IMAGELIST_BUTTON)
  if dlg~initCode <> 0 then do
    say "The Image List Dialog was not created correctly"
    say "Init code:" dlg~initCode
    return 99
  end

  dlg~execute("SHOWTOP")

return 0
-- End of entry point.

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  Directives, Classes, or Routines.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::requires "imageButtonrc.cls"

::class 'ImageListDlg' subclass ImageButton_IDD_IMAGELIST_BUTTON

::method initDialog
  expose pbPush pbView pbAdd stStatus ctr imagesLoaded

  self~connectButtonEvent(IDC_PB_PUSHME, "CLICKED", "onPushMe")
  self~connectButtonEvent(IDC_PB_VIEW, "CLICKED", "onView")
  self~connectButtonEvent(IDC_PB_ADD, "CLICKED", "onAdd")

  self~connectButtonEvent(IDC_PB_VIEW, "HOTITEM", onHover)
  self~connectButtonEvent(IDC_PB_ADD, "HOTITEM", onHover)

  imagesLoaded = .false
  ctr = 0

  pbPush = self~newPushButton(IDC_PB_PUSHME)
  pbView  = self~newPushButton(IDC_PB_VIEW)
  pbAdd  = self~newPushButton(IDC_PB_ADD)
  stStatus = self~newStatic(IDC_ST_STATUS)
  stStatus~Text = ""                                      -- ooDialog: stStatus~setText("")

  self~setPictureButtons

::method setPictureButtons private
  expose pbView pbAdd stStatus imagesLoaded imageList viewStates addStates

  F = .net~System~Windows~Forms
  D = .net~System~Drawing
  pbView~FlatStyle = "Standard"                           -- (a button drawn by Windows shows no image)
  pbAdd~FlatStyle = "Standard"
  pbView~TextImageRelation = "ImageAboveText"             -- ooDialog: pbView~style = "MULTILINE BOTTOM"

  srcDir = filespec("location", .context~package~name)   -- ooDialog: .application~srcDir

  -- The images are loaded from files.
  files = .array~new()
  files[1] = srcDir"resources\Normal.bmp"       -- Normal
  files[2] = srcDir"resources\Hot.bmp"          -- Hot (hover)
  files[3] = srcDir"resources\Pushed.bmp"       -- Pushed
  files[4] = srcDir"resources\Disabled.bmp"     -- Disabled
  files[5] = srcDir"resources\Default.bmp"      -- Default button
  files[6] = srcDir"resources\Hot.bmp"          -- Stylus hot, tablet PC only

  -- ooDialog: .ImageList~create(.Size~new(61, 46), 'COLOR24 MASK', 10, 10).
  -- White pixels are transparent (ooDialog: addMasked with the colorRef
  -- 255,255,255): the camera's background lets the button's colour through.
  imageList = F~ImageList~new
  imageList~ImageSize = D~Size~new(61, 46)
  imageList~ColorDepth = "Depth24Bit"
  imageList~TransparentColor = D~Color~White
  stStatus~Text = 'Created image list:' imageList~Handle

  index = -1
  lastGoodIndex = -1
  do file over files                                      -- (not f: Rexx's F is f)
    if \SysFileExists(file) then do
      say 'Failed to load bitmap:' file
      iterate
    end
    imageList~Images~Add(D~Bitmap~new(file))
    index = imageList~Images~Count - 1
    stStatus~Text = 'Added image index:' index
    lastGoodIndex = index
  end

  if lastGoodIndex == -1 then do
    stStatus~Text = "Failed to add any images.  Images are not available"
    return
  end

  imagesLoaded = .true

  -- Set up the alignment and margin around the image on the 'View Pictures'
  -- button.  Then set the image list in the button control (ooDialog:
  -- pbView~setImageList(imageList, .Rect~new(1), 'LEFT'))
  pbView~Padding = F~Padding~new(1)
  pbView~ImageAlign = "MiddleLeft"
  viewStates = .ButtonStates~new(pbView, imageList)
  stStatus~Text = "View Pictures button image list loaded."

  -- Temporarily set the title to the longest text, to calculate ideal size.
  pbView~Text = "DEATH if you touch me"
  bestSize = pbView~GetPreferredSize(D~Size~Empty)       -- ooDialog: pbView~getIdealSize

  -- Write this to the screen, example only.
  say 'Got ideal size:' bestSize
  say '  width: ' bestSize~Width
  say '  height:' bestSize~Height
  say

  -- Now reset the button label and set the size to the ideal size.
  pbView~Text = "View Pictures"
  pbView~Size = bestSize

  -- Example only: what the button has (ooDialog: getImageList, a .Directory).
  say 'Got View Picutes button control image list information.'
  say '  image list:' pbView~ImageList '('pbView~ImageList~Images~Count 'images)'
  say '  handle:    ' pbView~ImageList~Handle
  say '  align:     ' pbView~ImageAlign
  say 'Image margins:' pbView~Padding~Left',' pbView~Padding~Top',' pbView~Padding~Right',' pbView~Padding~Bottom
  say

  -- For the Add Pictures button, use the same image list created for the View
  -- Pictures button.  We just change the margins and the alignment.
  pbAdd~Padding = F~Padding~new(10, 30, 10, 15)           -- (left, top, right, bottom)
  pbAdd~ImageAlign = "MiddleCenter"
  addStates = .ButtonStates~new(pbAdd, imageList)
  stStatus~Text = "Add Pictures button image list loaded."

  -- Now, the same as above, figure out the ideal size and then adjust the
  -- button size.
  pbAdd~TextImageRelation = "ImageAboveText"              -- ooDialog: pbAdd~style = "BOTTOM MULTILINE"
  pbAdd~Text = "DEATH if you touch me"
  s = pbAdd~GetPreferredSize(D~Size~Empty)
  pbAdd~Text = "Add Pictures"
  pbAdd~Size = s

  say 'Got Add Picutes button control image list information.'
  say '  image list:' pbAdd~ImageList '(the same:' pbAdd~ImageList~Equals(pbView~ImageList)')'
  say '  align:     ' pbAdd~ImageAlign
  say 'Image margins:' pbAdd~Padding~Left',' pbAdd~Padding~Top',' pbAdd~Padding~Right',' pbAdd~Padding~Bottom
  say
return

-- As the user pushes the Push Me button, we cycle through some different
-- examples of changing the button state and style.  This changes the pictures
-- displayed on the buttons.
::method onPushMe unguarded
  expose pbView pbAdd stStatus ctr imagesLoaded oldImageList viewStates addStates

  select
    when ctr == 0 then do
      pbView~Focus                                        -- ooDialog: pbView~state = "FOCUS"
      stStatus~Text = 'View Pictures button set to the Focused state.'
      ctr += 1
    end

    when ctr == 1 then do
      self~form~AcceptButton = pbAdd                      -- ooDialog: pbAdd~style = "DEFPUSHBUTTON"
      stStatus~Text = 'Add Pictures button now the default push button.'
      ctr += 1
    end

    when ctr == 2 then do
      self~form~AcceptButton = pbView
      stStatus~Text = 'View Pictures button now the default push button.'
      ctr += 1
    end

    when ctr == 3 then do
      pbView~Enabled = .false                             -- ooDialog: pbView~disable
      stStatus~Text = 'View Pictures button now disabled.'
      ctr += 1
    end

    when ctr == 4 then do
      pbView~Enabled = .true
      self~form~AcceptButton = self~newPushButton(IDCANCEL)
      stStatus~Text = 'View Pictures button now enabled, should not be default push button.'
      ctr = 5
    end

    when ctr == 5 then do
      if imagesLoaded then do
        oldImageList = viewStates~list                    -- ooDialog: pbView~setImageList(.nil)
        viewStates~list = .nil
        stStatus~Text = 'Removed View Pictures button images.  Push "Push Me one more time to restore".'
      end
      ctr = 6
    end

    otherwise do                                          -- (6, and the impossible)
      if imagesLoaded, oldImageList \== .nil then do
        viewStates~list = oldImageList
        stStatus~Text = 'Restored View Pictures button images.'
      end
      ctr = 0
    end
  end
  -- End select
  if imagesLoaded then do                                 -- (.NET version) the default button changes the pictures
    viewStates~show
    addStates~show
  end

-- This is the amusing part.  We get this event message when the mouse is first
-- moved over a button (entering will be .true) or when the mouse moves off a
-- button (entering will be .false.)  We change the text and style of the
-- button, (.NET version) and ButtonStates the picture.
::method onHover unguarded
  expose imagesLoaded pbView pbAdd
  use arg id, entering

  if \ imagesLoaded then return

  isViewButton = (id == "IDC_PB_VIEW")                    -- ooDialog: (id == .constDir[IDC_PB_VIEW])

  if entering then do
    text = "DEATH if you touch me"
    relation = "TextAboveImage"                           -- ooDialog: style = "TOP"
  end
  else do
    if isViewButton then text = "View Pictures"
    else text = "Add Pictures"
    relation = "ImageAboveText"                           -- ooDialog: style = "BOTTOM"
  end

  if isViewButton then do
    pbView~TextImageRelation = relation
    pbView~Text = text
  end
  else do
    pbAdd~TextImageRelation = relation
    pbAdd~Text = text
  end

::method onView unguarded
  expose stStatus
  stStatus~Text = 'In onView, no actions defined.'

::method onAdd unguarded
  expose stStatus
  stStatus~Text = 'In onAdd, no actions defined.'

::method autoRun                       -- (.NET version) unattended: Push Me through its cycle, the hover, then OK
  expose stStatus pbView viewStates
  do 7
    self~onPushMe
    say "(auto)" stStatus~Text "- View's picture:" pbView~ImageIndex
  end
  self~onHover("IDC_PB_VIEW", .true)
  viewStates~enter
  say "(auto) hot:" pbView~Text "- picture:" pbView~ImageIndex
  viewStates~leave
  self~onHover("IDC_PB_VIEW", .false)
  say "(auto) left:" pbView~Text "- picture:" pbView~ImageIndex
  self~ok

/* (.NET version) A Win32 button image list's states on a .NET Button: the
   image of each state (0 normal, 1 hot, 2 pushed, 3 disabled, 4 default),
   chosen on the button's mouse and Enabled events. list = .nil: no image. */
::class ButtonStates
::attribute list get
::method init
  expose button list hot pressed
  use strict arg button, list
  hot = .false; pressed = .false
  button~MouseEnter += .net~handler(self, "ENTER")
  button~MouseLeave += .net~handler(self, "LEAVE")
  button~MouseDown += .net~handler(self, "DOWN")
  button~MouseUp += .net~handler(self, "UP")
  button~EnabledChanged += .net~handler(self, "SHOW")
  self~show
::method "LIST="
  expose list
  use strict arg list
  self~show
::method enter;  expose hot;     hot = .true;      self~show
::method leave;  expose hot pressed; hot = .false; pressed = .false; self~show
::method down;   expose pressed; pressed = .true;  self~show
::method up;     expose pressed; pressed = .false; self~show
::method show
  expose button list hot pressed
  if list == .nil then do
    button~ImageList = .nil
    return
  end
  form = button~FindForm
  select
    when \button~Enabled then i = 3
    when pressed then i = 2
    when hot then i = 1
    when form \== .nil, button~Equals(form~AcceptButton) then i = 4
    otherwise i = 0
  end
  button~ImageList = list
  button~ImageIndex = i
