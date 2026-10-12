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

/** customizeToolBar.rex
 *
 * The main purpose of this example is to show how to make the built-in
 * customization features of the toolbar available to the users of your
 * application.  It also shows how to connect many of the event notifications of
 * the toolbar.
 *
 * (.NET version of ooDialog's controls\ToolBar\customizeToolBar.rex, on
 * Windows Forms through oodnet.cls; the .rc is customizeToolBarrc.cls,
 * written by rc2oodnet.rex -cls (the original uses it compiled, a
 * ResDialog), its bitmap resources\ToolBar11IL.bmp. The tool bar is a .NET
 * ToolStrip: a button is a ToolStripButton whose Tag is its command id; with
 * MIXEDBUTTONS and no SHOWTEXT a button shows its image and has its text as
 * its tip (DisplayStyle Image, AutoToolTip); Alt and a drag moves a button,
 * as TBSTYLE_ALTDRAG (AllowItemReorder). A ToolStrip has no customization
 * of its own: the Customize Toolbar dialog Windows shows for a CCS_ADJUSTABLE
 * tool bar on a double click is a NetDialog here, CustomizeToolBarDialog,
 * which sends the dialog the tool bar's notifications as Windows does, to
 * the methods connectToolBarEvent named (BEGINADJUST, INITCUSTOMIZE,
 * QUERYINSERT, QUERYDELETE, GETBUTTONINFO, DELETINGBUTTON, TOOLBARCHANGE,
 * CUSTHELP, ENDADJUST; RELEASEDCAPTURE is the ToolStrip's MouseUp). TbButton
 * is the description of a button the program keeps, as ooDialog's; its
 * bitmapID counts the images from 1. A tool bar button's CLICKED is its
 * command (WM_COMMAND in ooDialog): connectButtonEvent keeps it for the
 * buttons made from TbButtons.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .CustomizableToolBar~new                          -- ooDialog: .CustomizableToolBar~new(sd'rc\customizeToolBar.dll', IDD_TBAR, , sd'rc\customizeToolBar.h')
    dlg~execute("SHOWTOP")

return 0
-- End of entry point.

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  Directives, Classes, or Routines.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::requires "customizeToolBarrc.cls"

::class 'CustomizableToolBar' subclass CustomizeToolBar_IDD_TBAR

::method init
  expose buttons commands tbEvents
  commands = .directory~new                                 -- (.NET version) command id -> method
  tbEvents = .directory~new                                 -- (.NET version) tool bar notification -> method
  forward class (super) continue

  self~connectButtonEvent(IDB_ARROW_LEFT,      'CLICKED', onArrowLeft)
  self~connectButtonEvent(IDB_ARROW_RIGHT,     'CLICKED', onArrowRight)
  self~connectButtonEvent(IDB_COPY_CLIPBOARD,  'CLICKED', onCopyClipBoard)
  self~connectButtonEvent(IDB_COPY_TO_FOLDER , 'CLICKED', onCopyToFolder)
  self~connectButtonEvent(IDB_CUT_CLIPBOARD,   'CLICKED', onCutClipBoard)
  self~connectButtonEvent(IDB_DELETE         , 'CLICKED', onDelete)
  self~connectButtonEvent(IDB_FAVORITES      , 'CLICKED', onFavorites)
  self~connectButtonEvent(IDB_FOLDER_CLOSED  , 'CLICKED', onFolderClosed)
  self~connectButtonEvent(IDB_MOVE_TO_FOLDER , 'CLICKED', onMoveToFolder)
  self~connectButtonEvent(IDB_PASTE_CLIPBOARD, 'CLICKED', onPasteClipboard)
  self~connectButtonEvent(IDB_SEARCH         , 'CLICKED', onSearch)

  self~connectToolBarEvent(IDC_TOOLBAR, 'BEGINADJUST')
  self~connectToolBarEvent(IDC_TOOLBAR, 'ENDADJUST')
  self~connectToolBarEvent(IDC_TOOLBAR, 'CUSTHELP')
  self~connectToolBarEvent(IDC_TOOLBAR, 'DELETINGBUTTON')
  self~connectToolBarEvent(IDC_TOOLBAR, 'GETBUTTONINFO')
  self~connectToolBarEvent(IDC_TOOLBAR, 'INITCUSTOMIZE')
  self~connectToolBarEvent(IDC_TOOLBAR, 'QUERYDELETE')
  self~connectToolBarEvent(IDC_TOOLBAR, 'QUERYINSERT')
  self~connectToolBarEvent(IDC_TOOLBAR, 'RELEASEDCAPTURE')
  self~connectToolBarEvent(IDC_TOOLBAR, 'TOOLBARCHANGE')

  tbb1  = .TbButton~new(IDB_ARROW_LEFT     , "Previous"             , "BUTTON", "ENABLED", , 1)
  tbb2  = .TbButton~new(IDB_ARROW_RIGHT    , "Next"                 , "BUTTON", "ENABLED", , 2)
  tbb3  = .TbButton~new(IDB_COPY_CLIPBOARD , "Copy to clipboard"    , "BUTTON", "ENABLED", , 3)
  tbb5  = .TbButton~new(IDB_COPY_TO_FOLDER , "Copy to folder"       , "BUTTON", "ENABLED", , 4)
  tbb4  = .TbButton~new(IDB_CUT_CLIPBOARD  , "Cut to clipboard"     , "BUTTON", "ENABLED", , 5)
  tbb6  = .TbButton~new(IDB_DELETE         , "Delete"               , "BUTTON", "ENABLED", , 6)
  tbb7  = .TbButton~new(IDB_FAVORITES      , "Favorites"            , "BUTTON", "ENABLED", , 7)
  tbb8  = .TbButton~new(IDB_FOLDER_CLOSED  , "Close folder"         , "BUTTON", "ENABLED", , 8)
  tbb9  = .TbButton~new(IDB_MOVE_TO_FOLDER , "Move to folder"       , "BUTTON", "ENABLED", , 9)
  tbb10 = .TbButton~new(IDB_PASTE_CLIPBOARD, "Paste from clipboard" , "BUTTON", "ENABLED", , 10)
  tbb11 = .TbButton~new(IDB_SEARCH         , "Search, for something", "BUTTON", "ENABLED", , 11)

  self~storeButtonText
  buttons = .array~of(tbb1, tbb2, tbb3, tbb4, tbb5, tbb6, tbb7, tbb8, tbb9, tbb10, tbb11)


::method initDialog
  expose tb buttons listBox

  tb = self~newToolBar(IDC_TOOLBAR)

  tb~ImageScalingSize = .net~System~Drawing~Size~new(24, 24)   -- ooDialog: tb~setBitmapSize(.Size~new(24, 24))
  tb~AllowItemReorder = .true                               -- (TBSTYLE_ALTDRAG: Alt and a drag moves a button)
  -- ooDialog: tb~setExtendedStyle('DOUBLEBUFFER MIXEDBUTTONS'): a ToolStrip
  -- is double buffered; the buttons show their images, their text as tips

  self~loadImageList(tb)
  self~setupListBox

  -- We only add the first 3 buttons here.
  btns = .array~of(buttons[1], buttons[2], buttons[3])
  ret = self~addButtons(tb, btns)                           -- ooDialog: tb~addButtons(btns)

  ret = self~setButtonText(tb, "Previous", IDB_ARROW_LEFT)  -- ooDialog: tb~setButtonText("Previous", IDB_ARROW_LEFT)
  ret = self~setButtonText(tb, "Next", IDB_ARROW_RIGHT)
  ret = self~setButtonText(tb, "Copy to clipboard", IDB_COPY_CLIPBOARD)

  -- (.NET version) A ToolStrip sizes itself (ooDialog: tb~autoSize).

  -- (.NET version) Windows' customization, and NM_RELEASEDCAPTURE.
  tb~MouseDoubleClick += .net~handler(self, "CUSTOMIZE")
  tb~MouseUp += .net~handler(self, "TOOLBAR.MOUSEUP")

  -- And show the tool bar.
  tb~Visible = .true                                        -- ooDialog: tb~show
  tb~Focus                                                  -- ooDialog: tb~assignFocus


::method onArrowLeft unguarded
  expose tb listBox
  self~add('Current text:' self~getButtonTextEx(tb, IDB_ARROW_LEFT))

::method onArrowRight unguarded
  expose tb listBox
  self~add('Current text:' self~getButtonTextEx(tb, IDB_ARROW_RIGHT))

::method onCopyClipboard unguarded
  expose tb listBox
  self~add('Current text:' self~getButtonTextEx(tb, IDB_COPY_CLIPBOARD))

::method onCopyToFolder unguarded
  expose tb listBox
  self~add('Current text:' self~getButtonTextEx(tb, IDB_COPY_TO_FOLDER))


::method onGetButtonInfo unguarded
  expose buttons listBox
  use arg id, index, textLen, tbb, toobar

  self~add('TBN_GETBUTTONINFO  buttonindex:' index)
  if index > buttons~items then return .false

  self~mergeButtons(tbb, buttons[index])
  return .true

::method onQueryDelete unguarded
  expose listBox
  use arg id, index, tbb, toolbar

  self~add('TBN_QUERYDELETE    buttonindex:' index 'cmdID:' tbb~cmdID)
  return .true

::method onQueryInsert unguarded
  expose listBox
  use arg id, index, tbb, toolbar

  self~add('TBN_QUERYINSERT    buttonindex:' index 'cmdID:' tbb~cmdID)
  return .true


::method onReleasedCapture unguarded
  expose listBox
  use arg id, toolBar
  self~add('NM_RELEASEDCAPTURE')

  return 0

::method onBeginAdjust unguarded
  expose listBox

  self~add('TBN_BEGINADJUST')
  return .true

::method onCustHelp unguarded
  expose listBox

  self~add('TBN_CUSTHELP')
  return .true

::method onDeletingButton unguarded
  expose listBox
  use arg id, cmdID, toolbar

  self~add('TNB_DELETINGBUTTON cmdID:' cmdID)
  return 0

::method onInitCustomize unguarded
  expose listBox

  self~add('TBN_INITCUSTOMIZE')
  return .true

::method onEndAdjust unguarded
  expose listBox
  use arg id, tb
  self~add('TBN_ENDADJUST')

  count = tb~Items~Count                                    -- ooDialog: tb~buttonCount
  do i = 1 to count
    cmdID = tb~Items[i - 1]~Tag                             -- ooDialog: tb~indexToCommand(i)
    if cmdID <> 0, cmdID <> .nil then self~resetText(cmdID)
  end
  return 0

::method onToolBarChange unguarded
  expose buttonTextSet listBox
  use arg id, tb
  self~add('TBN_TOOLBARCHANGE')

  return 0

::method leaving
  expose font imageList
  imageList~Dispose                                         -- ooDialog: imageList~release
  self~deleteFont(font)

::method mergeButtons unguarded private
  use strict arg button1, button2

  button1~bitmapID = button2~bitmapID
  button1~cmdID    = button2~cmdID
  button1~itemData = button2~itemData
  button1~state    = button2~state
  button1~style    = button2~style
  button1~text     = button2~text

::method printTbb unguarded private
  use arg tbb

  say 'bitmapID:' tbb~bitmapID
  say 'cmdID:   ' tbb~cmdID
  say 'itemData:' tbb~itemData
  say 'state:   ' tbb~state
  say 'style:   ' tbb~style
  say 'text:    ' tbb~text
  say

::method loadImageList private
  expose imageList
  use strict arg tb

  -- ooDialog: flags 'COLOR32 MASK', the mask colour magenta, the bitmap
  -- IDB_BUTTONS_IL of the resources, .ImageList~create(.Size~new(24, 24), ...),
  -- imageList~addMasked(imageBMP, cRef)
  D = .net~System~Drawing
  imageList = .net~System~Windows~Forms~ImageList~new
  imageList~ColorDepth = "Depth32Bit"
  imageList~ImageSize = D~Size~new(24, 24)
  imageList~TransparentColor = D~Color~FromArgb(255, 0, 255)
  srcDir = filespec("location", .context~package~name)
  imageBMP = D~Bitmap~new(srcDir"resources\ToolBar11IL.bmp")
  index = imageList~Images~AddStrip(imageBMP)
  tb~ImageList = imageList                                  -- ooDialog: tb~setImageList(imageList)

  h = imageList~Handle                                      -- (.NET version) the image list copies the images when it makes its handle:
  imageBMP~Dispose                                          -- then the bitmap can go

::method setupListBox private
  expose listBox font maxItems

  font = self~createFontEx('Courier New')

  listBox = self~newListBox(IDC_LB_EVENTS)
  listBox~Font = font                                       -- ooDialog: listBox~setFont(font)
  size = .net~System~Windows~Forms~TextRenderer~MeasureText('A'~copies(50), font)   -- ooDialog: self~getTextSizePX
  listBox~HorizontalScrollbar = .true
  listBox~HorizontalExtent = size~width                     -- ooDialog: listBox~setWidthPX(size~width)

  maxItems = listBox~ClientSize~Height % listBox~ItemHeight

::method add unguarded private
  expose listBox maxItems
  use strict arg text

  index = listBox~Items~Add(text)                           -- (from 0)
  if index + 1 > listBox~TopIndex + maxItems then listBox~TopIndex = index - maxItems + 1   -- ooDialog: getFirstVisible, makeFirstVisible

::method storeButtonText private
  expose buttonTextTable

  table = .table~new
  table[IDB_ARROW_LEFT]      = "Previous"                   -- (.NET version: the ids are names)
  table[IDB_ARROW_RIGHT]     = "Next"
  table[IDB_COPY_CLIPBOARD]  = "Copy to clipboard"
  table[IDB_COPY_TO_FOLDER]  = "Copy to folder"
  table[IDB_CUT_CLIPBOARD]   = "Cut to clipboard"
  table[IDB_DELETE]          = "Delete"
  table[IDB_FAVORITES]       = "Favorites"
  table[IDB_FOLDER_CLOSED]   = "Close folder"
  table[IDB_MOVE_TO_FOLDER]  = "Move to folder"
  table[IDB_PASTE_CLIPBOARD] = "Paste from clipboard"
  table[IDB_SEARCH]          = "Search, for something"

  buttonTextTable = table

::method resetText unguarded private
  expose tb buttonTextTable
  use arg cmdID

  ret = self~setButtonText(tb, buttonTextTable[cmdID], cmdID)


/* - - - - - - - - - - - - (.NET version) ooDialog's ToolBar methods, on a ToolStrip */

