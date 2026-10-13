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
/* ooDialog User Guide
   Exercise 07: The OrderFormView class				  v02-00 01Apr13
   OrderFormView.rex

   Contains: class "OrderFormView", class "HRSofv".
   Pre-requisite files: OrderFormView.rc, OrderFormView.h.

   Changes:
     v01-00 07Jun12: First version.
     v02-00 08Jan13: OrderFormView Modified to use the Model-View Framework (MVF).
                     Removed stand-alone startup (not now needed).
            25Feb13: Added control dialogs in tab sheet.
            27Feb13: Made Order Date functional.
            01Apr13: After ooDialog 4.2.2, Support folder moved to exercise
                     folder, so change to ::Requires needed.


   (.NET version, on Windows Forms through oodnet.cls: OrderFormView.rc's
   three dialogs and its menu are the classes of OrderFormViewrc.cls,
   written by rc2oodnet.rex -cls; OrderFormView subclasses the main one and
   inherits RcView (Support\RcView.rex: a mixin here); its two tab pages
   subclass the others and inherit oodnet.cls's ControlDialog (ooDialog's
   RcControlDialog), each a panel of this dialog put over the tab control's
   display area, as ooDialog's TabDemo.rex does. The tab control, the date
   picker and the list view are .NET's.)
------------------------------------------------------------------------------*/


-- ooDialog: .Application~addToConstDir("Order\OrderFormView.h"): here the ids are names


::REQUIRES "OrderFormViewrc.cls"           -- ooDialog: ::REQUIRES "ooDialog.cls"
::REQUIRES "support\RcView.rex"

