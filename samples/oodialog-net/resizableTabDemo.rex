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

/** Tab Control / Dialog Controls / ControlDialog Example
 *
 * This example demonstrates how to use the ControlDialog class to provide the
 * pages / content of a Tab control.  It is basically the same as the
 * PropertySheetDemo.rex example, but uses a Tab control with ControlDialog
 * objects rather than using a PropertySheetDialog.
 *
 * Note that this example is meant to demonstrate creating a resizable dialog
 * that has a tab control with ControlDialog dialogs as pages.  It is exactly
 * the same as the
 *
 *   oodialog\propertySheet.tabControls\TabDemo.rex
 *
 * example, except it is resizable.
 *
 * (.NET version of ooDialog's resizableDialogs\ResizingAdmin\TabDemo.rex, on
 * Windows Forms through oodnet.cls; it is TabDemo.rex here with the
 * original's changes: the defineSizing methods, oodnet.cls's ResizingAdmin
 * sizing the dialog's controls as the window is resized, each page's
 * controls as its panel is, and the pages themselves to the tab control's
 * display area (pagedTab). The dialogs of that directory's
 * rc\PropertySheetDemo.rc (the original loads them from its compiled
 * PropertySheetDemo.dll: the same dialogs), resizablePropertySheetDemo.rc
 * here, are classes of resizablePropertySheetDemorc.cls (rc2oodnet.rex
 * -cls); the pages inherit oodnet.cls's ControlDialog, each a Panel of the
 * main dialog placed over the tab control's display area (its
 * DisplayRectangle). The
 * pages' code is resizablePropertySheetDemo.rex's (.NET version). Selecting
 * a tab from the program raises .NET's SelectedIndexChanged, which
 * ooDialog's selectIndex does not: the program's own selections are not
 * taken for the user's.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  -- ooDialog: sd = locate(), .application~setDefaults("O", sd"rc\PropertySheetDemo.h", .false):
  -- here the ids are names.

  -- The original version of this example would take a longish period of time to
  -- appear on the screen.  Too much was being done in the initDialog() method
  -- of the .NewControlsDialog.  To improve the time between starting the
  -- program and the dialog's appearance on the screen, several steps were
  -- taken.
  --
  -- 1.) All dialogs were made ResDialog dialogs.
  --
  -- 2.) The instantiation of the dialogs used for the pages of the tab control
  --     was moved out of the initDialog() method and placed here.  Some of the
  --     work done in the initDialog() method was moved to the prep() method,
  --     which is invoked before the dialog is started executing.
  --
  -- 3.) The dialog is created with the VISIBLE style.  This causes the dialog
  --     to appear on the screen before the list view is populated, rather than
  --     having the list view populated first and then showing the dialog.
  --
  -- Instantiate all the control dialogs and pass them to the prep() method in
  -- an array.
  t1 = .ListViewDlg~new                                   -- ooDialog: .ListViewDlg~new(sd"rc\PropertySheetDemo.dll", IDD_LISTVIEW_DLG)
  t2 = .TreeViewDlg~new
  t3 = .ProgressBarDlg~new
  t4 = .TrackBarDlg~new
  t5 = .TabDlg~new

  tabContent = .array~of(t1, t2, t3, t4, t5)

  -- Create the main dialog.
  dlg = .NewControlsDialog~new                            -- ooDialog: .NewControlsDialog~new(sd'rc\PropertySheetDemo.dll', IDD_NEWCONTROLS_DLG)

  -- Invoke the prep() methods of the list view and progress bar dialogs to do
  -- some initial set up before we start executing the main dialog.  Note that
  -- the list view (t1) dialog needs to have its owner dialog set before
  -- invoking the prep method.
  t1~ownerDialog = dlg
  t1~prep
  t3~prep

  -- Invoke the main dialog's prep() method to do some initial set up before the
  -- dialog is started executing.
  dlg~prep(tabContent)

  -- Show and run the dialog.
  dlg~execute('SHOWTOP', IDI_DLG_OODIALOG)

  return 0

::requires "resizablePropertySheetDemorc.cls"

::class 'NewControlsDialog' subclass ResizablePropertySheetDemo_IDD_NEWCONTROLS_DLG inherit ResizingAdmin

::attribute tabContent

::method defineSizing

    -- In order for the ResizingAdmin to properly size ControlDialog dialogs
    -- used as pages in a tab control, it must be informed of the dialogs and
    -- what tab control they are in.  We do that by creating an array of their
    -- IDs and pass the tab control's resource ID and the array to the
    -- pagedTab() method.
    --
    -- Note that the dialog IDs must be the dlgID attribute of the dialogs.  In
    -- this case the resource ID of the dialog has the same value as the dlgID
    -- attribute, but this is not always the case.  Please read the doc tor the
    -- dlgID attribute in the ooDialog reference manual to understand this.

    dlgIDs = .array~of(IDD_LISTVIEW_DLG, IDD_TREEVIEW_DLG, IDD_PROGRESSBAR_DLG, -
                       IDD_TRACKBAR_DLG, IDD_TAB_DLG)
    self~pagedTab(IDC_TAB, dlgIDs)

    -- Now, we have 5 controls in this the main dialog.  The tab control and 4
    -- push buttons.  We define the sizing for all edges of the tab control at
    -- one time.  We want the tab control edges to remain the same distance
    -- from each corresponding edge of the dialog.  So we use a stationary pin
    -- type.  The pin to window is the dialog, which is the default, so we do
    -- not need to specify the third index in the array.
    self~controlSizing(IDC_TAB,                                -
                       .array~of('STATIONARY', 'LEFT'),        -
                       .array~of('STATIONARY', 'TOP'),         -
                       .array~of('STATIONARY', 'RIGHT'),       -
                       .array~of('STATIONARY', 'BOTTOM')       -
                      )

    -- For the 4 push buttons, we want them to remain fixed in size, with the
    -- Previous and Next buttons pinned to the bottom left of the dialog and the
    -- Ok and Cancel buttons pinned to the right bottom of the dialog.
    --
    -- There is probably some clever use of the default sizing that could reduce
    -- the number of lines of code here, but it is sometimes better to just
    -- spell everything out in code so that it is obvious what is happening.

    self~controlSizing(IDC_PB_PREVIOUS,                        -
                       .array~of('STATIONARY', 'LEFT'),        -
                       .array~of('STATIONARY', 'BOTTOM'),      -
                       .array~of('MYLEFT',     'LEFT'),        -
                       .array~of('MYTOP',      'TOP')          -
                      )

    -- Pin the left of the Next button to the right of the Previous button
    self~controlSizing(IDC_PB_NEXT,                                       -
                       .array~of('STATIONARY', 'RIGHT', IDC_PB_PREVIOUS), -
                       .array~of('STATIONARY', 'BOTTOM'),                 -
                       .array~of('MYLEFT',     'LEFT'),                   -
                       .array~of('MYTOP',      'TOP')                     -
                      )

    -- Ror the Ok and Cancel buttons, we just do a sort of 'mirror-image' of
    -- what we just did for the Previous and Next buttons.

    self~controlSizing(IDCANCEL,                           -
                       .array~of('STATIONARY', 'RIGHT'),   -
                       .array~of('STATIONARY', 'BOTTOM'),  -
                       .array~of('MYLEFT',     'LEFT'),    -
                       .array~of('MYTOP',      'TOP')      -
                      )

    -- Pin the left of the Ok button to the left of the Cancel button
    self~controlSizing(IDOK,                                       -
                       .array~of('STATIONARY', 'LEFT', IDCANCEL),  -
                       .array~of('STATIONARY', 'BOTTOM'),          -
                       .array~of('MYLEFT',     'LEFT'),            -
                       .array~of('MYTOP',      'TOP')              -
                      )

    -- We register to recieve a notification when the sizing of the dialog has
    -- ended.  We need this event so we can invoke the placeButton() method in
    -- our child, TabDlg, dialog.  In the TabDlg dialog, there is an owner-drawn
    -- button that serves as the context of the tab control.  That button needs
    -- to be sized and positioned so that it completely occupies the display
    -- rectangle of the tab control.  Besides the initial sizing of the button,
    -- the sizing also has to take place every time the size of dialog has
    -- changed.  The placeButton() method does the sizing, but the TabDlg dialog
    -- has no way to know *when* the sizing should be done.  Only this, the main
    -- dialog, has a way to know when the sizing should take place.
    self~wantSizeEnded('onSizeEnded', .true)

    -- We must return 0 from this method to continue.
    return 0

/** prep()
 *
 * This method is invoked before the dialog is executed.  It does some initial
 * set up that would normally be done (by the author) in initDialog().  The
 * tabContent argument is an array of the 5 ControlDialog dialogs used as the
 * content for the 5 pages of the tab control.  This array is saved in the
 * tabContent attribute so the dialogs can be accessed when needed.
 */