/* connectButtonEvent: a tool bar button's command (ooDialog: its WM_COMMAND);
   the dialog's own buttons as NetDialog's */
::method connectButtonEvent
  expose commands
  use arg id, event = "CLICKED", methodName
  if id~string~upper~abbrev("IDB_") then do
    commands[id~string~upper] = methodName
    return 0
  end
  forward class (super)

/* connectToolBarEvent(id, event [, method]): the method for a notification,
   by default "on" and the event's name (onBeginAdjust...) */
::method connectToolBarEvent
  expose tbEvents
  use strict arg id, event, methodName = ("on"event)
  tbEvents[event~upper] = methodName
  return 0

::method toolBarEvent unguarded          -- a notification, to its method if connected: its answer, else .true
  expose tbEvents
  use arg event
  m = tbEvents[event~upper]
  if m == .nil then return .true
  return self~sendWith(m, arg(2, "A"))

::method addButtons                     -- the buttons of TbButtons, at the end
  use strict arg tb, tbbs
  do tbb over tbbs
    tb~Items~Add(self~newButton(tb, tbb))
  end
  return .true

::method newButton                      -- a ToolStripButton of a TbButton
  expose commands
  use strict arg tb, tbb
  item = .net~System~Windows~Forms~ToolStripButton~new(tbb~text)
  item~Tag = tbb~cmdID~string~upper
  item~Name = tbb~cmdID
  item~ImageIndex = tbb~bitmapID - 1
  item~DisplayStyle = "Image"                               -- (MIXEDBUTTONS without SHOWTEXT)
  item~AutoToolTip = .true
  item~Enabled = tbb~state~caselessWordPos("ENABLED") > 0
  m = commands[item~Tag]
  if m \== .nil then item~Click += .net~handler(self, m)
  return item