/*==============================================================================
  OrderFormView							  v02-00 27Feb13
  -------------
  The "view" (or "gui") Data Entry part of the Sales Order component.

  Changes:
  v01-00 07Jun12: First Version
  v02-00 05Oct12: Modified to use the Model-View Framework (MVF) including
                  removal of stand-alone startup.
         27Feb13: Changed to show tabs (control dialogs).
                  Corrected the Order Date control and limited order date to
                    one year ahead.
                  Commented-out say's.

  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS OrderFormView SUBCLASS OrderFormView_IDD_ORDFORM_DIALOG PUBLIC INHERIT RcView   -- ooDialog: SUBCLASS RcView

  ::ATTRIBUTE tabContent

  ::METHOD newInstance CLASS PUBLIC
    use strict arg idModel, rootDlg
    --say; say ".OrderFormView-newInstance: rootDlg =" rootDlg
    dlg = self~new   -- ooDialog: self~new("Order\OrderFormView.rc", "IDD_ORDFORM_DIALOG")
    dlg~activate(idModel, rootDlg)
    return dlg

  /*----------------------------------------------------------------------------
    Dialog Setup Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD init
    -- creates the dialog instance but does not make it visible.
    expose menuBar
    --say "OrderFormView-init-01"

    forward class (super) continue

    if \ self~createMenuBar then do		-- if there was a problem
      self~initCode = 1
      return
    end


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD createMenuBar
    -- Creates the menu bar on the dialog.
    expose menuBar
    --say "OrderFormView-createMenuBar-01"
    menuBar = .OrderFormView_IDR_ORDFORM_MENU~new   -- ooDialog: menuBar = .ScriptMenuBar~new("Order\OrderFormView.rc", IDR_ORDFORM_MENU, , , .true)

    return .true


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD activate unguarded
    expose rootDlg idModelInstance orderData cd1 cd2
    use strict arg idModelInstance, rootDlg
    forward class (super) continue
    orderData = RESULT

    -- set up tabs for Customer Details and Order Lines:
    cd1 = .CustDetailsDlg~new   -- ooDialog: .CustDetailsDlg~new("Order\OrderFormView.rc", IDD_ORDFORM_CUST_DIALOG)
    cd2 = .OrderLinesDlg~new   -- ooDialog: .OrderLinesDlg~new("Order\OrderFormView.rc", IDD_ORDFORM_ORDLINES_DIALOG)
    tabContent = .array~of(cd1, cd2)
    --say "OrderFormView-activate-01: tabContent =" tabContent[1]||"," tabContent[2]
    cd1~ownerDialog = self
    self~prep(tabContent)

    --say "OrderFormView-activate-02: modelData, orderNum =" orderData||"," orderData[formNumber]
    self~popUpAsChild(rootDlg,"SHOWTOP",,"IDI_ORDFORM_DLGICON")
    return


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD prep
    expose tabContent lastSelected havePositioned
    use strict arg tabContent
    --say "OrderFormView-prep-01."
    -- The havePositioned array is used to determine if the page dialogs have been
    -- positioned or not.  Mark all 5 dialogs as not having been positioned yet.
    havePositioned = .array~of(.false, .false)
    -- No tab has been selected yet
    lastSelected = 0

    -- Connect the event handling methods to the events we are interested in.
    --self~connectButtonEvent(IDC_PB_PREVIOUS, CLICKED, onPrevious)
    --self~connectButtonEvent(IDC_PB_NEXT, CLICKED, onNext)
    self~connectTabEvent(IDC_ORDFORM_TABS, SELCHANGE, onNewTab)


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD initDialog
    -- Called by ooDialog after SHOWTOP.
    expose menuBar ecOrderNo orderData tabContent tabControl orderDate
    --say "OrderFormView-initDialog-01"

    menuBar~attachTo(self)

    menuBar~connectAllCommandEvents    -- (.NET version) ooDialog: new's autoConnect, .true

    -- Tab stuff starts:
    cd1 = tabContent[1]
    cd1~execute

    -- Add the tabs to the tab control.
    tabControl = self~newTab(IDC_ORDFORM_TABS)
    do t over .array~of("Customer Details", "Order Lines")   -- ooDialog: tabControl~addSequence("Customer Details", "Order Lines")
      tabControl~TabPages~Add(t)
    end
    -- tab stuff ends

    ecOrderNo         = self~newEdit("IDC_ORDFORM_ORDNO")
    --say "OrderFormView-initDialog-02: ecOrderNo =" ecOrderNo
    btnCancelOrder = self~newPushButton("IDC_CANCEL")
    btnPlaceOrder = self~newPushButton("IDC_ORDFORM_PLACEORDER")
    self~connectButtonEvent("IDC_CANCEL","CLICKED",cancel)
    self~connectButtonEvent("IDC_ORDFORM_PLACEORDER","CLICKED",placeOrderBtn)

    -- Get proxy for Order date and set its format. By default, it shows today.
    --Also, set allowable date range selected to between today and 1 year's time.
    orderDate = self~newDateTimePicker(IDC_ORDFORM_DATE);
    orderDate~Format = "Custom"                               -- ooDialog: orderDate~setFormat("MMM dd',' yyyy")
    orderDate~CustomFormat = "MMM dd',' yyyy"
    today = .DateTime~today
    maxOrderDate = today~addYears(1)
    orderDate~MinDate = .net~System~DateTime~Today            -- ooDialog: orderDate~setRange(.array~of(today,maxOrderDate))
    orderDate~MaxDate = .net~System~DateTime~Today~AddYears(1)

    -- Tab stuff starts:
    -- Determine the position and size of the display area of the tab control.
    self~calculateDisplayArea
    -- Position and show the control dialog used for the first page of the tab.
    self~positionAndShow(1)
    -- tab stuff ends

    self~setMyData(orderData)


 /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD calculateDisplayArea PRIVATE
    expose tabControl displayRect

    -- Given a rectangle describing the tab control's size and position, the tab
    -- control itself will calculate the display area's size and position.
    -- (.NET version: the tab control's DisplayRectangle, in its own
    -- coordinates; ooDialog: tabControl~windowRect, ~calcDisplayRect(r),
    -- .Size~new(...), .Point~new(r~left, r~top), self~screen2client(p))
    r = tabControl~DisplayRectangle

    -- Create our display rectangle.  This is used in setWindowPosition(), which
    -- takes a point / size rectangle.  ooDialog defines a point / size rectangle
    -- as using the left and top attributes for the position of the upper left
    -- corner of a rectangle, using the right attribute for the width of the
    -- rectangle, and using the bottom attribute for the height of the rectangle.
    displayRect = .NetRect~new(tabControl~Left + r~X, tabControl~Top + r~Y, r~Width, r~Height)   -- ooDialog: .Rect~new(p~x, p~y, s~width, s~height)


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    positionAndShow()
    Used to resize and reposition one of the control dialogs so it occupies
    the display area of the tab control.
    -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - */
  ::METHOD positionAndShow private
    expose tabControl tabContent displayRect lastSelected havePositioned
    use strict arg index
    --say "OrderFormView-positionAndShow-01; index =" index
    -- We can not position the control dialog until the underlying Windows dialog
    -- is created. If the system is heavily loaded for some reason, this may not
    -- have happened yet.  We need to wait for it.
    dlg = tabContent[index]
    do i = 1 to 10
      if dlg~hwnd <> 0 then leave
      z = SysSleep(.01)
    end
    --say "OrderFormView-positionAndShow-02."
    if dlg~hwnd == 0 then do
      say "Error creating dialog for the tab with index:" index", aborting"
      return self~cancel
    end

    if lastSelected <> 0 then tabContent[lastSelected]~hide

    -- Now resize and reposition the control dialog to the tab control's display
    -- area.  We need to position the control dialog *above* the tab control in
    -- the Z-order so that it shows.
    dlg~setWindowPos(tabControl~Handle, displayRect, "SHOWWINDOW NOOWNERZORDER")   -- ooDialog: tabControl~hwnd
    --say "OrderFormView-positionAndShow-03."; say

    lastSelected = index
    havePositioned[index] = .true


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    onNewTab - Invoked when user selects another tab.
    -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - */
  ::METHOD onNewTab
    expose tabControl tabContent havePositioned lastSelected
    --say "OrderFormView-onNewTab-01."
    index = tabControl~SelectedIndex + 1
    --say "OrderFormView-onNewTab-02: index =" index
    dlg = tabContent[index]
    --say "OrderFormView-onNewTab-03: dlg, havePositioned[index] =" dlg havePositioned[index]

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
    end


  /*----------------------------------------------------------------------------
    setData - sets (or "populates") controls with data provided in the
              method's argument.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD setMyData
    expose ecOrderNo
    use strict arg orderData
    ecOrderNo~Text = orderData[formNumber]   -- ooDialog: ~setText


  /*----------------------------------------------------------------------------
    Event-Handler Methods - Menu Events
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD placeOrder UNGUARDED
    self~noMenuFunction(.HRSofv~PlaceOrder)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD saveOrder UNGUARDED
    self~noMenuFunction(.HRSofv~SaveOrder)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD CancelOrder UNGUARDED
    self~cancel

  /*- - Help - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD about UNGUARDED
    self~noMenuFunction(.HRSofv~HelpAbout)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD noMenuFunction UNGUARDED
    use arg title
    ret = MessageDialog(.HRSofv~NoMenu, self~hwnd, title, 'WARNING')

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
    -- "Cancel" - This method over-rides the default Windows action of
    -- 'cancel window' for an Escape key.
    -- cancel - 'endExecution' required else dialog hangs when user tried to close.
  ::METHOD cancel
    expose tabContent
    say "OrderFormView-cancel-01."

    response = askDialog(.HRSofv~QExit, "N")
    if response = 1 then do /*forward class (super) */ -- '1' means the 'Yes' button pressed
      do dlg over tabContent
        dlg~endExecution(.false)
      end
      return self~cancel:super
    end



  /*----------------------------------------------------------------------------
    Event-Handler Methods - Button Events
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD placeOrderBtn UNGUARDED
    ret = MessageDialog(.HRSofv~NoBtn, self~hwnd, "Place Order Button", 'WARNING')

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD autoRun UNGUARDED
    -- (.NET version) unattended: the second tab and back, the menu's items and
    -- Place Order, then Cancel Order: it asks, the answer is its default, No;
    -- then the dialog is closed as Yes would.
    expose menuBar tabControl tabContent
    say "(auto) order form" self~newEdit("IDC_ORDFORM_ORDNO")~Text", tabs" tabControl~TabCount
    tabControl~SelectedIndex = 1                              -- (SELCHANGE: onNewTab)
    say "(auto) tab 2 shown:" tabContent[2]~form~Visible", its list's columns" tabContent[2]~newListView("IDC_ORDLINES_LIST")~Columns~Count
    tabControl~SelectedIndex = 0
    say "(auto) tab 1 shown:" tabContent[1]~form~Visible", tab 2" tabContent[2]~form~Visible
    menuBar~item(IDM_ORDFORM_PLACE)~PerformClick
    menuBar~item(IDM_ORDFORM_SAVE)~PerformClick
    menuBar~item(IDM_ORDFORM_ABOUT)~PerformClick
    self~newPushButton("IDC_ORDFORM_PLACEORDER")~PerformClick
    self~newPushButton("IDC_CANCEL")~PerformClick
    say "(auto) still open after No:" self~isDialogActive
    do dlg over tabContent                                    -- (ooDialog: the Yes branch)
      dlg~endExecution(.false)
    end
    self~endDialog(2)


    /*----------------------------------------------------------------------------
    leaving - invoked by ooDialog when a dialog closes.
    *** Find out if it's a bug in RcControlDialog
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD leaving UNGUARDED
    expose cd1 cd2
    say "OrderFormView-leaving-01."
    forward class (super) continue

/*============================================================================*/