/** prep()
 *
 * This method is invoked before the dialog is executed.  It does some initial
 * set up that would normally be done (by the author) in initDialog().  The
 * tabContent argument is an array of the 5 ControlDialog dialogs used as the
 * content for the 5 pages of the tab control.  This array is saved in the
 * tabContent attribute so the dialogs can be accessed when needed.
 */
::method prep
  expose tabContent lastSelected havePositioned selecting
  use strict arg tabContent

  -- The havePositioned array is used to determine if the page dialogs have been
  -- positioned or not.  Mark all 5 dialogs as not having been positioned yet.
  havePositioned = .array~of(.false, .false, .false, .false, .false)

  -- No tab has been selected yet
  lastSelected = 0
  selecting = .false                                      -- (.NET version: a selection by the program)

  -- Connect the event handling methods to the events we are interested in.
  self~connectButtonEvent(IDC_PB_PREVIOUS, CLICKED, onPrevious)
  self~connectButtonEvent(IDC_PB_NEXT, CLICKED, onNext)
  self~connectTabEvent(IDC_TAB, SELCHANGE, onNewTab)


/** initDialog()
 *
 * Initialize the underlying Windows dialog.  This includes setting up the tab
 * control tabs, executing the dialog used for the first tab, and positioning
 * the dialog over the display area of the tab control.  There are 5
 * .ControlDialog dialogs.  The dialogs are used for the display
 * area of the tab control, one control dialog for each tab of the tab control.
 */