::method commandItem private            -- the ToolStripButton of a command id, or .nil
  use strict arg tb, cmdID
  do item over tb~Items~makeArray
    if item~Tag == cmdID~string~upper then return item
  end
  return .nil

::method setButtonText
  use strict arg tb, text, cmdID
  item = self~commandItem(tb, cmdID)
  if item == .nil then return .false
  item~Text = text
  return .true

::method getButtonTextEx
  use strict arg tb, cmdID
  item = self~commandItem(tb, cmdID)
  if item == .nil then return ''
  return item~Text

::method "TOOLBAR.MOUSEUP" unguarded
  expose tb
  use arg strip, e
  self~toolBarEvent('RELEASEDCAPTURE', IDC_TOOLBAR, tb)

::method customize unguarded             -- Windows' Customize Toolbar dialog (a double click: CCS_ADJUSTABLE)
  expose tb buttons
  use arg strip, e
  dlg = .CustomizeToolBarDialog~new(self, tb, IDC_TOOLBAR)
  dlg~execute

::method autoRun                       -- (.NET version) unattended: a button clicked; the tool bar customized; OK
  expose tb listBox
  say "(auto) tool bar:" tb~Items~Count "buttons, images" tb~ImageList~Images~Count", tips:" tb~Items[0]~ToolTipText
  tb~Items[0]~PerformClick
  self~customize(tb, .nil)
  say "(auto) tool bar now:"
  do i = 0 to tb~Items~Count - 1
    it = tb~Items[i]
    say "(auto)  " i + 1":" (it~Tag == .nil)~?("(separator)", it~Tag "-" it~Text)
  end
  say "(auto) events:"
  do i = 0 to listBox~Items~Count - 1
    say "(auto)  " listBox~Items[i]
  end
  self~ok


