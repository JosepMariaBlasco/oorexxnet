/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2018 Rexx Language Association. All rights reserved.    */
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

/** Tab Control / Dialog Controls / ControlDialog Example
 *
 * This example demonstrates how to use the ControlDialog class to populate a
 * Tab control.  It is basically the same as the PropertySheetDemo.rex example,
 * but uses a Tab control with ControlDialog objects rather than using a
 * PropertySheetDialog.
 *
 * Much of the code is simply copied from the PropertySheetDemo.rex program.
 *
 * (.NET version of ooDialog's propertysheet.tabControls\TabOwnerDemo.rex, on
 * Windows Forms through oodnet.cls: the dialogs of rc\TabOwnerDemo.rc (the
 * original loads them from its compiled TabOwnerDemo.dll: the same dialogs)
 * are classes of TabOwnerDemorc.cls (rc2oodnet.rex -cls). oodnet.cls has
 * ooDialog's TabOwnerDialog, ManagedTab, TabOwnerDlgInfo and ControlDlgInfo:
 * each tab control shows its control dialogs (inherit ControlDialog), made
 * when first chosen, over its display area. The ids are names. The pages'
 * code is PropertySheetDemo.rex's (.NET version); their bitmaps are the same
 * as TabOwnerDemo's, so the propertySheetDemo ones serve. The progress bars
 * move on timers where ooDialog starts a thread for each.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  -- ooDialog: sd = locate(), .application~setDefaults("O", sd"rc\TabOwnerDemo.h", .false):
  -- here the ids are names.

  -- Create a managed tab object that is composed of all the control dialogs for
  -- a specific tab control in the tab owner dialog.
  dlgs = .array~new(5)

  exArgs = .ControlDlgInfo~new( , .true, "List View", .net~System~Drawing~Size~new(300, 250))   -- ooDialog: .Size~new(300, 250)
  dlgs[1] = .ListViewDlg~new(exArgs)                      -- ooDialog: .ListViewDlg~new(sd"rc\TabOwnerDemo.dll", IDD_LISTVIEW_DLG, , , exArgs)

  exArgs~title = 'Tree View'
  dlgs[2] = .TreeViewDlg~new(exArgs)

  exArgs~title = 'Progress Bar'
  dlgs[3] = .ProgressBarDlg~new(exArgs)

  exArgs~title = 'Track Bar'
  dlgs[4] = .TrackBarDlg~new(exArgs)

  exArgs~title = 'Tab'
  dlgs[5] = .TabDlg~new(exArgs)

  mt1 = .ManagedTab~new(IDC_TAB1, dlgs, "SELCHANGE")

  dlgs = .array~new(5)

  exArgs~Title = "Blank 1"
  dlgs[1] = .BlankDlg~new(exArgs)

  exArgs~title = 'Blank 2'
  dlgs[2] = .BlankDlg~new(exArgs)

  exArgs~title = 'Blank 3'
  dlgs[3] = .BlankDlg~new(exArgs)

  exArgs~title = 'Blank 4'
  dlgs[4] = .BlankDlg~new(exArgs)

  exArgs~title = 'Blank 5'
  dlgs[5] = .BlankDlg~new(exArgs)

  mt2 = .ManagedTab~new(IDC_TAB2, dlgs)

  -- Create the main dialog.
  exArgs = .TabOwnerDlgInfo~new(.array~of(mt1, mt2))
  dlg = .NewControlsDialog~new( , , exArgs)

  -- Show and run the dialog.
  dlg~execute('SHOWTOP', IDI_DLG_OOREXX)

  return 0

::requires "TabOwnerDemorc.cls"

::class 'NewControlsDialog' subclass NetDialog inherit TabOwnerDialog

::method init

  forward class (super) continue
  if self~initCode <> 0 then return

  self~createCenter(640, 300, "TabOwner Example with ControlDialog objects", "", , "Arial", 9)

::method defineDialog

  self~createTab(IDC_TAB1, 10,  5, 305, 265)
  self~createTab(IDC_TAB2, 325, 5, 305, 265)

  self~createPushButton(IDC_PB_PREVIOUS, 10, 278, 60, 14, , "Previous Control", onPrevious)
  self~createPushButton(IDC_PB_NEXT, 80, 278, 60, 14, , "Next Control", onNext)
  self~createPushButton(IDOK, 500, 278, 60, 14, "DEFAULT", "Ok")
  self~createPushButton(IDCANCEL, 570, 278, 60, 14, , "Cancel")


::method initDialog
  expose tabControl pbNext pbPrevious

  -- Save a reference to the push buttons.
  pbNext = self~newPushButton(IDC_PB_NEXT)
  pbPrevious = self~newPushButton(IDC_PB_PREVIOUS)
  tabControl = self~newTab(IDC_TAB1)

  pbPrevious~Enabled = .false                            -- ooDialog: pbPrevious~disable

::method tabOwnerSelChange unguarded
  expose pbNext pbPrevious
  use arg pageDlg, pageNumber

  if pageNumber == 1 then do
    pbPrevious~Enabled = .false
    pbNext~Enabled = .true
  end
  else if pageNumber == 5 then do
    pbPrevious~Enabled = .true
    pbNext~Enabled = .false
  end
  else do
    pbPrevious~Enabled = .true
    pbNext~Enabled = .true
  end

::method onNext
  expose tabControl

  tabControl~SelectedIndex = min(tabControl~SelectedIndex + 1, tabControl~TabCount - 1)   -- ooDialog: tabControl~focus(tabControl~selectedIndex + 1)
  self~checkButtons


::method onPrevious
  expose tabControl

  tabControl~SelectedIndex = max(tabControl~SelectedIndex - 1, 0)
  self~checkButtons


::method checkButtons
  expose tabControl pbNext pbPrevious

  index = tabControl~SelectedIndex + 1
  if index == 1 then do
    pbPrevious~Enabled = .false
    pbNext~Enabled = .true
  end
  else if index == 5 then do
    pbPrevious~Enabled = .true
    pbNext~Enabled = .false
  end
  else do
    pbPrevious~Enabled = .true
    pbNext~Enabled = .true
  end

::method autoRun unguarded                                -- (.NET version) unattended: Next on the first tab control, a page of the second, OK
  expose tabControl
  call show self, "at first"
  do 4
    self~onNext
    call show self, "Next"
  end
  tab2 = self~newTab(IDC_TAB2)
  tab2~SelectedIndex = 2
  call show self, "Blank 3"
  self~onPrevious
  call show self, "Previous"
  say "(auto) progress bars running:" self~getTabPage(IDC_TAB1, 3)~running
  say "(auto) list view:" self~getTabPage(IDC_TAB1, 1)~newListView(IDC_LV_MAIN)~Items~Count "rows"
  self~ok

::routine show                                            -- (.NET version) the pages shown on each tab control
  use arg dlg, what
  s = ""
  do id over .array~of(IDC_TAB1, IDC_TAB2)
    tc = dlg~newTab(id)
    shown = ""
    do i = 1 to tc~TabCount
      p = dlg~getTabPage(id, i)
      if p~isDialogActive then if p~form~Visible then shown = shown p~pageTitle
    end
    s = s "|" tc~SelectedTab~Text":" shown~strip
  end
  say "(auto)" what":" s~substr(4) "- Previous" dlg~newPushButton(IDC_PB_PREVIOUS)~Enabled "Next" dlg~newPushButton(IDC_PB_NEXT)~Enabled


::class 'ListViewDlg' subclass TabOwnerDemo_IDD_LISTVIEW_DLG inherit ControlDialog   -- ooDialog: subclass ResControlDialog

::method initDialog
    expose lv

    -- (.NET version) ooDialog: self~initUpdateListView(IDC_LV_MAIN): nothing to do
    sd = filespec("location", .context~package~name)     -- ooDialog: .application~srcDir

    -- Instantiate a Rexx list view object that represents the underlying
    -- Windows list-view.  The list-view style is report.
    lv = self~newListView(IDC_LV_MAIN)

    -- Set the column headers
    lv~Columns~Add("Symbol", self~px(40), "Left")                -- ooDialog: lv~insertColumn(0, "Symbol", 40) (dialog units)
    lv~Columns~Add("Quote", self~px(50), "Left")
    lv~Columns~Add("Year high", self~px(50), "Left")
    lv~Columns~Add("Year low", self~px(50), "Left")
    lv~Columns~Add("Description", self~px(120), "Left")

    -- Set the images for the items in the list-view.  The list-view control was
    -- created without the SHAREIMAGES styles, so it takes care of releasing the
    -- image list when the program ends.
    -- (.NET version: an ImageList of 16 x 16 images, the bitmap's strip.)
    imageList = .net~System~Windows~Forms~ImageList~new  -- ooDialog: .ImageList~create(.Size~new(16, 16), COLOR8, 4, 0)
    imageList~ImageSize = .net~System~Drawing~Size~new(16, 16)
    imageList~ColorDepth = "Depth8Bit"
    imageList~Images~AddStrip(.net~System~Drawing~Image~FromFile(sd"resources\propertySheetDemoListView.bmp"))
    lv~SmallImageList = imageList                        -- ooDialog: lv~setImageList(imageList, SMALL)

    -- Fill the list-view with random data.
    do ch = "A"~c2d to "Z"~c2d
        q = random(200)
        yh = random(400)
        yh = max(yh, q)
        yl = random(100)
        yl = min(yl, q)
        item = .net~System~Windows~Forms~ListViewItem~new(.array~of("_" || ch~d2c~copies(3) || "_", "$" || q, "$" || yh, "$" || yl, -
                  ch~d2c~copies(3) "is a fictitious company."))   -- ooDialog: lv~addRow( , random(3), ...)
        item~ImageIndex = random(3)
        lv~Items~Add(item)
    end

    -- Add full row select and the ability to drag and drop the columns to the
    -- list-view.
    lv~FullRowSelect = .true                             -- ooDialog: lv~addExtendedStyle("FULLROWSELECT HEADERDRAGDROP")
    lv~AllowColumnReorder = .true

    -- Connect 2 list-view events to Rexx methods in this dialog.  The double-
    -- click on a list-view item, and the click on a column header events.
    self~connectListViewEvent(IDC_LV_MAIN, "ACTIVATE", "onActivate")
    self~connectListViewEvent(IDC_LV_MAIN, "COLUMNCLICK")

-- Invoked when a list-view item is double-clicked.  We display a message and
-- set the focus to the next item in the list.
::method onActivate
    expose lv

    selectedItem = lv~FocusedItem~Index                  -- ooDialog: lv~focused
    symbol = lv~Items[selectedItem]~Text                 -- ooDialog: lv~itemText(selectedItem)
    price = lv~Items[selectedItem]~SubItems[1]~Text      -- ooDialog: lv~itemText(selectedItem, 1)

    question = "You have selected the stock with symbol" symbol". Do you want to order" || .endOfLine || -
               "50 shares of stock at" price"?"
    placeOrder = MessageDialog(question, self~hwnd, "Place Order for Stock", "YESNO", "QUESTION", "DEFBUTTON2" )

    cost = 50 * price~substr(2)
    if placeOrder == self~IDYES then do                  -- ooDialog: self~constDir["IDYES"]
        j = MessageDialog("Okay, your bank account will be debited $"cost "dollars.", self~hwnd, -
                         "Order Confirmation", "OK", "INFORMATION")
    end
    else do
        j = MessageDialog("That saved you $"cost "dollars.", self~hwnd, "Order Canceled", "OK", "EXCLAMATION")
    end

    lv~Items[selectedItem]~Selected = .false             -- ooDialog: lv~deselect(selectedItem)
    selectedItem += 1
    if selectedItem < lv~Items~Count then do             -- (.NET version: past the last one, nothing)
        lv~Items[selectedItem]~Focused = .true           -- ooDialog: lv~focus(selectedItem)
        lv~Items[selectedItem]~Selected = .true          -- ooDialog: lv~select(selectedItem)
    end

-- Invoked when a column header of the list-view is clicked.  We just show a
-- message box so that the user has some feedback.
-- (.NET version: the method gets .NET's (sender, e): e~Column, from 0.)
::method OnColumnClick
   use arg sender, e
   id = sender~Name
   column = e~Column
   j = MessageDialog("Column" column + 1 "was clicked in control" id, self~hwnd, "List-View Notification")

::method tabPageSetActive unguarded
  use arg owner, tab
  return 0


::class 'TreeViewDlg' subclass TabOwnerDemo_IDD_TREEVIEW_DLG inherit ControlDialog   -- ooDialog: subclass ResControlDialog

::method initDialog

    -- Instantiate a Rexx tree view object that represents the Windows tree-view
    -- control.
    tv = self~newTreeView(IDC_TV_MAIN)

    -- Create and set the ImageList for the tree view items
    sd = filespec("location", .context~package~name)
    imageList = .net~System~Windows~Forms~ImageList~new  -- ooDialog: .ImageList~create(.Size~new(32, 32), COLOR8, 10, 0)
    imageList~ImageSize = .net~System~Drawing~Size~new(32, 32)
    imageList~ColorDepth = "Depth8Bit"
    imageList~Images~AddStrip(.net~System~Drawing~Image~FromFile(sd"resources\propertySheetDemoTreeView.bmp"))
    tv~ImageList = imageList                             -- ooDialog: tv~setImageList(imageList, NORMAL)

    -- Add the tree view items.  Toys will be the root (the first argument is
    -- not omitted.  Subitems are added by omitting the first arguments.  The
    -- number of arguments omitted indicates the depth of the subitem.
    --
    -- The last numeric argument in some of the items is the index for the icon
    -- for that item in the image list.  Those items without a number will not
    -- display an icon.
    -- (.NET version: ooDialog's add, on a TreeAdder.)
    tv = .TreeAdder~new(tv)

    tv~add("Toys", 1)
    tv~add(, "Indoor", 14)
    tv~add(, , "Boys", 19)
    tv~add(, , , "Cowboys", 13)
    tv~add(, , , "Cars", 8)
    tv~add(, , , "Starwars", 9)
    tv~add(, , "Girls", 0)
    tv~add(, , , "Barby", 19)
    tv~add(, , , "Painting", 15)
    tv~add(, , , "Cooking", 13)
    tv~add(, , "Adults", 17)
    tv~add(, , , "Poker", 15)
    tv~add(, , "Technical", 16)
    tv~add(, , , "Racing cars", 8)
    tv~add(, , , "Trains", 7)
    tv~add(, "Outdoor", 11)
    tv~add(, , "Water", 22)
    tv~add(, , , "Ball", 5)
    tv~add(, , , "Soft tennis", 6)
    tv~add(, , "Sand", 12)
    tv~add(, , , "Shovel", 12)
    tv~add(, , , "Bucket", 19)
    tv~add(, , , "Sandbox", 12)
    tv~add(, , "Technical", 16)
    tv~add(, , , "Trains", 7)
    tv~add(, , , "Remote controlled", 8)
    tv~add("Office Articles", 2)
    tv~add( , "Tools", 16)
    tv~add( , "Books", 19)
    tv~add( , , "Introduction", 14)
    tv~add( , , "Advanced Programming", 17)
    tv~add( , , "Tips & Tricks", 16)
    tv~add("Hardware", 4)
    tv~add( , "Garden", 0)
    tv~add( , "Handyman", 18)
    tv~add( , "Household", 18)
    tv~add("Furniture", 3)
    tv~add( , "Standard", 12)
    tv~add( , "Luxury", 21)

    -- Connecting the begin drag event and using the default tree drag handler
    -- allows us to suppport drag and drop (using the default behaviour.
    self~connectTreeViewEvent(IDC_TV_MAIN, "BeginDrag", "DefTreeDragHandler")

::method tabPageSetActive unguarded
  use arg owner, tab
  return 0


::class 'ProgressBarDlg' subclass TabOwnerDemo_IDD_PROGRESSBAR_DLG inherit ControlDialog   -- ooDialog: subclass ResControlDialog

::method initDialog unguarded
  expose threadsStarted processes

  threadsStarted = 0
  processes = .array~of('animateProgressA', 'animateProgressB', 'animateProgressC',  -
                        'animateProgressD', 'animateProgressE')
  self~activateThreads

-- (.NET version: each "thread" is a timer, on this thread.)
::method activateThreads unguarded
    expose threadsStarted processes
    use arg propSheet

    -- If no threads are running, start a thread to run each progress bar
    -- asynchronously.
    if threadsStarted < 1 then do
        threadsStarted = processes~items
        do methodName over processes
            self~send(methodName)                        -- ooDialog: self~start(methodName)
        end
    end

::method tabPageKillActive unguarded
  use strict arg owner, tab
  return .true

::method tabPageSetActive unguarded
  use arg owner, tab
  self~activateThreads
  return 0

-- This is the generic method that simulates some type of processing that takes
-- a long time.  The progress of this processing is displayed by the progress
-- bar. to simulate a process of which the progress is displayed by a progress bar */
-- (.NET version: the loop is an Animator's timer: one step each tsleep ms.)
::method animateProgress unguarded
   use arg progressBar, label, step, iterations, tsleep

   progressBar~Minimum = 0                               -- ooDialog: progressBar~setRange(0, iterations * step)
   progressBar~Maximum = iterations * step
   progressBar~Step = step                               -- ooDialog: progressBar~setStep(step)
   return .Animator~new(self, progressBar, label, step, iterations, tsleep)

-- (.NET version) an Animator's process has ended
::method processEnded unguarded
   expose threadsStarted
   threadsStarted -= 1

-- The following 5 methods are started asynchronously to animate the progress
-- bars.
::method animateProgressA unguarded
   expose pbA labelA

   pbA = self~newProgressBar(IDC_PBAR_PROCESSA)
   labelA = self~newStatic(IDC_ST_PERCENTA)

   self~animateProgress(pbA, labelA, 5, 20, 600)

::method animateProgressB unguarded
   expose pbB labelB

   pbB = self~newProgressBar(IDC_PBAR_PROCESSB)
   labelB = self~newStatic(IDC_ST_PERCENTB)

   self~animateProgress(pbB, labelB, 1, 100, 150)

::method animateProgressC unguarded
   expose pbC labelC

   pbC = self~newProgressBar(IDC_PBAR_PROCESSC)
   labelC = self~newStatic(IDC_ST_PERCENTC)

   self~animateProgress(pbC, labelC, 2, 50, 200)

::method animateProgressD unguarded
    expose pbD labelD

    pbD = self~newProgressBar(IDC_PBAR_PROCESSD)
    labelD = self~newStatic(IDC_ST_PERCENTD)

    self~animateProgress(pbD, labelD, 10, 40, 300)

::method animateProgressE unguarded
    expose pbE labelE

    pbE = self~newProgressBar(IDC_PBAR_PROCESSE)
    labelE = self~newStatic(IDC_ST_PERCENTE)

    self~animateProgress(pbE, labelE, 20, 50, 500)

::method running                                         -- (.NET version) how many processes still run
    expose threadsStarted
    return threadsStarted


::class 'TrackBarDlg' subclass TabOwnerDemo_IDD_TRACKBAR_DLG inherit ControlDialog   -- ooDialog: subclass ResControlDialog

::method initDialog
    expose font1 trackBars tbLabels

    -- As we initialize each track bar we'll stash the Rexx object in a table
    -- for easy access later, indexed by its numeric resource id.  The same
    -- thing is done for the static control that is the label for the track bar.
    -- (.NET version: by its id, a name.)
    trackBars = .table~new
    tbLabels = .table~new

    -- For the horizonatal track bars we'll use a big font for the label.
    font1 = self~CreateFontEx("Arial", 24, "BOLD")

    -- The symbolic IDs for the track bars / labels are named after the style
    -- of the track bar.  Vertical or horizontal and where the ticks are placed.

    -- Initialize the horizontal track bar with ticks on the bottom.
    tb = self~newTrackBar(IDC_TB_HORZ_BOTTOM)
    label = self~newStatic(IDC_ST_HORZ_BOTTOM)

    tb~TickFrequency = 10                                -- ooDialog: tb~setTickFrequency(10)
    tb~Value = 20                                        -- ooDialog: tb~setPos(20, .true)
    label~Text = 20
    label~Font = font1

    id = IDC_TB_HORZ_BOTTOM                              -- ooDialog: self~constDir[IDC_TB_HORZ_BOTTOM]
    trackBars[id] = tb
    tbLabels[id] = label

    -- Initialize the horizontal track bar with ticks on the top.
    tb = self~newTrackBar(IDC_TB_HORZ_TOP)
    label = self~newStatic(IDC_ST_HORZ_TOP)

    call initRange tb, 0, 200                            -- ooDialog: tb~initRange(0, 200)
    tb~TickFrequency = 50
    tb~Value = 40
    label~Text = 40
    label~Font = font1

    id = IDC_TB_HORZ_TOP
    trackBars[id] = tb
    tbLabels[id] = label

    -- Initialize the horizontal track bar with ticks on the both sides.
    tb = self~newTrackBar(IDC_TB_HORZ_BOTH)
    label = self~newStatic(IDC_ST_HORZ_BOTH)

    call initSelRange tb, 20, 60                         -- ooDialog: tb~initSelRange(20, 60)
    tb~TickFrequency = 10
    tb~Value = 80
    label~Text = 80
    label~Font = font1

    id = IDC_TB_HORZ_BOTH
    trackBars[id] = tb
    tbLabels[id] = label

    -- Initialize the vertical track bar with ticks on the right.
    tb = self~newTrackBar(IDC_TB_VERT_RIGHT)
    label = self~newStatic(IDC_ST_VERT_RIGHT)

    tb~TickFrequency = 10
    tb~Value = 30
    label~Text = 30

    id = IDC_TB_VERT_RIGHT
    trackBars[id] = tb
    tbLabels[id] = label

    -- Initialize the vertical track bar with ticks on the left.
    tb = self~newTrackBar(IDC_TB_VERT_LEFT)
    label = self~newStatic(IDC_ST_VERT_LEFT)

    tb~TickFrequency = 10
    call initRange tb, 0, 400
    tb~SmallChange = 5                                   -- ooDialog: tb~setLineStep(5)
    tb~LargeChange = 50                                  -- ooDialog: tb~setPageStep(50)
    tb~Value = 90
    label~Text = 90

    id = IDC_TB_VERT_LEFT
    trackBars[id] = tb
    tbLabels[id] = label

    -- Initialize the vertical track bar with ticks on the both sides.
    tb = self~newTrackBar(IDC_TB_VERT_BOTH)
    label = self~newStatic(IDC_ST_VERT_BOTH)

    tb~TickFrequency = 5
    tb~Value = 70
    label~Text = 70

    id = IDC_TB_VERT_BOTH
    trackBars[id] = tb
    tbLabels[id] = label

    -- Connect the event notification that is sent when a track bar is moved to
    -- the onEndTrack() method.  That method will update the text label for the
    -- track bar with the new postition.
    self~connectTrackBarEvent(IDC_TB_HORZ_BOTH, "EndTrack", "onEndTrack")
    self~connectTrackBarEvent(IDC_TB_HORZ_TOP, "EndTrack", "onEndTrack")
    self~connectTrackBarEvent(IDC_TB_HORZ_BOTTOM, "EndTrack", "onEndTrack")
    self~connectTrackBarEvent(IDC_TB_VERT_RIGHT, "EndTrack", "onEndTrack")
    self~connectTrackBarEvent(IDC_TB_VERT_LEFT, "EndTrack", "onEndTrack")
    self~connectTrackBarEvent(IDC_TB_VERT_BOTH, "EndTrack", "onEndTrack")

-- Update the static contol that shows the position for a slider when the
-- user is done moving it.
-- (.NET version: the method gets .NET's (sender, e), the track bar its
-- sender, its id its Name.)
::method onEndTrack
    expose trackBars tbLabels
    use arg trackBar, e

    -- hwndTrackBar is the handle to the track bar that was moved.  Get its
    -- resource ID and use that as an index into the table of track bar objects
    -- and the table of the labels.
    id = trackBar~Name                                   -- ooDialog: self~getControlID(hwndTrackBar)
    tbLabels[id]~Text = trackBars[id]~Value

-- We use the leaving() method to clean up (delete) the font we created.  In
-- this program there is really no need to do this.  As soon as the interpreter
-- terminates, the OS cleans up the resources automatically.  The only time
-- cleaning up resources makes sense is in a long-running program that creates
-- and ends a lot of dialogs.  Then, over time, the memory usge of the program
-- would keep growing.
::method leaving
    expose font1
    self~deleteFont(font1)


::class 'TabDlg' subclass TabOwnerDemo_IDD_TAB_DLG inherit ControlDialog   -- ooDialog: subclass ResControlDialog

::method initDialog
   expose font2 font3 imageList iconsRemoved needWrite tc pb

   -- Set the iconsRemoved and needWrite to false.  These flags are used in
   -- the OnDrawTabRect() method.
   iconsRemoved = .false
   needWrite = .false

   -- Connect the draw event of the owner-drawn button.  This is sent when the
   -- button needs to be drawn.  Then connect the selection changed event of the
   -- tab control.  This is sent when the user clicks on a different tab.
   self~connectDraw(IDC_PB_OWNERDRAW, "onDrawTabRect")
   self~connectTabEvent(IDC_TAB_MAIN, "SELCHANGE", "onTabSelChange")

   tc = self~newTab(IDC_TAB_MAIN)
   if tc == .nil then return

   -- Create a font used to display the name of the color in the owner-drawn
   -- button.  Create another font used to display some informative text.
   font2 = self~createFontEX("Arial", 48, "BOLD ITALIC")
   font3 = self~createFontEx("Arial", 16, "BOLD")

   -- Add all the tabs, including the index into the image list for an icon for
   -- each tab.
   -- (.NET version: a TabPage for each, ooDialog's tc~AddFullSeq("Red", 0, , "Green", 1, , ...).)
   do t over .array~of("Red", "Green", "Moss", "Blue", "Purple", "Cyan", "Gray")
      page = .net~System~Windows~Forms~TabPage~new(t)
      page~ImageIndex = tc~TabPages~Count
      tc~TabPages~Add(page)
   end

   -- Create a COLORREF (pure white) and load our bitmap.  The bitmap is a
   -- series of 16x16 images, each one a colored letter.
   sd = filespec("location", .context~package~name)

   -- Create our image list, as a masked image list.
   -- (.NET version: white is its TransparentColor.)
   imageList = .net~System~Windows~Forms~ImageList~new   -- ooDialog: .ImageList~create(.Size~new(16, 16), 'COLOR24 MASK', 10, 0)
   imageList~ImageSize = .net~System~Drawing~Size~new(16, 16)
   imageList~ColorDepth = "Depth24Bit"
   imageList~TransparentColor = .net~System~Drawing~Color~White   -- ooDialog: .Image~colorRef(255, 255, 255)
   imageList~Images~AddStrip(.net~System~Drawing~Image~FromFile(sd"resources\propertySheetDemoTab.bmp"))   -- ooDialog: imageList~addMasked(image, cRef)
   tc~ImageList = imageList                              -- ooDialog: tc~setImageList(imageList)

  -- We will position and size the owner-draw button so that it exactly covers
  -- the display area of the tab control.
  pb = self~newPushButton(IDC_PB_OWNERDRAW)
  self~placeButton
  tc~SizeChanged += .net~handler(self, "placeButton")    -- (.NET version: and when the tab control's size changes)

-- (.NET version) the owner-drawn button over the tab control's display area,
-- in front of it: ooDialog's tc~windowRect, calcDisplayRect, screen2client,
-- pb~setWindowPos(tc~hwnd, ...)
::method placeButton unguarded
   expose tc pb
   r = tc~DisplayRectangle                               -- (in the tab control's coordinates)
   pb~Bounds = .net~System~Drawing~Rectangle~new(tc~Left + r~X, tc~Top + r~Y, r~Width, r~Height)
   pb~BringToFront
   pb~Invalidate


-- When a new tab is selected, we have the owner-drawn button update itself.
-- This causes the button to redraw and the onDrawTabRect() method gets invoked,
-- which actually does the drawing.
::method onTabSelChange
   button = self~newPushButton(IDC_PB_OWNERDRAW)
   button~Invalidate                                     -- ooDialog: button~update


-- Fill the owner-drawn button with the color matching the tab's label and write
-- the name of the color.
-- (.NET version: the button's Paint; e~Graphics is its device context.)
::method onDrawTabRect
   expose font2 font3 imageList iconsRemoved needWrite
   use arg button, e

   tc = self~newTab(IDC_TAB_MAIN)

   -- Each time the 'Gray' tab is selected, we remove the tab icons.  Then, when
   -- one of the other tabs is selected we set the  image list back.
   currentTab = tc~SelectedTab~Text                      -- ooDialog: tc~selected
   if currentTab == 'Gray' then do
      if \iconsRemoved then do                           -- (.NET version: once; setting it repaints)
        tc~ImageList = .nil
        iconsRemoved = .true
        needWrite = .true
      end
   end
   else do
      if iconsRemoved then do
         tc~ImageList = imageList
         iconsRemoved = .false
         needWrite = .true
      end
   end

   -- Get the button's device context, create pen and brush, and assign pen,
   -- brush and font to the device context.
   g = e~Graphics                                        -- ooDialog: dc = button~getDC
   D = .net~System~Drawing
   pen = D~Pen~new(D~Color~Black, .net~single(1))        -- ooDialog: button~createPen(1, "SOLID", 0)
   brush = D~SolidBrush~new(NetDialogColor(tc~SelectedIndex + 1))   -- ooDialog: button~createBrush(tc~SelectedIndex + 1)

   -- Draw a filled in rectangle, with a border of 5 around it, and write text.
   size = button~ClientSize                              -- ooDialog: button~getRealSize
   g~FillRectangle(brush, 5, 5, size~width - 10, size~height - 10)   -- ooDialog: button~rectangle(dc, 5, 5, size~width - 5, size~height - 5, "FILL")
   g~DrawRectangle(pen, 5, 5, size~width - 11, size~height - 11)
   F = .net~System~Windows~Forms
   F~TextRenderer~DrawText(g, tc~SelectedTab~Text, font2, D~Point~new(trunc(size~width / 4), trunc(size~height / 4)), D~Color~Black)   -- ooDialog: writeDirect

   -- Add informative text if needed.
   if needWrite then do
      x = trunc(size~width / 4)
      y = trunc(size~height / 2)

      if currentTab == 'Gray' then
        F~TextRenderer~DrawText(g, "(Tab icons are removed)", font3, D~Point~new(x, y), D~Color~Black)
      else
        F~TextRenderer~DrawText(g, "(Tab icons are restored)", font3, D~Point~new(x, y), D~Color~Black)
      needWrite = .false
   end

   pen~Dispose                                           -- ooDialog: button~deleteObject(pen), ~deleteObject(brush)
   brush~Dispose

-- We use the leaving() method to clean up (delete) the fonts and the image list
-- we created.  In  this program there is really no need to do this.  As soon as
-- the interpreter terminates, the OS cleans up the resources automatically.
-- The only time cleaning up resources makes sense is in a long-running program
-- that creates and ends a lot of dialogs.  Then, over time, the memory usge of
-- the program would keep growing.
::method leaving
    expose font2 font3 imageList

    self~deleteFont(font2)
    self~deleteFont(font3)

::method tabPageSetActive unguarded
  use arg owner
  return 0


::class 'BlankDlg' subclass TabOwnerDemo_IDD_BLANK_DLG inherit ControlDialog   -- ooDialog: subclass ResControlDialog

::method initDialog
  self~connectHelp(onHelp)

::method onHelp unguarded
--say 'Got onHelp hwnd' self~hwnd


/* (.NET version) ooDialog's TreeView add(): the arguments omitted at first
   give the depth (none: a root), then the text and the image's index */
::class TreeAdder
::method init
  expose tv levels
  use strict arg tv
  levels = .array~new
::method add
  expose tv levels
  depth = 1
  do while \arg(depth, "E")
    depth += 1
  end
  text = arg(depth)
  node = .net~System~Windows~Forms~TreeNode~new(text)
  if arg(depth + 1, "E") then do
    node~ImageIndex = arg(depth + 1)
    node~SelectedImageIndex = arg(depth + 1)
  end
  if depth = 1 then tv~Nodes~Add(node)
  else levels[depth - 1]~Nodes~Add(node)
  levels[depth] = node
  return node

/* (.NET version) a progress bar's process: a step each ms milliseconds, on
   a timer (ooDialog's animateProgress loop, on a thread of its own) */
::class Animator
::method init
  expose dialog bar label step iterations i timer
  use strict arg dialog, bar, label, step, iterations, ms
  i = 0
  timer = .net~System~Windows~Forms~Timer~new
  timer~Interval = ms
  timer~Tick += .net~handler(self, "TICK")
  timer~Start
::method tick
  expose dialog bar label step iterations i timer
  if bar~IsDisposed then do                              -- (ooDialog: \ self~isDialogActive)
    timer~Stop
    return
  end
  i += 1
  bar~PerformStep                                        -- ooDialog: progressBar~step
  if (iterations * step == 100) then label~Text = i * step "%"
  else label~Text = i * step
  if i >= iterations then do
    timer~Stop
    dialog~processEnded
  end

/* (.NET version) ooDialog's TrackBar initRange and initSelRange: the
   selection by Windows' own messages (TBM_SETSELSTART, TBM_SETSELEND) */
::routine initRange
  use strict arg tb, min, max
  tb~Minimum = min
  tb~Maximum = max
  return 0

::routine initSelRange
  use strict arg tb, min, max
  call sendWinIntMsg tb, 1035, 0, min                    -- TBM_SETSELSTART (0x40B)
  call sendWinIntMsg tb, 1036, 1, max                    -- TBM_SETSELEND (0x40C), redrawn
  return 0