::method initDialog
  expose tabContent tabControl pbNext pbPrevious needCalculation

  needCalculation = .true

  -- Start executing the control dialog for the first tab in the tab control.
  -- We can not resize and reposition the control dialog until the underlying
  -- dialog is created, so we get it started, then do our other tasks.
  dlg = tabContent[1]
  dlg~execute

  -- Add the tabs to the tab control.
  tabControl = self~newTab(IDC_TAB)
  do t over .array~of("List View", "Tree View", "Progress Bar", "Track Bar", "Tab")   -- ooDialog: tabControl~addSequence(...)
    tabControl~TabPages~Add(t)
  end

  -- Save a reference to the push buttons.
  pbNext = self~newPushButton(IDC_PB_NEXT)
  pbPrevious = self~newPushButton(IDC_PB_PREVIOUS)

  -- Position and show the control dialog used for the first page of the tab.
  self~positionAndShow(1)


/** calculateDisplayArea()
 *
 * Tab controls contain two areas, the tabs themselves and the display area.
 * The display area is where the content for each tab is drawn.
 *
 * We need to match the control dialog(s) size and position with the display
 * area size and position.  There are two approaches here:
 *
 * We could calculate the size of the largest dialog, resize the tab control to
 * match, and position the control dialog over the display area.
 *
 * We can get the size and position of the tab control's display area and resize
 * and reposition the control dialog(s) to match.  This is the approach we use
 * here.
 *
 * (.NET version: the tab control's DisplayRectangle, in its own coordinates.)
 */
::method calculateDisplayArea private
  expose tabControl displayRect

  -- Given a rectangle describing the tab control's size and position, the tab
  -- control itself will calculate the display area's size and position.
  r = tabControl~DisplayRectangle                         -- ooDialog: tabControl~windowRect, ~calcDisplayRect(r)

  -- Create our display rectangle.  This is used in setWindowPosition(), which
  -- takes a point / size rectangle.  ooDialog defines a point / size rectangle
  -- as using the left and top attributes for the position of the upper left
  -- corner of a rectangle, using the right attribute for the width of the
  -- rectangle, and using the bottom attribute for the height of the rectangle.
  displayRect = .NetRect~new(tabControl~Left + r~X, tabControl~Top + r~Y, r~Width, r~Height)   -- ooDialog: .Rect~new(p~x, p~y, s~width, s~height)


/** positionAndShow()
 *
 * Used to resize and reposition one of the control dialogs so it occupies the
 * display area of the tab control.
 *
 * (.NET version: the control dialog's panel exists as soon as it executes.)
 */