/* ooDialog's TbButton: the description of a tool bar button (bitmapID: its
   image, from 1) */
::class TbButton public
::attribute cmdID
::attribute text
::attribute style
::attribute state
::attribute itemData
::attribute bitmapID
::method init
  use arg cmdID = 0, text = "", style = "BUTTON", state = "ENABLED", itemData = .nil, bitmapID = 0
  self~cmdID = cmdID; self~text = text; self~style = style; self~state = state
  self~itemData = itemData; self~bitmapID = bitmapID
::method ofItem class                  -- a TbButton for a ToolStrip's item
  use strict arg item
  if .net~isInstance(item, "System.Windows.Forms.ToolStripSeparator") then return self~new(0, "", "SEP")
  return self~new(item~Tag, item~Text, "BUTTON", item~Enabled~?("ENABLED", ""), , item~ImageIndex + 1)


/* (.NET version) Windows' Customize Toolbar dialog: the buttons that could
   be added (those the program gives with GETBUTTONINFO and the tool bar has
   not, and a separator), those on the tool bar; Add, Remove, Move Up, Move
   Down, Reset (the tool bar as it was), Help, Close. It sends the dialog the
   notifications, as Windows does: BEGINADJUST, INITCUSTOMIZE, QUERYDELETE
   for each button, GETBUTTONINFO from 1 until .false, QUERYINSERT before an
   insertion, DELETINGBUTTON, TOOLBARCHANGE after each change, CUSTHELP,
   ENDADJUST. */
