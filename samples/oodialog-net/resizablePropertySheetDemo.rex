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

/** Propery Sheet / Dialog Controls Example
 *
 * This example demonstrates how to use the PropertySheetDialog and has examples
 * of using 5 dialog controls, the: List View, Tree View, Progress Bar, Track
 * Bar, and Tab.
 *
 * Note that this example is meant to demonstrate creating a resizable
 * PropertySheetDialog dialog.  It is exactly  the same as the
 *
 *   oodialog\propertySheet.tabControls\PropertySheetDemo.rex
 *
 * example, except it is resizable.
 *
 * (.NET version of ooDialog's resizableDialogs\ResizingAdmin\PropertySheetDemo.rex,
 * on Windows Forms through oodnet.cls; it is PropertySheetDemo.rex here with
 * the original's defineSizing methods: oodnet.cls's ResizingAdmin sizes the
 * property sheet's tab control and buttons as the window is resized, and each
 * page's controls as its tab page is. rc\PropertySheetDemo.rc of
 * resizableDialogs\ResizingAdmin is resizablePropertySheetDemo.rc here; its
 * dialogs are classes of resizablePropertySheetDemorc.cls (rc2oodnet.rex
 * -cls), the pages
 * subclasses of them, the property sheet a NetPropertySheet (a TabControl,
 * OK, Cancel). The controls are .NET's: a ListView and a TreeView with
 * ImageLists made from the original's bitmaps (AddStrip), vertical
 * ProgressBars (PBS_VERTICAL added to their style by oodnet.cls), TrackBars,
 * a TabControl whose display area a Panel covers, drawn on its Paint. The
 * progress bars move on timers where ooDialog starts a thread for each:
 * Windows Forms' controls belong to the thread that made them. ooDialog's
 * tree view add(), whose omitted arguments give an item's depth, is the
 * TreeAdder class below; its DefTreeDragHandler, oodnet.cls's. A track bar's
 * selection range (TBS_ENABLESELRANGE) is set by TBM_SETSELSTART and
 * TBM_SETSELEND, as Windows' own; a track bar's ENDTRACK is the user letting
 * it go (.NET's MouseUp, KeyUp).)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  -- ooDialog: .application~setDefaults("O", sd"rc\PropertySheetDemo.h", .false): here the ids are names

  -- Create the 5 dialog pages.
  p1 = .ListViewDlg~new                                   -- ooDialog: .ListViewDlg~new(sd"rc\PropertySheetDemo.rc", IDD_LISTVIEW_DLG)
  p2 = .TreeViewDlg~new
  p3 = .ProgressBarDlg~new
  p4 = .TrackBarDlg~new
  p5 = .TabDlg~new

  -- Create the PropertySheetDialog using an array of the 5 dialog pages.  The
  -- order of the pages in the array will be the order of the pages in the tab
  -- control of the property sheet.
  pages = .array~of(p1, p2, p3, p4, p5)
  propDlg = .PropertySheetDemoDlg~new(pages, "NOAPPLYNOW", "ooRexx Property Sheet with Controls")

  -- Do any customization of the property sheet dialog by setting the values of
  -- the appropriate attributes.  However, for this example we do not do any
  -- customization.

  -- Show the property sheet.
  propDlg~execute

  return 0

::requires "resizablePropertySheetDemorc.cls"

::class 'ListViewDlg' subclass ResizablePropertySheetDemo_IDD_LISTVIEW_DLG inherit ResizingAdmin

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
    -- dialog to continue, any other value is a failure and the dialog will be
    -- ended.
    return 0


::method initDialog
    expose lv

    sd = filespec("location", .context~package~name)     -- ooDialog: locate()

    -- Instantiate a Rexx list view object that represents the underlying
    -- Windows list-view.  The list-view style is report.
    lv = self~newListView(IDC_LV_MAIN)

    -- Set the column headers
    lv~Columns~Add("Symbol", self~px(40))                -- ooDialog: lv~insertColumn(0, "Symbol", 40) (dialog units)
    lv~Columns~Add("Quote", self~px(50))
    lv~Columns~Add("Year high", self~px(50))
    lv~Columns~Add("Year low", self~px(50))
    lv~Columns~Add("Description", self~px(120))

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


::class 'TreeViewDlg' subclass ResizablePropertySheetDemo_IDD_TREEVIEW_DLG inherit ResizingAdmin


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


::class 'ProgressBarDlg' subclass ResizablePropertySheetDemo_IDD_PROGRESSBAR_DLG inherit ResizingAdmin

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


::method initDialog
  expose threadsStarted processes

  threadsStarted = 0
  processes = .array~of('animateProgressA', 'animateProgressB', 'animateProgressC',  -
                        'animateProgressD', 'animateProgressE')


-- The setActive event notification is sent by the property sheet to the page
-- that is about to become the active page.  It is sent before the page is
-- visible.  This allows the page to do any initialization necessary.  For this
-- program, we use the notification to start the progress bar animation threads.
-- (.NET version: each "thread" is a timer, on this thread.)
::method setActive unguarded
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


::class 'TrackBarDlg' subclass ResizablePropertySheetDemo_IDD_TRACKBAR_DLG inherit ResizingAdmin

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
-- The reverse is true for the vertical trackbars, they should stretch
-- vertically and remain fixed horizontally.
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


::class 'TabDlg' subclass ResizablePropertySheetDemo_IDD_TAB_DLG inherit ResizingAdmin

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

::class 'PropertySheetDemoDlg' subclass NetPropertySheet inherit ResizingAdmin

-- Define the sizing for the controls in the property sheet dialog.  Note that
-- the control ID for the tab control is provided by a constant from the
-- PropertySheetDialog class.  The Ok and Cancel push buttons have the usual IDs
-- supplied by the operatting system.
--
-- We set the sizing for the tab control so that it keeps a fixed margin all the
-- way around it.  This makes the tab control expand to take up as much space in
-- the dialog as it can.  The buttons are fixed in size and pinned to the bottom
-- right corner of the dialog.
::method defineSizing

    self~controlSizing(self~IDC_TAB_IN_PROPSHEET,              -
                       .array~of('STATIONARY', 'LEFT'),        -
                       .array~of('STATIONARY', 'TOP'),         -
                       .array~of('STATIONARY', 'RIGHT'),       -
                       .array~of('STATIONARY', 'BOTTOM')       -
                      )

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

    ret = self~wantSizeEnded('onSizeEnded', .true)

    return 0;



-- The onSizeEnded() method is invoked when the user has resized the dialog and
-- that sizing is ended.  At this point the TabDlg dialog needs to recalculate
-- and position the owner-drawn button.
::method onSizeEnded unguarded
    self~pages[5]~placeButton
    return 0


::method autoRun unguarded                               -- (.NET version) unattended: each page, what it shows; a few clicks
    say "(auto)" self~pages~items "pages; the sheet's tabs:" self~control(self~IDC_TAB_IN_PROPSHEET)~TabPages~Count
    -- the list view: 26 rows; the first one double clicked (Yes or No: No, unattended)
    lvPage = self~pages[1]
    lv = lvPage~newListView(IDC_LV_MAIN)
    say "(auto) list view:" lv~Items~Count "rows," lv~Columns~Count "columns, the first" lv~Items[0]~Text"; images" lv~SmallImageList~Images~Count
    lv~Items[0]~Focused = .true
    lvPage~onActivate
    say "(auto) now focused:" lv~FocusedItem~Text
    -- the tree
    self~setCurSel(, 2)
    tv = self~pages[2]~newTreeView(IDC_TV_MAIN)
    say "(auto) tree view:" tv~Nodes~Count "roots, Toys has" tv~Nodes[0]~GetNodeCount(.true) "items, images" tv~ImageList~Images~Count
    say "(auto)   Toys > Indoor > Boys >" tv~Nodes[0]~Nodes[0]~Nodes[0]~Nodes[2]~Text "(image" tv~Nodes[0]~Nodes[0]~Nodes[0]~Nodes[2]~ImageIndex")"
    -- the progress bars, a while
    self~setCurSel(, 3)
    pPage = self~pages[3]
    call msSleep 2000
    s = ""
    do id over .array~of(IDC_PBAR_PROCESSA, IDC_PBAR_PROCESSB, IDC_PBAR_PROCESSC, IDC_PBAR_PROCESSD, IDC_PBAR_PROCESSE)
      bar = pPage~newProgressBar(id)
      s = s bar~Value"/"bar~Maximum
    end
    say "(auto) progress bars after 2 seconds:" s~strip "- running:" pPage~running "- vertical:" (pPage~newProgressBar(IDC_PBAR_PROCESSA)~Height > pPage~newProgressBar(IDC_PBAR_PROCESSA)~Width)
    -- the track bars: one moved, its label follows (ENDTRACK)
    self~setCurSel(, 4)
    tPage = self~pages[4]
    tb = tPage~newTrackBar(IDC_TB_HORZ_TOP)
    tb~Value = 150
    tPage~onEndTrack(tb, .nil)
    both = tPage~newTrackBar(IDC_TB_HORZ_BOTH)
    say "(auto) track bar moved to" tb~Value", its label:" tPage~newStatic(IDC_ST_HORZ_TOP)~Text "- selection" sendWinIntMsg(both, 1041, 0, 0)".."sendWinIntMsg(both, 1042, 0, 0)
    -- the tab control: Gray, then Blue
    self~setCurSel(, 5)
    tabPage = self~pages[5]
    tc = tabPage~newTab(IDC_TAB_MAIN)
    tc~SelectedIndex = 6
    tabPage~newPushButton(IDC_PB_OWNERDRAW)~Refresh
    say "(auto) tab" tc~SelectedTab~Text": icons" (tc~ImageList \== .nil)
    tc~SelectedIndex = 3
    tabPage~newPushButton(IDC_PB_OWNERDRAW)~Refresh
    say "(auto) tab" tc~SelectedTab~Text": icons" (tc~ImageList \== .nil)
    -- resized: 100 pixels wider, 80 taller
    f = self~form
    sheetTab = self~control(self~IDC_TAB_IN_PROPSHEET)
    okB = self~control(IDOK); cancelB = self~control(IDCANCEL)
    pb = tabPage~newPushButton(IDC_PB_OWNERDRAW)
    before = sizes()
    f~Size = .net~System~Drawing~Size~new(f~Width + 100, f~Height + 80)
    self~onSizeEnded
    say "(auto) resizable:" f~FormBorderStyle~string"; 100 x 80 more, the tab control, the owner-drawn button:" sizes(before)
    say "(auto)   OK, Cancel moved by" okB~Left - before[5] cancelB~Left - before[6]"," okB~Top - before[7]"; their size kept" (okB~Width = before[8])
    self~setCurSel(, 1)
    say "(auto)   the list view now" lv~Width "x" lv~Height
    self~ok
    return
  sizes:
    if arg() = 0 then return .array~of(sheetTab~Width, sheetTab~Height, pb~Width, pb~Height, okB~Left, cancelB~Left, okB~Top, okB~Width)
    use arg b
    return "+"(sheetTab~Width - b[1]) "+"(sheetTab~Height - b[2])"," "+"(pb~Width - b[3]) "+"(pb~Height - b[4])

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