::method positionAndShow private
  expose tabControl tabContent displayRect lastSelected havePositioned needCalculation
  use strict arg index

  dlg = tabContent[index]

  if lastSelected <> 0 then tabContent[lastSelected]~hide

  -- Determine the position and size of the display area of the tab control.
  -- Note: in the non-resizable example program, we only calculate the display
  -- rect once.  Here we need to calculate it every time the dialog has been
  -- resized.  To avoid calculating the display rectangle over and over when it
  -- is not needed, we track when the dialog has been resized using the
  -- needCalculation variable and only do the calculation when necessary.
  if needCalculation then do
      self~calculateDisplayArea
      needCalculation = .false
  end

  -- Now resize and reposition the control dialog to the tab control's display
  -- area.  We need to position the control dialog *above* the tab control in
  -- the Z-order so that it shows.
  dlg~setWindowPos(tabControl~Handle, displayRect, "SHOWWINDOW NOOWNERZORDER")

  -- Normally this redraw is not needed.  But, for resizable dialogs, when the
  -- main dialog is resized before the page dialog has been started, when the
  -- page dialog is started and sized to the display rect, it does not always
  -- paint correctly.  Invoking the redraw() method seems to fix that problem.
  -- (.NET version: here, not on another thread with start('REDRAW'): Windows
  -- Forms' controls belong to the thread that made them.)
  self~redraw

  lastSelected = index
  havePositioned[index] = .true

  self~checkButtons


-- The onSizeEnded() method is invoked when the user has resized the dialog and
-- that sizing is ended.  At this point the TabDlg dialog needs to recalculate
-- and position the owner-drawn button.  Also, at this point we need to
-- recalculate the display
::method onSizeEnded unguarded
    expose tabContent needCalculation

    needCalculation = .true

    tabContent[5]~placeButton

    return 0


::method onNewTab
  expose tabControl tabContent havePositioned lastSelected selecting

  if selecting then return                                -- (.NET version: the program's selection, handled there)

  index = tabControl~SelectedIndex + 1
  dlg = tabContent[index]

  if havePositioned[index] then do
    last = tabContent[lastSelected]
    last~hide
    dlg~show
    lastSelected = index
  end
  else do
    dlg~ownerDialog = self
    dlg~execute
    self~positionAndShow(index)
    if index == 5 then dlg~placeButton
  end
  if index == 3 then dlg~activateThreads

  self~checkButtons


::method onNext unguarded
  expose tabControl

  self~selectIndex(tabControl~SelectedIndex + 1)          -- ooDialog: tabControl~selectIndex(tabControl~selectedIndex + 1)
  self~onNewTab


::method onPrevious unguarded
  expose tabControl

  self~selectIndex(tabControl~SelectedIndex - 1)
  self~onNewTab

-- (.NET version) ooDialog's selectIndex, which does not notify SELCHANGE
::method selectIndex private unguarded
  expose tabControl selecting
  use strict arg index

  if index < 0 | index >= tabControl~TabCount then return  -- (ooDialog's fails quietly)
  selecting = .true
  tabControl~SelectedIndex = index
  selecting = .false

::method checkButtons private
  expose tabControl pbNext pbPrevious

  index = tabControl~SelectedIndex + 1
  if index == 1 then do
    pbPrevious~Enabled = .false                           -- ooDialog: pbPrevious~disable
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


::method cancel
  expose tabContent

  do dlg over tabContent
    dlg~endExecution(.false)
  end

  return self~cancel:super

::method ok
  expose tabContent

  do dlg over tabContent
    dlg~endExecution(.true)
  end

  return self~ok:super

::method autoRun unguarded                                -- (.NET version) unattended: Next to the last tab, resized, OK
  expose tabControl tabContent displayRect
  say "(auto) display area:" displayRect~left displayRect~top displayRect~right displayRect~bottom "- tabs:" tabControl~TabCount
  do 4
    self~onNext
    i = tabControl~SelectedIndex + 1
    shown = ""
    do k = 1 to tabContent~items
      if tabContent[k]~isDialogActive then if tabContent[k]~form~Visible then shown = shown k
    end
    say "(auto) Next:" tabControl~SelectedTab~Text "- page shown:" shown~strip "- Previous" self~newPushButton(IDC_PB_PREVIOUS)~Enabled "Next" self~newPushButton(IDC_PB_NEXT)~Enabled
  end
  -- resized: 120 pixels wider, 90 taller
  f = self~form
  okB = self~newPushButton(IDOK); prevB = self~newPushButton(IDC_PB_PREVIOUS)
  pb = tabContent[5]~newPushButton(IDC_PB_OWNERDRAW)
  b = .array~of(tabControl~Width, tabControl~Height, okB~Left, okB~Top, prevB~Left, prevB~Top, pb~Width, pb~Height, tabContent[5]~form~Width)
  f~Size = .net~System~Drawing~Size~new(f~Width + 120, f~Height + 90)
  self~onSizeEnded
  say "(auto) resizable:" f~FormBorderStyle~string"; 120 x 90 more: the tab control +"tabControl~Width - b[1] "+"tabControl~Height - b[2]", OK moved" okB~Left - b[3] okB~Top - b[4]", Previous" prevB~Left - b[5] prevB~Top - b[6]
  say "(auto)   the page shown, its owner-drawn button: +"tabContent[5]~form~Width - b[9]"," "+"pb~Width - b[7] "+"pb~Height - b[8]
  lv = tabContent[1]~newListView(IDC_LV_MAIN)
  dr = tabControl~DisplayRectangle
  say "(auto)   a hidden page sized too: the list view's page" tabContent[1]~form~Width "x" tabContent[1]~form~Height "(the display area" dr~Width "x" dr~Height"), the list view" lv~Width "x" lv~Height
  self~onPrevious
  say "(auto) Previous:" tabControl~SelectedTab~Text
  bars = tabContent[3]
  say "(auto) progress bars running:" bars~running
  say "(auto) list view:" lv~Items~Count "rows; tree view:" tabContent[2]~newTreeView(IDC_TV_MAIN)~Nodes~Count "roots"
  self~ok


::class 'ListViewDlg' subclass ResizablePropertySheetDemo_IDD_LISTVIEW_DLG inherit ControlDialog ResizingAdmin   -- ooDialog: subclass ResControlDialog inherit ResizingAdmin

::method defineSizing

    -- The only control in this dialog is the list-view.  We define its sizing
    -- so that each edge of the list-view maintains the same distance to its
    -- corresponding edeg of the dialog:
    self~controlSizing(IDC_LV_MAIN,                            -
                       .array~of('STATIONARY', 'LEFT'),        -
                       .array~of('STATIONARY', 'TOP'),         -
                       .array~of('STATIONARY', 'RIGHT'),       -
                       .array~of('STATIONARY', 'BOTTOM')       -
                      )

    -- A value must be returned from the defineSizing() method.  O allows the
    -- dialog to continue, any other values is a failure and the dialog will be
    -- ended.
    return 0


::method initDialog
    expose lv imageList listData

    -- Instantiate a Rexx list view object that represents the underlying
    -- Windows list-view.  The list-view style is report.
    lv = self~newListView(IDC_LV_MAIN)

    -- Set the column headers
    lv~Columns~Add("Symbol", self~px(40))                -- ooDialog: lv~insertColumn(0, "Symbol", 40) (dialog units)
    lv~Columns~Add("Quote", self~px(50))
    lv~Columns~Add("Year high", self~px(50))
    lv~Columns~Add("Year low", self~px(50))
    lv~Columns~Add("Description", self~px(120))

    -- Set the image list for the list view.
    lv~SmallImageList = imageList                        -- ooDialog: lv~setImageList(imageList, SMALL)

    -- Fill the list-view with the data prepared in prep().
    do row over listData
        item = .net~System~Windows~Forms~ListViewItem~new(.array~of(row[2], row[3], row[4], row[5], row[6]))   -- ooDialog: lv~addRow( , row[1], ...)
        item~ImageIndex = row[1]
        lv~Items~Add(item)
    end

    -- Add full row select and the ability to drag and drop the columns to the
    -- list-view.
    lv~FullRowSelect = .true                             -- ooDialog: lv~addExtendedStyle("FULLROWSELECT HEADERDRAGDROP")
    lv~AllowColumnReorder = .true

    lv~Select                                            -- ooDialog: lv~assignFocus

/** onActivate
 *
 * Invoked when a list-view item is double-clicked.  We display a message and
 * set the focus to the next item in the list.
 */
::method onActivate
    expose lv

    selectedItem = lv~FocusedItem~Index                  -- ooDialog: lv~focused
    symbol = lv~Items[selectedItem]~Text                 -- ooDialog: lv~itemText(selectedItem)
    price = lv~Items[selectedItem]~SubItems[1]~Text

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
        lv~Items[selectedItem]~Focused = .true
        lv~Items[selectedItem]~Selected = .true
    end

/** onColumnClick()
 *
 * Invoked when a column header of the list-view is clicked.  We just show a
 * message box so that the user has some feedback.
 *
 * (.NET version: the method gets .NET's (sender, e): e~Column, from 0.)
 */
::method onColumnClick
   use arg sender, e
   msg = "Column" e~Column + 1 "was clicked in control" sender~Name
   j = MessageDialog(msg, self~hwnd, "List-View Notification")

/** prep()
 *
 * Does some initial set up for the list view dialog.  This is moved out of the
 * initDialog() method to, perhaps, help populate the list view a little
 * quicker.
 */
::method prep
    expose imageList listData

    -- (.NET version) ooDialog: self~initUpdateListView(IDC_LV_MAIN): nothing to do

    sd = filespec("location", .context~package~name)     -- ooDialog: .application~srcDir
    imageList = .net~System~Windows~Forms~ImageList~new  -- ooDialog: .ImageList~create(.Size~new(16, 16), COLOR8, 4, 0)
    imageList~ImageSize = .net~System~Drawing~Size~new(16, 16)
    imageList~ColorDepth = "Depth8Bit"
    imageList~Images~AddStrip(.net~System~Drawing~Image~FromFile(sd"resources\propertySheetDemoListView.bmp"))

    listData = .array~new(26)
    do ch = "A"~c2d to "Z"~c2d
        q = random(200)
        yh = random(400)
        yh = max(yh, q)
        yl = random(100)
        yl = min(yl, q)

        row = .array~new(6)
        row[1] = random(3)
        row[2] = "_" || ch~d2c~copies(3) || "_"
        row[3] = "$" || q
        row[4] = "$" || yh
        row[5] = "$" || yl
        row[6] = ch~d2c~copies(3) "is a fictitious company."
        listData~append(row)
    end

    self~connectListViewEvent(IDC_LV_MAIN, "ACTIVATE", "onActivate")
    self~connectListViewEvent(IDC_LV_MAIN, "COLUMNCLICK")


::class 'TreeViewDlg' subclass ResizablePropertySheetDemo_IDD_TREEVIEW_DLG inherit ControlDialog ResizingAdmin   -- ooDialog: subclass ResControlDialog inherit ResizingAdmin

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



::class 'ProgressBarDlg' subclass ResizablePropertySheetDemo_IDD_PROGRESSBAR_DLG inherit ControlDialog ResizingAdmin   -- ooDialog: subclass RcControlDialog inherit ResizingAdmin

-- Define the sizing for the controls.  Note that for the progress bars, we want
-- to use the default sizing so that they resize proportionally.  But, we want
-- the static labels to be fixed in size and pinned to the progress bar the
-- label is for.
--
-- The individual sizing for a control is added to the sizing table in the order
-- the sizings are defined.  Then, during a resize event, the windows are sized
-- in the order they occur in the table.  For any control sizing definition, the
-- pin to window has to *precede* the control in the table.  Otherwise resizing
-- would not work correctly.
--
-- What this means is that we can not pin a static control to its progress bar
-- unless the progress bar is already in the table.  The defaultSizing() method
-- allows us to put a control in to the table with a minimum amount of typing.
--
-- We also show both ways of defing the edges of a control.  Using individual
-- method calls for each edge, or using the single method call, controlSizing().
::method defineSizing

    self~noMinSize

    self~useDefaultSizing(IDC_PBAR_PROCESSA)
    self~useDefaultSizing(IDC_PBAR_PROCESSB)
    self~useDefaultSizing(IDC_PBAR_PROCESSC)
    self~useDefaultSizing(IDC_PBAR_PROCESSD)
    self~useDefaultSizing(IDC_PBAR_PROCESSE)

    self~controlLeft(  IDC_ST_PROCESSA, 'STATIONARY', 'XCENTER', IDC_PBAR_PROCESSA)
    self~controlTop(   IDC_ST_PROCESSA, 'STATIONARY', 'TOP',     IDC_PBAR_PROCESSA)
    self~controlRight( IDC_ST_PROCESSA, 'MYLEFT',     'LEFT')
    self~controlBottom(IDC_ST_PROCESSA, 'MYTOP',      'TOP')

    self~controlLeft(  IDC_ST_PROCESSB, 'STATIONARY', 'XCENTER', IDC_PBAR_PROCESSB)
    self~controlTop(   IDC_ST_PROCESSB, 'STATIONARY', 'TOP',     IDC_PBAR_PROCESSB)
    self~controlRight( IDC_ST_PROCESSB, 'MYLEFT',     'LEFT')
    self~controlBottom(IDC_ST_PROCESSB, 'MYTOP',      'TOP')

    self~controlLeft(  IDC_ST_PROCESSC, 'STATIONARY', 'XCENTER', IDC_PBAR_PROCESSC)
    self~controlTop(   IDC_ST_PROCESSC, 'STATIONARY', 'TOP',     IDC_PBAR_PROCESSC)
    self~controlRight( IDC_ST_PROCESSC, 'MYLEFT',     'LEFT')
    self~controlBottom(IDC_ST_PROCESSC, 'MYTOP',      'TOP')

    self~controlLeft(  IDC_ST_PROCESSD, 'STATIONARY', 'XCENTER', IDC_PBAR_PROCESSD)
    self~controlTop(   IDC_ST_PROCESSD, 'STATIONARY', 'TOP',     IDC_PBAR_PROCESSD)
    self~controlRight( IDC_ST_PROCESSD, 'MYLEFT',     'LEFT')
    self~controlBottom(IDC_ST_PROCESSD, 'MYTOP',      'TOP')

    self~controlLeft(  IDC_ST_PROCESSE, 'STATIONARY', 'XCENTER', IDC_PBAR_PROCESSE)
    self~controlTop(   IDC_ST_PROCESSE, 'STATIONARY', 'TOP',     IDC_PBAR_PROCESSE)
    self~controlRight( IDC_ST_PROCESSE, 'MYLEFT',     'LEFT')
    self~controlBottom(IDC_ST_PROCESSE, 'MYTOP',      'TOP')

    self~controlSizing(IDC_ST_PERCENTA,                                        -
                       .array~of('STATIONARY', 'XCENTER', IDC_PBAR_PROCESSA),  -
                       .array~of('STATIONARY', 'BOTTOM',  IDC_PBAR_PROCESSA),  -
                       .array~of('MYLEFT',     'LEFT'),                        -
                       .array~of('MYTOP',      'TOP')                          -
                      )

    self~controlSizing(IDC_ST_PERCENTB,                                        -
                       .array~of('STATIONARY', 'XCENTER', IDC_PBAR_PROCESSB),  -
                       .array~of('STATIONARY', 'BOTTOM',  IDC_PBAR_PROCESSB),  -
                       .array~of('MYLEFT',     'LEFT'),                        -
                       .array~of('MYTOP',      'TOP')                          -
                      )

    self~controlSizing(IDC_ST_PERCENTC,                                        -
                       .array~of('STATIONARY', 'XCENTER', IDC_PBAR_PROCESSC),  -
                       .array~of('STATIONARY', 'BOTTOM',  IDC_PBAR_PROCESSC),  -
                       .array~of('MYLEFT',     'LEFT'),                        -
                       .array~of('MYTOP',      'TOP')                          -
                      )

    self~controlSizing(IDC_ST_PERCENTD,                                        -
                       .array~of('STATIONARY', 'XCENTER', IDC_PBAR_PROCESSD),  -
                       .array~of('STATIONARY', 'BOTTOM',  IDC_PBAR_PROCESSD),  -
                       .array~of('MYLEFT',     'LEFT'),                        -
                       .array~of('MYTOP',      'TOP')                          -
                      )

    self~controlSizing(IDC_ST_PERCENTE,                                        -
                       .array~of('STATIONARY', 'XCENTER', IDC_PBAR_PROCESSE),  -
                       .array~of('STATIONARY', 'BOTTOM',  IDC_PBAR_PROCESSE),  -
                       .array~of('MYLEFT',     'LEFT'),                        -
                       .array~of('MYTOP',      'TOP')                          -
                      )

  return 0


::method prep
  expose threadsStarted processes

  threadsStarted = 0
  processes = .array~of('animateProgressA', 'animateProgressB', 'animateProgressC',  -
                        'animateProgressD', 'animateProgressE')

-- (.NET version: each "thread" is a timer, on this thread.)
::method activateThreads unguarded
    expose threadsStarted processes

    -- If no threads are running, start a thread to run each progress bar
    -- asynchronously.
    if threadsStarted < 1 then do
        threadsStarted = processes~items
        do methodName over processes
            self~send(methodName)                        -- ooDialog: self~start(methodName)
        end
    end
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


::class 'TrackBarDlg' subclass ResizablePropertySheetDemo_IDD_TRACKBAR_DLG inherit ControlDialog ResizingAdmin   -- ooDialog: subclass ResControlDialog inherit ResizingAdmin

-- Define the sizing of the controls.  Here, we have the 2 static frames that
-- surround the trackbars grow proportionally to the dialog, which is the
-- deault.  Then we pin the controls inside of a static frame to the static
-- frame.
--
-- For the horizontal trackbars, it makes sense for them to stretch horizontally
-- as the dialog widens.  But there is no point in them stretching vertially as
-- the dialog get taller.  The actual part of the control that is drawn keeps
-- the same vertical height.
--
-- The reverse is true for the vertical trackbars, the should stretch vertically
-- and remain fixed horizontally.
--
-- All the static labels should remain fixed in size.  The labels for the
-- horizontal trackbars are pinned to the bottoms of their trackbars and pinned
-- proportionally to the left of their trackbars.  The labels for the vertical
-- trackbars are pinned to the top of their trackbars and to the center of their
-- trackbars.
--
-- For the horizontal trackbars: the top trakbar is pinned to the top of its
-- frame, the bottom to the bottom of its frame, and the middle trackbar is
-- pinned to the vertical center of its frame.
--
-- For the vertical trackbars: the left trackbar is pinned to the left of its
-- frame, the right is pinned to the right of its frame, and the middle trackbar
-- is pinned to the horizontal center of its frame.
::method defineSizing

    self~noMinSize

    self~useDefaultSizing(IDC_ST_FRAME_LEFT)

    self~controlLeft(  IDC_TB_HORZ_BOTTOM, 'STATIONARY', 'LEFT',  IDC_ST_FRAME_LEFT)
    self~controlTop(   IDC_TB_HORZ_BOTTOM, 'STATIONARY', 'TOP',   IDC_ST_FRAME_LEFT)
    self~controlRight( IDC_TB_HORZ_BOTTOM, 'STATIONARY', 'RIGHT', IDC_ST_FRAME_LEFT)
    self~controlBottom(IDC_TB_HORZ_BOTTOM, 'MYTOP',      'TOP')

    self~controlLeft(  IDC_ST_HORZ_BOTTOM, 'PROPORTIONAL', 'LEFT',   IDC_TB_HORZ_BOTTOM)
    self~controlTop(   IDC_ST_HORZ_BOTTOM, 'STATIONARY',   'BOTTOM', IDC_TB_HORZ_BOTTOM)
    self~controlRight( IDC_ST_HORZ_BOTTOM, 'MYLEFT',       'LEFT')
    self~controlBottom(IDC_ST_HORZ_BOTTOM, 'MYTOP',        'TOP')

    self~controlLeft(  IDC_TB_HORZ_TOP, 'STATIONARY', 'LEFT',    IDC_ST_FRAME_LEFT)
    self~controlTop(   IDC_TB_HORZ_TOP, 'STATIONARY', 'YCENTER', IDC_ST_FRAME_LEFT)
    self~controlRight( IDC_TB_HORZ_TOP, 'STATIONARY', 'RIGHT',   IDC_ST_FRAME_LEFT)
    self~controlBottom(IDC_TB_HORZ_TOP, 'MYTOP',      'TOP')

    self~controlLeft(  IDC_ST_HORZ_TOP, 'PROPORTIONAL', 'LEFT',   IDC_TB_HORZ_TOP)
    self~controlTop(   IDC_ST_HORZ_TOP, 'STATIONARY',   'BOTTOM', IDC_TB_HORZ_TOP)
    self~controlRight( IDC_ST_HORZ_TOP, 'MYLEFT',       'LEFT')
    self~controlBottom(IDC_ST_HORZ_TOP, 'MYTOP',        'TOP')

    self~controlLeft(  IDC_TB_HORZ_BOTH, 'STATIONARY', 'LEFT',   IDC_ST_FRAME_LEFT)
    self~controlTop(   IDC_TB_HORZ_BOTH, 'STATIONARY', 'BOTTOM', IDC_ST_FRAME_LEFT)
    self~controlRight( IDC_TB_HORZ_BOTH, 'STATIONARY', 'RIGHT',  IDC_ST_FRAME_LEFT)
    self~controlBottom(IDC_TB_HORZ_BOTH, 'MYTOP',      'TOP')

    self~controlLeft(  IDC_ST_HORZ_BOTH, 'PROPORTIONAL', 'LEFT',   IDC_TB_HORZ_BOTH)
    self~controlTop(   IDC_ST_HORZ_BOTH, 'STATIONARY',   'BOTTOM', IDC_TB_HORZ_BOTH)
    self~controlRight( IDC_ST_HORZ_BOTH, 'MYLEFT',       'LEFT')
    self~controlBottom(IDC_ST_HORZ_BOTH, 'MYTOP',        'TOP')

    self~useDefaultSizing(IDC_ST_FRAME_RIGHT)

    self~controlLeft(  IDC_TB_VERT_RIGHT, 'STATIONARY', 'LEFT',    IDC_ST_FRAME_RIGHT)
    self~controlTop(   IDC_TB_VERT_RIGHT, 'STATIONARY', 'TOP',     IDC_ST_FRAME_RIGHT)
    self~controlRight( IDC_TB_VERT_RIGHT, 'MYLEFT',     'LEFT')
    self~controlBottom(IDC_TB_VERT_RIGHT, 'STATIONARY', 'BOTTOM',  IDC_ST_FRAME_RIGHT)

    self~controlLeft(  IDC_ST_VERT_RIGHT, 'STATIONARY', 'XCENTER', IDC_TB_VERT_RIGHT)
    self~controlTop(   IDC_ST_VERT_RIGHT, 'STATIONARY', 'TOP',     IDC_TB_VERT_RIGHT)
    self~controlRight( IDC_ST_VERT_RIGHT, 'MYLEFT',     'LEFT')
    self~controlBottom(IDC_ST_VERT_RIGHT, 'MYTOP',      'TOP')

    self~controlLeft(  IDC_TB_VERT_LEFT, 'STATIONARY',  'XCENTER', IDC_ST_FRAME_RIGHT)
    self~controlTop(   IDC_TB_VERT_LEFT, 'STATIONARY',  'TOP',     IDC_ST_FRAME_RIGHT)
    self~controlRight( IDC_TB_VERT_LEFT, 'MYLEFT',      'LEFT')
    self~controlBottom(IDC_TB_VERT_LEFT, 'STATIONARY',  'BOTTOM',  IDC_ST_FRAME_RIGHT)

    self~controlLeft(  IDC_ST_VERT_LEFT, 'STATIONARY',  'XCENTER', IDC_TB_VERT_LEFT)
    self~controlTop(   IDC_ST_VERT_LEFT, 'STATIONARY',  'TOP',     IDC_TB_VERT_LEFT)
    self~controlRight( IDC_ST_VERT_LEFT, 'MYLEFT',      'LEFT')
    self~controlBottom(IDC_ST_VERT_LEFT, 'MYTOP',       'TOP')

    self~controlLeft(  IDC_TB_VERT_BOTH, 'STATIONARY',  'RIGHT',   IDC_ST_FRAME_RIGHT)
    self~controlTop(   IDC_TB_VERT_BOTH, 'STATIONARY',  'TOP',     IDC_ST_FRAME_RIGHT)
    self~controlRight( IDC_TB_VERT_BOTH, 'MYLEFT',      'LEFT')
    self~controlBottom(IDC_TB_VERT_BOTH, 'STATIONARY',  'BOTTOM',  IDC_ST_FRAME_RIGHT)

    self~controlLeft(  IDC_ST_VERT_BOTH, 'STATIONARY',  'XCENTER', IDC_TB_VERT_BOTH)
    self~controlTop(   IDC_ST_VERT_BOTH, 'STATIONARY',  'TOP',     IDC_TB_VERT_BOTH)
    self~controlRight( IDC_ST_VERT_BOTH, 'MYLEFT',      'LEFT')
    self~controlBottom(IDC_ST_VERT_BOTH, 'MYTOP',       'TOP')

  return 0


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


::class 'TabDlg' subclass ResizablePropertySheetDemo_IDD_TAB_DLG inherit ControlDialog ResizingAdmin   -- ooDialog: subclass ResControlDialog inherit ResizingAdmin

::method defineSizing

    self~controlSizing(IDC_TAB_MAIN,                           -
                       .array~of('STATIONARY', 'LEFT'),        -
                       .array~of('STATIONARY', 'TOP'),         -
                       .array~of('STATIONARY', 'RIGHT'),       -
                       .array~of('STATIONARY', 'BOTTOM')       -
                      )

    return 0


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
   if pb~isA(.String) then return 0                      -- (not made yet: ooDialog's "if \ tc~isA(.Tab)")
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
