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
 *  Name:       oodListViews.rex
 *  Type:       Open Object Rexx (ooRexx) example
 *  Resources:  oodListViews.rc, oodListViews1.bmp, oodListViews2.bmp
 *
 *  Description:
 *
 *    Demonstrates the different views possible in the list-view control.  Shows
 *    how to use the ControlDialog class to populate each page in a tab
 *    control.  Demonstrates some other list-view features, such as info tips,
 *    user item data, in place label editing, drag and drop in icon view, etc..
 *
 *
 * Note: this program uses the public routine, locate(), to get the full path
 * name to the directory this source code file is located. In places, the
 * variable holding this value has been callously abbreviated to 'sd' which
 * stands for source directory.
 *
 * (.NET version of ooDialog's propertysheet.tabControls\oodListViews.rex, on
 * Windows Forms through oodnet.cls: rc\oodListViews.rc's dialogs are classes
 * of oodListViewsrc.cls (rc2oodnet.rex -cls); the page is a ControlDialog
 * (oodnet.cls's mixin), its owner given to new. The list view is .NET's: its
 * View, Columns, Items (a record is an item's Tag, ooDialog's item data),
 * SmallImageList and LargeImageList. Its events' methods get .NET's (sender,
 * e): e~Column, e~Item, e~Label, e~CancelEdit, e~ItemIndex, e~IsSelected.
 * .NET's list view has no info tip event: an item's ToolTipText is what
 * onGetInfoTip answers, set when the item is added or changed, and shown
 * while Use Info Tips is checked (ShowItemToolTips). The tab control's
 * minimum tab width is set by TCM_SETMINTABWIDTH, which .NET has not.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  -- ooDialog: srcDir = locate(), .application~useGlobalConstDir("O", srcDir'rc\oodListViews.h'):
  -- here the ids are names.

  dlg = .ListsDialog~new                                  -- ooDialog: .ListsDialog~new(srcDir"rc\oodListViews.rc", IDD_LISTVIEWS)

  if dlg~initCode <> 0 then do
    say "Error instantiating the ListsDialog, aborting"
    return 99
  end

  dlg~execute("SHOWTOP")

  return 0

::requires "oodListViewsrc.cls"


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     ListsDialog Class - the main (top-level) dialog.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ListsDialog' subclass OodListViews_IDD_LISTVIEWS

::method init
  expose sd

  forward class (super) continue

  if self~initCode <> 0 then return self~initCode

  sd = filespec("location", .context~package~name)       -- ooDialog: locate()

  self~createImageLists
  self~initRecords

  self~connectButtonEvent(IDC_PB_ADDRECORD,  "CLICKED", "onAdd")
  self~connectButtonEvent(IDC_PB_EDITRECORD, "CLICKED", "onEdit")
  self~connectButtonEvent(IDC_PB_FORWARD,    "CLICKED", "onForward")
  self~connectButtonEvent(IDC_PB_BACKWARD,   "CLICKED", "onBackward")

  self~connectButtonEvent(IDC_CK_INFOTIPS, "CLICKED", onCheckClicked)

  self~connectTabEvent(IDC_TAB, 'SELCHANGE', 'onNewTab')


::method initDialog
  expose tabControl pageDialog smallIcons normalIcons records pbBackward pbForward ckInfoTips sd

  -- Set the Use Info Tips check box.
  ckInfoTips = self~newCheckBox(IDC_CK_INFOTIPS)
  ckInfoTips~Checked = .true                              -- ooDialog: ckInfoTips~check

  -- Disable the edit record push button.
  self~newPushButton(IDC_PB_EDITRECORD)~Enabled = .false  -- ooDialog: ~disable

  -- Save a reference to the push buttons.
  pbBackward = self~newPushButton(IDC_PB_BACKWARD)
  pbForward = self~newPushButton(IDC_PB_Forward)

  -- We start on the first page, so going backwards is not possible.
  pbBackward~Enabled = .false

  -- Add the tabs to the tab control.
  tabControl = self~newTab(IDC_TAB)
  do t over .array~of("List", "Report", "Icon", "Small Icon")   -- ooDialog: tabControl~addSequence(...)
    tabControl~TabPages~Add(t)
  end

  -- Get the display rectangle of the tab control.
  displayRect = self~calculateDisplayArea(tabControl)

  -- The tab control is quite wide in relation to the default space the 4 tabs
  -- occupy. Make the tabs wide enough to take up a little over 1/2 of the width
  -- of the tab control.
  w = (displayRect~right * (7 / 12)) % 4
  call sendWinIntMsg tabControl, 4913, 0, w              -- ooDialog: tabControl~setMinTabWidth(w) (TCM_SETMINTABWIDTH)

  pageDialog = .PageDialog~new(self)                      -- ooDialog: .PageDialog~new(sd"rc\oodListViews.rc", IDD_PAGE, , , , , self)
  pageDialog~useInfoTips = .true
  pageDialog~initialize(smallIcons, normalIcons, records)

  -- Use execute() to properly start a ControlDialog.
  pageDialog~execute
  self~positionAndShow(pageDialog, tabControl, displayRect)


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
 */
::method calculateDisplayArea private
  use strict arg tabControl

  -- Given a rectangle describing the tab control's size and position, the tab
  -- control itself will calculate the display area's size and position.
  -- (.NET version: its DisplayRectangle, in its own coordinates.)
  r = tabControl~DisplayRectangle

  -- Create our display rectangle.  This is used in setWindowPosition(), which
  -- takes a point / size rectangle.  ooDialog defines a point / size rectangle
  -- as using the left and top attributes for the position of the upper left
  -- corner of a rectangle, using the right attribute for the width of the
  -- rectangle, and using the bottom attribute for the height of the rectangle.
  return .NetRect~new(tabControl~Left + r~X, tabControl~Top + r~Y, r~Width, r~Height)


/** positionAndShow()
 *
 * Used to resize and reposition the control dialog (PageDialog so it occupies
 * the display area of the tab control.
 */
::method positionAndShow private
  use strict arg dlg, tabControl, displayRect

  -- We can not position the control dialog until the underlying Windows dialog
  -- is created and we have a valid window handle.  This takes a small but
  -- disecernable amount of time.  The actual amount of time can vary widely and
  -- depends on both the amount of concurrency going on in the interpreter and
  -- the amount of multi-tasking going on in the operating system.
  --
  -- We don't want to spin forever if there is some error in creating the
  -- dialog, so we set a timeout here.  However, it is very short and may not be
  -- long enough.  If it is not long enough, it is better to increase the time
  -- sleeping rather than the loop counter.
  -- (.NET version: the control dialog's panel is there as soon as it executes.)

  -- Now resize and reposition the control dialog to the tab control's display
  -- area.  We need to position the control dialog *above* the tab control in
  -- the Z-order so that it shows.
  dlg~setWindowPos(tabControl~Handle, displayRect, "SHOWWINDOW NOOWNERZORDER")


/** onCheckClicked()
 *
 * This is the event handler for the CLICKED event of the Use Info Tips check
 * box.  Each time it is clicked, we update the Page dialog with its state.
 */
::method onCheckClicked unguarded
  expose ckInfoTips pageDialog

  if ckInfoTips~Checked then pageDialog~useInfoTips = .true
  else pageDialog~useInfoTips = .false


/** onNewTab()
 *
 * This is the method we connected to the SELCHANGE event of the tab control.
 *
 * It is invoked when the user changes to a new tab using the tab control's
 * interface.  I.e. by clicking on a tab or by using the keyboard when the
 * tab control has the focus.
 *
 * In general, there is usually a different control dialog for each page of
 * the tab.  In that usage, the programmer would hide the dialog of the old
 * page and show the dialog of the new page.  However, in this application we
 * only use one control dialog.  When the page is changed, we tell the page
 * dialog to change the view style of the list view to produce the effect of
 * changing pages.
 */
::method onNewTab unguarded
  expose tabControl pageDialog
  use arg ignore1, ignore2

  pageDialog~refreshView(tabControl~SelectedIndex + 1)
  self~checkButtons


/** onForward()
 *
 * The event handle for the 'Forward' button's CLICKED event.  We select the
 * next tab in the tab control and then force the page to update by calling the
 * 'onNewTab' method ourselfs.
 *
 * Note that we do not need to check that the selected index plus 1 is valid
 * because the Forward button is disabled when we are on the last page.
 */
::method onForward
  expose tabControl

  tabControl~SelectedIndex = tabControl~SelectedIndex + 1   -- ooDialog: tabControl~selectIndex(...) (.NET: SELCHANGE too)
  self~onNewTab


/** onBackward()
 *
 * The event handle for the 'Backward' button's CLICKED event.  Coments are the
 * same as for the onForward() method above.
 */
::method onBackward
  expose tabControl

  tabControl~SelectedIndex = tabControl~SelectedIndex - 1
  self~onNewTab


/** onAdd()
 *
 * The event handle for the 'Add' button's CLICKED event.  Here we display the
 * address dialog which allows the user add a new record, which in turn will
 * show up as a new item in the list-view.
 */
::method onAdd unguarded
  expose pageDialog sd

  dlg = .AddressDialog~new                                -- ooDialog: .AddressDialog~new(sd'rc\oodListViews.rc', IDD_ADDRESS)

  if dlg~initCode = 0 then do
    if dlg~execute("SHOWTOP") == self~IDOK then do

      rec = .directory~new
      rec~FirstName  = dlg~IDC_EDIT_FNAME
      rec~Lastname   = dlg~IDC_EDIT_LNAME
      rec~Street     = dlg~IDC_EDIT_STREET
      rec~City       = dlg~IDC_EDIT_CITY
      rec~State      = dlg~IDC_EDIT_STATE
      rec~ZipCode    = dlg~IDC_EDIT_ZIPCODE
      rec~Age        = dlg~IDC_EDIT_AGE
      rec~isEditable = dlg~IDC_CHK_EDITABLE

      if dlg~IDC_RB_MALE = 1 then rec~Sex = "M"
      else rec~Sex = "F"

      -- Have the page dialog add the record to the list-view.
      pageDialog~addRecord(rec)
    end
  end


/** onEdit()
 *
 * The event handle for the 'Edit' button's CLICKED event.  Here we display the
 * address dialog, but set its mode to edit, which allows the user to edit an
 * existing record.
 *
 * The address dialog is set in edit mode by passing a record into init().  If
 * the address dialog is ended with okay, then we update the record with the
 * values the user entered and have the page dialog update the list-view item.
 */
::method onEdit unguarded
  expose pageDialog sd

  rec = pageDialog~getSelectedRecord

  dlg = .AddressDialog~new(rec)                           -- ooDialog: .AddressDialog~new(sd'rc\oodListViews.rc', IDD_ADDRESS, rec)

  if dlg~initCode = 0 then do
    if dlg~execute("SHOWTOP") == self~IDOK then do

      rec~FirstName  = dlg~IDC_EDIT_FNAME
      rec~Lastname   = dlg~IDC_EDIT_LNAME
      rec~Street     = dlg~IDC_EDIT_STREET
      rec~City       = dlg~IDC_EDIT_CITY
      rec~State      = dlg~IDC_EDIT_STATE
      rec~ZipCode    = dlg~IDC_EDIT_ZIPCODE
      rec~Age        = dlg~IDC_EDIT_AGE
      rec~isEditable = dlg~IDC_CHK_EDITABLE

      if dlg~IDC_RB_MALE = 1 then rec~Sex = "M"
      else rec~Sex = "F"

      -- Have the page dialog refresh, update, the item.
      pageDialog~refreshSelectedItem
    end
  end


/** cancel()
 *
 * The user can not end a ControlDialog, so we need to end the page dialog
 * here during cancel.  Passing .false to endExecution() says the user
 * canceled the main dialog.
 */
::method cancel
  expose pageDialog

  -- Always use endExecution() to close a ControlDialog.
  pageDialog~endExecution(.false)
  return self~cancel:super


/** ok()
 *
 * The user can not end a ControlDialog, so we need to end the page dialog
 * here during ok.  Passing .true to endExecution() says the user closed the
 * main dialog with ok.
 */
::method ok
  expose pageDialog

  -- Always use endExecution() to close a ControlDialog.
  pageDialog~endExecution(.true)
  return self~ok:super


/** initAutoDetection()
 *
 * We turn off auto detection for this dialog.
 */
::method initAutoDetection                                -- (.NET version: data attributes are made only when asked for)
  return 0

/** checkButtons()
 *
 * Enables or disables the forwards / backwards buttons to fit the current
 * page.  I.e., if we are on the first page, the backwards button should be
 * disabled, etc..
 */
::method checkButtons private
  expose tabControl pbForward pbBackward

  index = tabControl~SelectedIndex + 1

  if index == 1 then do
    pbBackward~Enabled = .false
    pbForward~Enabled = .true
  end
  else if index == 4 then do
    pbBackward~Enabled = .true
    pbForward~Enabled = .false
  end
  else do
    pbBackward~Enabled = .true
    pbForward~Enabled = .true
  end


::method autoRun unguarded                                -- (.NET version) unattended: the four views, a record added and edited, labels, a column
  expose tabControl pageDialog
  lv = pageDialog~newListView(IDC_LISTVIEW)
  say "(auto)" lv~Items~Count "records:" rows(lv)"; images" lv~SmallImageList~Images~Count lv~LargeImageList~Images~Count
  do 3
    self~onForward
    say "(auto)" tabControl~SelectedTab~Text": the list view's" lv~View~string "- Backward" self~newPushButton(IDC_PB_BACKWARD)~Enabled "Forward" self~newPushButton(IDC_PB_FORWARD)~Enabled
  end
  self~onBackward; self~onBackward
  say "(auto) info tip:" lv~Items[1]~ToolTipText~changeStr(.endOfLine, " / ") "- shown" lv~ShowItemToolTips
  self~newCheckBox(IDC_CK_INFOTIPS)~Checked = .false; self~onCheckClicked   -- a CheckBox has no PerformClick
  say "(auto) Use Info Tips unchecked: shown" lv~ShowItemToolTips
  self~onAdd
  say "(auto) added:" rows(lv)
  lv~Items[3]~Selected = .true
  say "(auto) the new one selected: Edit Record" self~newPushButton(IDC_PB_EDITRECORD)~Enabled
  self~onEdit
  say "(auto) edited:" lv~Items[3]~SubItems[5]~Text "years, info tip" lv~Items[3]~ToolTipText~changeStr(.endOfLine, " / ")
  F = .net~System~Windows~Forms
  e = F~LabelEditEventArgs~new(0)
  pageDialog~onBeginEdit(lv, e)
  say "(auto) label edit of Miller (not editable): refused" e~CancelEdit
  e = F~LabelEditEventArgs~new(1, "Thaxton-Smith, Susan")
  pageDialog~onEndEdit(lv, e)
  say "(auto) Thaxton renamed: kept" (\e~CancelEdit) "- the record:" lv~Items[1]~Tag~firstName lv~Items[1]~Tag~lastName
  e = F~LabelEditEventArgs~new(2, "Dave Hewitt")
  pageDialog~onEndEdit(lv, e)
  say "(auto) a label without a comma: refused" e~CancelEdit
  w = lv~Columns[1]~Width
  pageDialog~onColumnClick(lv, F~ColumnClickEventArgs~new(1))
  say "(auto) column 2 clicked: width" w "->" lv~Columns[1]~Width
  self~ok

/** createImageLists()
 *
 * Create the small and large icon image lists.  These will be used in the
 * report, small icon, and icon views of the list-view.  The small icon image
 * list is used by both the report and the small icon views, normal icon image
 * list is used by the icon view.
 *
 * In this program we create the initial records and image lists here, in the
 * main dialog, and then pass the objects to the page dialog.  The creation
 * could just as well have been done in the page dialog itself.  The example
 * program does it this way to try and show that how you use a ControlDialog is
 * very flexible.
 */
::method createImageLists private
  expose smallIcons normalIcons sd

  -- (.NET version: ImageLists, the bitmaps' strips.)
  smallIcons = imageList(sd"resources\oodListViews1.bmp", 16, 12)   -- ooDialog: .ImageList~create(.Size~new(16, 12), COLOR4, 4, 0)
  normalIcons = imageList(sd"resources\oodListViews2.bmp", 32, 32)


/** initRecords()
 *
 * Create 3 records to start with.  The records could be pulled from a database.
 * Here we just fake it.  Each 'record' is put into an array and then the array
 * is passed to the page dialog where is record is used to insert a single item
 * into the list-view.
 */
::method initRecords private
  expose records

  records = .array~new(3)

  rec = .directory~new
  rec~FirstName  = "Mike"
  rec~Lastname   = "Miller"
  rec~Street     = "432 Fifth Ave"
  rec~City       = "New York"
  rec~State      = "NY"
  rec~ZipCode    = "12897"
  rec~Age        = "35"
  rec~Sex        = "M"
  rec~IsEditable = .false
  records[1] = rec

  rec = .directory~new
  rec~FirstName  = "Sue"
  rec~Lastname   = "Thaxton"
  rec~Street     = "5179 Bellevue St"
  rec~City       = "Tucson"
  rec~State      = "AZ"
  rec~ZipCode    = "87340"
  rec~Age        = "30"
  rec~Sex        = "F"
  rec~IsEditable = .true
  records[2] = rec

  rec = .directory~new
  rec~FirstName  = "Dave"
  rec~Lastname   = "Hewitt"
  rec~Street     = "4932 Texas St"
  rec~City       = "San Diego"
  rec~State      = "CA"
  rec~ZipCode    = "92110"
  rec~Age        = "49"
  rec~Sex        = "M"
  rec~IsEditable = .true
  records[3] = rec



/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     PageDialog Class
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'PageDialog' subclass OodListViews_IDD_PAGE inherit ControlDialog   -- ooDialog: subclass RcControlDialog

-- This attribute allows the parent dialog to notify us if the Use Info Tips
-- check box is checked or not.  When it is not checked, we don't display any
-- info tips.
-- (.NET version: the list view shows its items' tips, or not.)
::method useInfoTips
  expose useInfoTips
  return useInfoTips
::method "USEINFOTIPS="
  expose useInfoTips lv
  use strict arg useInfoTips
  if var("LV") then lv~ShowItemToolTips = useInfoTips

::method initialize
  expose smallIcons normalIcons records haveSelection pbEdit
  use strict arg smallIcons, normalIcons, records

  self~connectListViewEvent(IDC_LISTVIEW, "COLUMNCLICK")
  self~connectListViewEvent(IDC_LISTVIEW, "ACTIVATE", "onActivate", .true)
  self~connectListViewEvent(IDC_LISTVIEW, "DBLCLK", "onDoubleClick", .true)
  self~connectListViewEvent(IDC_LISTVIEW, "BEGINDRAG", "DefListDragHandler")
  self~connectListViewEvent(IDC_LISTVIEW, "BEGINEDIT", "onBeginEdit", .true)
  self~connectListViewEvent(IDC_LISTVIEW, "ENDEDIT", , .true)
  -- (.NET version) ooDialog: self~connectListViewEvent(IDC_LISTVIEW, "GETINFOTIP"): the items' ToolTipText
  self~connectListViewEvent(IDC_LISTVIEW, "SELECTCHANGED")

  -- (.NET version) ooDialog: self~initUpdateListView(IDC_LISTVIEW): nothing to do

  haveSelection = .false
  pbEdit = self~ownerDialog~newPushButton(IDC_PB_EDITRECORD)

::method initDialog
  expose lv smallIcons normalIcons records ckInfoTips useInfoTips

  lv = self~newListView(IDC_LISTVIEW)

  if smallIcons <> .nil then lv~SmallImageList = smallIcons   -- ooDialog: lv~setImageList(smallIcons, SMALL)
  if normalIcons <> .nil then lv~LargeImageList = normalIcons -- ooDialog: lv~setImageList(normalIcons, NORMAL)

  lv~Columns~Add("Name", self~px(50))                    -- ooDialog: lv~insertColumn(0, "Name", 50) (dialog units)
  lv~Columns~Add("Street", self~px(60))
  lv~Columns~Add("City", self~px(50))
  lv~Columns~Add("State", self~px(20))
  lv~Columns~Add("Zip Code", self~px(30))
  lv~Columns~Add("Age", self~px(20))

  do r over records
    self~addRecord(r, .false)
  end

  lv~FullRowSelect = .true                               -- ooDialog: lv~addExtendedStyle("FULLROWSELECT DOUBLEBUFFER GRIDLINES INFOTIP")
  lv~GridLines = .true
  lv~ShowItemToolTips = (useInfoTips == .true)


/** refreshView()
 *
 * Invoked by the main dialog when the user has switched to a new tab in the tab
 * control.
 *
 * Typically an application uses a different dialog for each page of a tab
 * control.  In this example program however, the different pages just show the
 * different view types of a list-view. Therefore the same dialog, (and the same
 * list-view,) are used for each page.  When a new page is to be displayed,
 * rather than switching to a different dialog, the current view of the list-
 * view is simply changed to the correct view for that page.
 */
::method refreshView unguarded
  expose lv
  use strict arg index

  select
    when index == 1 then lv~View = "List"                -- ooDialog: lv~setView("LIST")
    when index == 2 then lv~View = "Details"             -- ooDialog: lv~setView("REPORT")
    when index == 3 then lv~View = "LargeIcon"           -- ooDialog: lv~setView("ICON")
    when index == 4 then lv~View = "SmallIcon"           -- ooDialog: lv~setView("SMALLICON")
    otherwise return .false
  end
  -- End select

  return .true


/** onBeginEdit()
 *
 * The event handler for the label begin edit event, invoked when the user
 * initiates a label editing operation.
 *
 * When the label editing is initiated, the operating system creates and
 * postitions a edit control, but doesn't show it.  The system then sends the
 * label begin edit notification.  Here we have access to the edit control,
 * which could be customized by using the typical methods of the edit object.
 *
 * In addition, the edit operation can be vetoed by returning false.  I.e.,
 * return true to allow the editing, and false to disallow it.  To demonstrate
 * this, we check if the record is editable and if it is not we disallow the
 * label editing operation by returning false from this event handler.
 *
 * (.NET version: .NET's (sender, e): e~Item, the item's index; e~CancelEdit
 * = .true disallows it.)
 */
::method onBeginEdit unguarded
  use arg listViewCtrl, e

  rec = listViewCtrl~Items[e~Item]~Tag                    -- ooDialog: listViewCtrl~getItemData(itemIndex)
  if rec~isEditable then return

  e~CancelEdit = .true                                    -- ooDialog: reply .false

  msg = "The record for" rec~FirstName rec~LastName 'can not be changed.'
  title = "Label Edit Error"
  j = MessageDialog(msg, self~hwnd, title, , "WARNING")

  return


/** onEndEdit()
 *
 * This is the event handler for the end label edit notification.  It is invoked
 * when the user ends the label editing operation.  If the user canceled the
 * operation, then the 'text' argument will be the .nil object.  Otherwise it
 * will be the text the user entered.
 *
 * We use this event to validate the label to a degree and to update the record
 * for the item when the user edits the label.
 *
 * (.NET version: e~Label is the text, .nil if canceled; e~CancelEdit = .true
 * rejects it.)
 */
::method onEndEdit unguarded
  use arg listViewCtrl, e

  text = e~Label
  if text == .nil then return

  if text~words == 2 & text~word(1)~right(1) == ',' then do
    rec = listViewCtrl~Items[e~Item]~Tag
    rec~FirstName = text~word(2)
    rec~LastName  = text~word(1)~strip('T', ',')
    self~setTip(listViewCtrl~Items[e~Item])               -- (.NET version: its info tip anew)

    return
  end

  e~CancelEdit = .true                                    -- ooDialog: reply .false

  msg = "The format for a record label must be" || .endOfLine || -
        "last name, comma, first name.  For"    || .endOfLine || -
        "example: Swift, Tom"                   || .endOfLine~copies(2) || -
        "The change is rejected."

  title = "Label Editing Error"
  j = MessageDialog(msg, self~hwnd, title, , "WARNING")

  return


/** onColumnClick()
 *
 * The event handler for a column click event, invoked when the user clicks on a
 * column header when the list-view is in Report view.
 *
 * We use the event to demonstrate some of the list-view methods.
 */
::method onColumnClick unguarded
  use arg listView, e
  column = e~Column

  -- Get the current width, in pixels, of the column clicked and then set its
  -- width to 10 pixels more.
  listView~Columns[column]~Width = listView~Columns[column]~Width + 10   -- ooDialog: setColumnWidthPx, columnWidthPx

  -- Display information about the column clicked.
  c = listView~Columns[column]                            -- ooDialog: listView~getColumnInfo(column, d)
  tab = '09'x
  msg = "Column Title:"tab c~Text                   || .endOfLine            ||  -
        "Subitem index:"tab column                  || .endOfLine            ||  -
        "Column Width:"tab c~Width                  || .endOfLine            ||  -
        "Allignment:"tab c~TextAlign~string~upper   || .endOfLine~copies(2)  ||  -
        "Note: each time you click on a column"     || .endOfLine            ||  -
        "its width is increased."
  j = MessageDialog(msg, self~hwnd, "Column Click Detected")


/** onDoubleClick()
 *
 * The event handler for a double clikc event, invoked when a list-view item is
 * double clicked.
 *
 * We use the event to demonstrate:
 *
 * 1.)  That a double click also activates an item and that the double click
 *      comes first.  When you double click an item you will see a message box
 *      displaying the arguments to this method, the 'age increase' message box,
 *      and then a message box from the onActivate() method.
 *
 * 2.)  Some of the list-view methods.
 *
 * (.NET version: .NET's (sender, e); the item and subitem double clicked are
 * found where the pointer is.)
 */
::method onDoubleClick unguarded
  use arg listView, e

  hit = listView~HitTest(listView~PointToClient(.net~System~Windows~Forms~Control~MousePosition))
  id = listView~Name
  if hit~Item == .nil then do; item = -1; subitem = 0; state = ""; end
  else do
    item = hit~Item~Index
    subitem = 0
    if hit~SubItem \== .nil then subitem = hit~Item~SubItems~IndexOf(hit~SubItem)
    state = (hit~Item~Selected~?("SELECTED", "") hit~Item~Focused~?("FOCUSED", ""))~space
  end
  isSingleClick = .false

  tab  = '09'x
  tab2 = tab~copies(2)
  true = self~booleanToText(isSingleClick)
  msg = 'onDoubleClick()'       || .endOfLine~copies(2) || -
        'id:'tab2 id            || .endOfLine || -
        'item:'tab2 item        || .endOfLine || -
        'subitem:'tab2 subitem  || .endOfLine || -
        'state:'tab2 state      || .endOfLine || -
        'single click:'tab true || .endOfLine || -
        'listView:'tab2 listView

  ret = MessageDialog(msg, self~hwnd, "onDoubleClick Method Invoked", OK, INFORMATION)

  -- Get the index of the item with the focus, use the index to retrieve the
  -- item information and the text associated with it
  if listView~FocusedItem == .nil then return 0          -- (.NET version: none)
  index = listView~FocusedItem~Index                      -- ooDialog: listView~focused

  -- The item's information is returned in the .directory object passed in to
  -- the getItemInfo() method.
  -- (.NET version: the item's own Text and ImageIndex.)
  it = listView~Items[index]

  parse value it~Text with lastName ', ' firstName

  pronoun = 'his'
  if it~ImageIndex == 1 then pronoun = "her"

  age = it~SubItems[5]~Text                               -- ooDialog: listView~itemText(index, 5)

  msg = "You have double clicked on the item for" firstName lastName || "0d0a0d0a"x ,
        "Should" pronoun "age be increased by 1?"

  ret = MessageDialog(msg, self~hwnd, "Age Increment", YESNO, INFORMATION)
  if ret == self~IDYES then do
    age += 1
    it~SubItems[5]~Text = age                             -- ooDialog: listView~setItemText(index, 5, age)

    -- Now we need to update the age in the record for this item. We retrieve
    -- the record from the user item data and update the age.
    rec = it~Tag                                          -- ooDialog: listView~getItemData(index)
    rec~age = age
  end

  -- Deselect the focused item and move the focus to the first item
  it~Selected = .false                                    -- ooDialog: listView~deselect(index)
  listView~Items[0]~Focused = .true                       -- ooDialog: listView~focus(0)
  return 0


/** onActivate()
 *
 * The event handler for an activate event, invoked when a list-view item is
 * activated.
 *
 * We use the event to demonstrate that a double click event also generates an
 * activate event.  We just print out the argument values here.
 *
 * (.NET version: .NET's ItemActivate, (sender, e).)
 */
::method onActivate unguarded
  use arg listView, e

  tab = '09'x
  msg = 'onActivate()'               || .endOfLine~copies(2) || -
        'id:'tab listView~Name       || .endOfLine || -
        'event:'tab e~class~id       || .endOfLine || -
        'listView:'tab listView

  ret = MessageDialog(msg, self~hwnd, "onActivate Method Invoked", OK, INFORMATION)

  return 0


/** onGetInfoTip()
 *
 * This is the event handler for the INFOTIP event.  This method is invoked when
 * the list-view wants the text for an info tip.
 *
 * If this method returns the empty string then no info tip will be shown.
 * Otherwise, the info tip will contain the text sent back.
 *
 * The maxLen argument will be the maximum length allowed for the returned text.
 * You should never assume what this length is, although it appears to usually
 * be 1023.  If the text sent back is longer than maxLen, it will automatically
 * be truncated.
 *
 * Note that the original versions of this example did not use the user item
 * data feature of the list-view.  Instead they trackd the records through an
 * array.  When this example was updated to work with the user item data
 * feature, this method was left as is, to show more than one way of associating
 * a record with a list-view item.
 *
 * (.NET version: called when an item is added or changed, by setTip; whether
 * the tips show is the list view's ShowItemToolTips.)
 */
::method onGetInfoTip unguarded
  expose lv records useInfoTips
  use arg id, item, text, maxLen

  text = ''

  r = records[item + 1]
  text = r~firstName r~lastName '('r~age')' || .endOfLine || -
         r~street                           || .endOfLine || -
         r~city',' r~state r~zipcode

  return text

-- (.NET version) an item's info tip, as onGetInfoTip makes it
::method setTip private
  expose lv
  use strict arg it
  it~ToolTipText = self~onGetInfoTip(lv~Name, it~Index, "", 1023)


/** onSelectionChanged()
 *
 * This is the event handler for the selection changed event.  It is invoked
 * each time the selection state of an item changes.  We use this event to
 * enable or disable the Edit Record push button.  The button is only enabled
 * when an item is selected, and that item is an editable record.  When no item
 * is selected, or if the selected item is not editable, then the push button is
 * disabled.
 *
 * The event happens each time a selected item is deselected and each time an
 * unselected item is selected.  This means that quite often when an item is
 * selected there are two events, the old selected item losing its selection and
 * the newly selected item gaining the selection.
 *
 * (.NET version: .NET's (sender, e): e~ItemIndex, e~IsSelected.)
 */
::method onSelectChanged unguarded
  expose haveSelection pbEdit
  use arg lv, e
  itemIndex = e~ItemIndex
  state = e~IsSelected~?('SELECTED', 'UNSELECTED')

  if state == 'SELECTED' then haveSelection = .true
  else if state == 'UNSELECTED' & lv~SelectedIndices~Count == 0 then haveSelection = .false   -- ooDialog: lv~selected == -1

  if \ haveSelection then do
    pbEdit~Enabled = .false                               -- ooDialog: pbEdit~disable
  end
  else if state == 'SELECTED' then do
    -- We have a selection and an item was just selected, see if it is editable:
    rec = lv~Items[itemIndex]~Tag                         -- ooDialog: lv~getItemData(itemIndex)
    if rec~isEditable then pbEdit~Enabled = .true
    else pbEdit~Enabled = .false
  end


::method booleanToText unguarded private
  use strict arg boolean
  if boolean == .true then return 'true'
  else if boolean == .false then return 'false'
  else return 'not a boolean'


/** addRecord()
 *
 * Used to add an item to the list view.
 *
 * Note that it does not matter what view the list-view is in.  When the list-
 * view is in report view, then all the information will be visible to the user.
 * When it is in other views, only some of the information is visible to the
 * user.
 */
::method addRecord unguarded
  expose lv records counter
  use strict arg rec, newRecord = .true

  iconSex = 0
  if rec~sex = "F" then iconSex = 1

  it = .net~System~Windows~Forms~ListViewItem~new(.array~of(rec~lastName', 'rec~firstName, rec~street, rec~city, rec~state, rec~ZipCode, rec~age))
  it~ImageIndex = iconSex                                 -- ooDialog: index = lv~addRow(, iconSex, ...)
  it~Tag = rec                                            -- ooDialog: lv~setItemData(index, rec)
  lv~Items~Add(it)

  if newRecord then records~append(rec)
  self~setTip(it)


/** getSelectedRecord()
 *
 * The owner dialog, the top-level dialog, invokes this method to get access to
 * the data record of the currently selected item.
 *
 * Because the program only enables the 'Edit Record' button when an item that
 * is editable is selected, we do not need to do a lot of checks here.  We
 * simply get the selected index, get the user item data for that index, and
 * send the record back.
 */
::method getSelectedRecord
  expose lv
  return lv~SelectedItems[0]~Tag                          -- ooDialog: lv~getItemData(lv~selected)


/** refreshSelectedRecord()
 *
 * This method is invoked by the owner dialog to notify us that the data in a
 * record has been changed.  We simply get the record for the selected item and
 * modify the item with the record data.
 *
 * Because of the way the program is structured, there must be a selected item.
 * We check anyway that the selected index is value
 */
::method refreshSelectedItem
  expose lv pbEdit

  if lv~SelectedItems~Count == 0 then return .false       -- ooDialog: index = lv~selected; if index == -1 ...
  it = lv~SelectedItems[0]

  rec = it~Tag

  iconSex = 0
  if rec~sex = "F" then iconSex = 1

  it~Text = rec~lastName', 'rec~firstName                 -- ooDialog: lv~modify(index, 0, ..., iconSex)
  it~ImageIndex = iconSex
  it~SubItems[1]~Text = rec~street                        -- ooDialog: lv~modify(index, 1, rec~street)...
  it~SubItems[2]~Text = rec~city
  it~SubItems[3]~Text = rec~state
  it~SubItems[4]~Text = rec~zipCode
  it~SubItems[5]~Text = rec~age
  self~setTip(it)

  -- The is editable status of the record could have changed.
  if rec~isEditable then pbEdit~Enabled = .true
  else pbEdit~Enabled = .false

  return .true


/** leaving()
 *
 * The ooDialog framework invokes the leaving method automatically when a dialog
 * is being ended.  The default implementation does nothing.  The method is
 * intended to be over-ridden by the programmer, if desired, to provide the
 * proper place to clean up resources.
 *
 * We use it here to release the image lists resources.  This is not needed in
 * this stand alone program.  When the interpreter process ends, (which will
 * happen now that the dialog is ending,) the operating system will free all the
 * resources.  The example program does this because ... because it is an
 * example and this makes a good place to explain about the leaving() method.
 */
::method leaving
  expose smallIcons normalIcons
  if smallIcons \== .nil then smallIcons~Dispose          -- ooDialog: smallIcons~release
  if normalIcons \== .nil then normalIcons~Dispose


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     AddressDialog Class
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'AddressDialog' subclass OodListViews_IDD_ADDRESS

::method init
  expose rec
  self~init:super                                         -- ooDialog: self~init:super(arg(1), arg(2))

  if self~initCode <> 0 then return self~initCode

  if arg(1, 'E') then rec = arg(1)                        -- ooDialog: arg(3)
  else rec = .nil

  -- Initialize the data attributes. These attributes are added automatically
  -- to this dialog by the ooDialog framework.  The attributes are used to
  -- reflect the state of the underlying dialog controls.
  --
  -- If we have a record, we are in edit mode, otherwise we are in add mode.
  if rec == .nil then do
    self~IDC_RB_MALE = 1
    self~IDC_RB_FEMALE = 0
    self~IDC_EDIT_FNAME = ''
    self~IDC_EDIT_LNAME = ''
    self~IDC_EDIT_STREET = ''
    self~IDC_EDIT_CITY = ''
    self~IDC_EDIT_STATE = ''
    self~IDC_EDIT_ZIPCODE = ''
    self~IDC_EDIT_AGE = ''
    self~IDC_CHK_EDITABLE = 1
  end
  else do
    if rec~Sex == 'M' then do
      self~IDC_RB_MALE   = 1
      self~IDC_RB_FEMALE = 0
    end
    else do
      self~IDC_RB_MALE   = 0
      self~IDC_RB_FEMALE = 1
    end
    self~IDC_EDIT_FNAME   = rec~FirstName
    self~IDC_EDIT_LNAME   = rec~Lastname
    self~IDC_EDIT_STREET  = rec~Street
    self~IDC_EDIT_CITY    = rec~City
    self~IDC_EDIT_STATE   = rec~State
    self~IDC_EDIT_ZIPCODE = rec~ZipCode
    self~IDC_EDIT_AGE     = rec~Age
    self~IDC_CHK_EDITABLE = rec~isEditable
  end

  return self~initCode


::method initDialog

  -- To help with data validation, restrict the number of characters the user
  -- can type into these edit controls.  Note that in the resource script, the
  -- zip code and age edit controls are defined as numeric only.  The state edit
  -- control is defined as upper-case only.
  self~newEdit(IDC_EDIT_STATE)~MaxLength = 2              -- ooDialog: ~setLimit(2)
  self~newEdit(IDC_EDIT_ZIPCODE)~MaxLength = 5
  self~newEdit(IDC_EDIT_AGE)~MaxLength = 3


/** validate()
 *
 * The validate() method is invoked automatically by the ooDialog framework when
 * the user closes a dialog with 'ok'.  The default implementation simply
 * returns true.  The method is meant to be over-ridden by the programmer, if
 * desired, to validate the user input is correct.  The method must return .true
 * or .false.  When .true is returned, the dialog continues to close.  If .false
 * is returned, the dialog will not be closed.
 *
 * Here we do a bare minimum of validation.  We just check that something has
 * been entered for the first and last names.
 */
::method validate

  if self~namesEnteredOkay then return .true

  -- It's not very user friendly to prevent the user from closing the dialog
  -- without letting him know why.
  msg = "The last and first names must be specified for each new record."
  title = "New Record Input Error"
  j = MessageDialog(msg, self~hwnd, title, , "WARNING")

  -- Place the focus on the first edit control that has invalid data:
  if self~newEdit(IDC_EDIT_FNAME)~Text~strip == "" then
    self~newEdit(IDC_EDIT_FNAME)~Focus                    -- ooDialog: self~focusControl(IDC_EDIT_FNAME)
  else
    self~newEdit(IDC_EDIT_LNAME)~Focus

  return .false


/* Simple convenience function to make validate() more readable */
::method namesEnteredOkay private
  if self~newEdit(IDC_EDIT_LNAME)~Text~strip == "" then return .false
  if self~newEdit(IDC_EDIT_FNAME)~Text~strip == "" then return .false
  return .true

::method autoRun unguarded                               -- (.NET version) unattended: OK with no names (refused), then a new record; or ten years older
  expose rec
  if rec == .nil then do
    self~ok
    say "(auto) OK with no names: still open" (\self~form~IsDisposed)
    self~IDC_EDIT_FNAME = "Tom"; self~IDC_EDIT_LNAME = "Swift"
    self~IDC_EDIT_STREET = "1 Main St"; self~IDC_EDIT_CITY = "Austin"
    self~newEdit(IDC_EDIT_STATE)~Text = "tx"
    say "(auto) the state typed tx:" self~IDC_EDIT_STATE
    self~IDC_EDIT_ZIPCODE = "73301"; self~IDC_EDIT_AGE = "41"
    self~IDC_RB_FEMALE = 0
  end
  else self~IDC_EDIT_AGE = self~IDC_EDIT_AGE + 10
  self~ok

/* (.NET version) an ImageList of w x h images, a bitmap's strip */
::routine imageList
  use strict arg file, w, h
  il = .net~System~Windows~Forms~ImageList~new
  il~ImageSize = .net~System~Drawing~Size~new(w, h)
  il~ColorDepth = "Depth4Bit"
  il~Images~AddStrip(.net~System~Drawing~Image~FromFile(file))
  return il

/* (.NET version) the list view's labels */
::routine rows
  use strict arg lv
  s = ""
  do i = 0 to lv~Items~Count - 1
    s = s || "; " || lv~Items[i]~Text
  end
  return s~substr(3)