::class CustomizeToolBarDialog subclass NetDialog
::method init
  expose owner tb id available original
  use strict arg owner, tb, id
  self~init:super
  self~createCenter(330, 128, "Customize Toolbar")
::method defineDialog
  self~createStatic(ST_AVAIL, 7, 7, 120, 9, , "A&vailable toolbar buttons:")
  self~createListBox(LB_AVAIL, 7, 18, 120, 103, "PARTIAL")
  self~createPushButton(PB_ADD, 133, 46, 50, 14, , "&Add ->", onAdd)
  self~createPushButton(PB_REMOVE, 133, 64, 50, 14, , "<- &Remove", onRemove)
  self~createStatic(ST_CURRENT, 189, 7, 80, 9, , "&Toolbar buttons:")
  self~createListBox(LB_CURRENT, 189, 18, 80, 103, "PARTIAL")
  self~createPushButton(IDCANCEL, 275, 7, 48, 14, , "&Close")
  self~createPushButton(PB_RESET, 275, 25, 48, 14, , "R&eset", onReset)
  self~createPushButton(IDHELP, 275, 43, 48, 14, , "&Help")
  self~createPushButton(PB_UP, 275, 75, 48, 14, , "Move &Up", onUp)
  self~createPushButton(PB_DOWN, 275, 93, 48, 14, , "Move &Down", onDown)