/*==============================================================================
  CustDetailsDlg - a Page in the OrderFormView
  -------------

  The "view" (or "gui") Customer Ordering part of the OrderFormView component.
  ----------------------------------------------------------------------------*/
::class CustDetailsDlg subclass OrderFormView_IDD_ORDFORM_CUST_DIALOG inherit ControlDialog   -- ooDialog: subclass RcControlDialog

  ::method initDialog
    expose tabControl
    --say "CustDetailsDlg-initDialog-01."


/*==============================================================================
  OrderLinesDlg - a Page in the OrderFormView
  ----------------

  The "view" (or "gui") Products Ordering part of the OrderFormView.
  ----------------------------------------------------------------------------*/
::class OrderLinesDlg subclass OrderFormView_IDD_ORDFORM_ORDLINES_DIALOG inherit ControlDialog   -- ooDialog: subclass RcControlDialog

  ::method initDialog
    expose tabControl
    lvOrderItems = self~newListView("IDC_ORDLINES_LIST")
    lvOrderItems~GridLines = .true; lvOrderItems~FullRowSelect = .true   -- ooDialog: ~addExtendedStyle("GRIDLINES FULLROWSELECT")
    lvOrderItems~Columns~Add("ProdNo", 60, "Left")   -- ooDialog: ~insertColumnPX
    lvOrderItems~Columns~Add("Product Name", 180, "Left")   -- ooDialog: ~insertColumnPX
    lvOrderItems~Columns~Add("Qty", 40, "Left")   -- ooDialog: ~insertColumnPX
    lvOrderItems~Columns~Add("Amount", 60, "Left")   -- ooDialog: ~insertColumnPX
    --say "OrderLinesDlg-initDialog-01."

    -- Test an edit field:
    ecProdno = self~newEdit("IDC_ORDLINES_PRODNO")


  /*----------------------------------------------------------------------------
    leaving - invoked by ooDialog when a dialog closes.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  --::METHOD leaving UNGUARDED
    --expose objectMgr viewClass viewInstance
    --objectMgr~removeView(viewClass, viewInstance)
    --say "OrderFormView=OrderLinesDlg-leaving-01."
    -- Note - we do not remove the Model. Should we? If so, not from here!

/*============================================================================*/



/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  Human-Readable Strings (HRSofv)				  v01-00 07Jun12
  --------
   The HRSofv class provides constant character strings for user-visible messages.
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS HRSofv PRIVATE	   -- Human-Readable Strings
  ::CONSTANT QExit       "Are you sure you want to cancel this Order and throw away all changes?"
  ::CONSTANT NoMenu      "This menu item is not yet implemented."
  ::CONSTANT NoBtn       "This button is not yet implemented."
  ::CONSTANT PlaceOrder  "Place Order"
  ::CONSTANT SaveOrder   "Save Order"
  ::CONSTANT CancelOrder "Cancel Order"
  ::CONSTANT HelpAbout   "Help - About"

/*============================================================================*/