::method initDialog
  expose owner tb id available original
  owner~toolBarEvent('BEGINADJUST', id, tb)
  owner~toolBarEvent('INITCUSTOMIZE', id, tb)
  original = .array~new
  do i = 0 to tb~Items~Count - 1
    tbb = .TbButton~ofItem(tb~Items[i])
    original~append(tbb)
    owner~toolBarEvent('QUERYDELETE', id, i + 1, tbb, tb)
  end
  available = .array~new                 -- what GETBUTTONINFO gives
  do i = 1
    tbb = .TbButton~new
    if owner~toolBarEvent('GETBUTTONINFO', id, i, 0, tbb, tb) \== .true then leave
    available~append(tbb)
  end
  do name over .array~of(LB_AVAIL, LB_CURRENT)
    lb = self~newListBox(name)
    lb~DrawMode = "OwnerDrawFixed"
    lb~ItemHeight = max(26, lb~Font~Height + 4)
    lb~DrawItem += .net~handler(self, "ONDRAWITEM")
    lb~SelectedIndexChanged += .net~handler(self, "ONSELECT")
  end
  self~fill
::method fill private                   -- the two lists, from the tool bar (their TbButtons in Rexx arrays, their texts in the ListBoxes)
  expose tb available lists
  avail = self~newListBox(LB_AVAIL); cur = self~newListBox(LB_CURRENT)
  a = .array~of(.TbButton~new(0, "Separator", "SEP"))
  do tbb over available
    if self~onBar(tbb~cmdID) == .nil then a~append(tbb)
  end
  c = .array~new
  do i = 0 to tb~Items~Count - 1
    c~append(.TbButton~ofItem(tb~Items[i]))
  end
  lists = .directory~new
  lists[avail~Name~upper] = a; lists[cur~Name~upper] = c
  avail~Items~Clear; cur~Items~Clear
  do tbb over a; avail~Items~Add(tbb~text); end
  do tbb over c; cur~Items~Add(tbb~text); end
  avail~SelectedIndex = 0
  if cur~Items~Count > 0 then cur~SelectedIndex = 0
::method onBar private                  -- the tool bar's item of a command id, or .nil
  expose tb
  use strict arg cmdID
  do item over tb~Items~makeArray
    if item~Tag \== .nil, item~Tag == cmdID~string~upper then return item
  end
  return .nil
::method entry private                  -- a list's TbButton at index i (from 0)
  expose lists
  use strict arg lb, i
  return lists[lb~Name~upper][i + 1]
::method onDrawItem unguarded           -- a list's item: its image and its text
  expose tb lists
  use arg lb, e
  e~DrawBackground
  if e~Index < 0 | \var("LISTS") then return
  tbb = self~entry(lb, e~Index)
  r = e~Bounds
  if tbb~bitmapID > 0 then tb~ImageList~Draw(e~Graphics, r~X + 2, r~Y + (r~Height - 24) % 2, tbb~bitmapID - 1)
  rt = .net~System~Drawing~Rectangle~new(r~X + 30, r~Y, r~Width - 30, r~Height)
  .net~System~Windows~Forms~TextRenderer~DrawText(e~Graphics, tbb~text, e~Font, rt, e~ForeColor, "VerticalCenter, SingleLine, NoPrefix")
  e~DrawFocusRectangle
::method onSelect unguarded              -- the buttons enabled as Windows' dialog has them
  use arg lb, e
  cur = self~newListBox(LB_CURRENT)
  i = cur~SelectedIndex
  self~newPushButton(PB_REMOVE)~Enabled = i >= 0
  self~newPushButton(PB_UP)~Enabled = i > 0
  self~newPushButton(PB_DOWN)~Enabled = i >= 0 & i < cur~Items~Count - 1
  self~newPushButton(PB_ADD)~Enabled = self~newListBox(LB_AVAIL)~SelectedIndex >= 0
::method onAdd unguarded                 -- the button chosen, before the selected one of the tool bar
  expose owner tb id
  avail = self~newListBox(LB_AVAIL); cur = self~newListBox(LB_CURRENT)
  if avail~SelectedIndex < 0 then return 0
  tbb = self~entry(avail, avail~SelectedIndex)
  at = cur~SelectedIndex
  if at < 0 then at = tb~Items~Count
  if owner~toolBarEvent('QUERYINSERT', id, at + 1, tbb, tb) \== .true then return 0
  if tbb~style == "SEP" then item = .net~System~Windows~Forms~ToolStripSeparator~new
  else item = owner~newButton(tb, tbb)
  tb~Items~Insert(at, item)
  owner~toolBarEvent('TOOLBARCHANGE', id, tb)
  self~fill
  cur~SelectedIndex = at
  return 0
::method onRemove unguarded
  expose owner tb id
  cur = self~newListBox(LB_CURRENT)
  i = cur~SelectedIndex
  if i < 0 then return 0
  item = tb~Items[i]
  owner~toolBarEvent('DELETINGBUTTON', id, (item~Tag == .nil)~?(0, item~Tag), tb)
  tb~Items~RemoveAt(i)
  item~Dispose
  owner~toolBarEvent('TOOLBARCHANGE', id, tb)
  self~fill
  if cur~Items~Count > 0 then cur~SelectedIndex = min(i, cur~Items~Count - 1)
  return 0
::method onUp unguarded
  self~move(-1)
::method onDown unguarded
  self~move(1)
::method move private
  expose owner tb id
  use strict arg delta
  cur = self~newListBox(LB_CURRENT)
  i = cur~SelectedIndex
  if i < 0 | i + delta < 0 | i + delta >= tb~Items~Count then return 0
  item = tb~Items[i]
  tb~Items~RemoveAt(i)
  tb~Items~Insert(i + delta, item)
  owner~toolBarEvent('TOOLBARCHANGE', id, tb)
  self~fill
  cur~SelectedIndex = i + delta
  return 0
::method onReset unguarded               -- the tool bar as it was when the dialog opened
  expose owner tb id original
  do while tb~Items~Count > 0
    item = tb~Items[0]; tb~Items~RemoveAt(0); item~Dispose
  end
  do tbb over original
    if tbb~style == "SEP" then tb~Items~Add(.net~System~Windows~Forms~ToolStripSeparator~new)
    else tb~Items~Add(owner~newButton(tb, tbb))
  end
  owner~toolBarEvent('TOOLBARCHANGE', id, tb)
  self~fill
  return 0
::method help unguarded
  expose owner tb id
  owner~toolBarEvent('CUSTHELP', id, tb)
  return 0
::method leaving
  expose owner tb id
  owner~toolBarEvent('ENDADJUST', id, tb)
::method autoRun                       -- (unattended) Favorites added before Next, a separator at the end, Next removed, moved, Help; Close
  avail = self~newListBox(LB_AVAIL); cur = self~newListBox(LB_CURRENT)
  say "(auto) customize: available" avail~Items~Count", on the tool bar" cur~Items~Count
  do i = 0 to avail~Items~Count - 1
    if avail~Items[i] == "Favorites" then avail~SelectedIndex = i
  end
  cur~SelectedIndex = 1
  self~onAdd
  avail~SelectedIndex = 0
  cur~SelectedIndex = -1
  self~onAdd
  cur~SelectedIndex = 2
  self~onRemove
  cur~SelectedIndex = 0
  self~onDown
  self~help
  self~cancel
