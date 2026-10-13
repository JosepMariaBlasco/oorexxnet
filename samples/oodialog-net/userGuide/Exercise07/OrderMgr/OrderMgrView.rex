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
   Exercise 07: OrderMgrView.rex 				  v02-00 27Feb13

   Contains: 	   class: "OrderMgrView", "HRSomv"

   Description: The Order Manager View class - the container for of the
        	Order Management application.

   Pre-requisites: MVF.

   Description: A sample Order Manager View class - part of the sample
        	Order Manager component.

   Outstanding Problems: None reported.

   Changes:
     v01-00 07Jun12: First Version
     v01-01 18Jan13: Version 1.1 - dialog sizing now uses resizingAdmin.
     v02-00 20Feb13:
       1. Added get id of ObjectMgr in init method.
       2. Added menu item "Help - Person" to surface a Person Model in order to
          illustrate MVF using Person class early in Chapter 7.
       3. Added menu item "Help - Message Sender" to surface the Message Sender.
       4. Updated 'showModel' method to use the MVF (via ObjectMgr) to surface
          List Views that are populated with data read from disk (instead of data
          hard-coded in the ListView) also give listview the instance name of "a"
          to indicate an anonymous component to ObjectMgr.
       5. Added methods "person" and "messageSender" which launch a PersonModel
          and a Message Sender respectively.
       27Feb13: Commented-out several 'say's.
       30Jly14: Corrected .ImageList~create(...) statement in createIconList 
                method.


   (.NET version, on Windows Forms through oodnet.cls: OrderMgrView.rc's
   dialog and menu are the classes of OrderMgrViewrc.cls, written by
   rc2oodnet.rex -cls; OrderMgrView subclasses the dialog's in place of
   RcDialog and inherits oodnet.cls's ResizingAdmin. The icons are a .NET
   ImageList of the same bitmaps, the list view's LargeImageList; dragging
   them about is oodnet.cls's DefListDragHandler. The views the ObjectMgr
   shows are popped up as children of this one.)
------------------------------------------------------------------------------*/

-- Use the global .constDir for symbolic IDs - load them from OrderMgrView.h
-- ooDialog: .Application~addToConstDir("OrderMgr\OrderMgrView.h"): here the ids are names

call "OrderMgr\RequiresList.rex"

::REQUIRES "OrderMgrViewrc.cls"            -- ooDialog: ::REQUIRES "ooDialog.cls"

/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  OrderMgrView							  v02-00 20Feb13
  --------------------
  To the user, this class is the Order Management Application. It provides
  access to the various functions required for managing Sales orders.
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS OrderMgrView SUBCLASS OrderMgrView_IDD_ORDMGR PUBLIC INHERIT ResizingAdmin   -- ooDialog: SUBCLASS RcDialog

  ::ATTRIBUTE lv PRIVATE	-- The ListView that contains the icons.

  /*----------------------------------------------------------------------------
    Class Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD newInstance CLASS PUBLIC
    --say ".OrderMgrView-newInstance-01."
    dlg = .OrderMgrView~new   -- ooDialog: .OrderMgrView~new("OrderMgr\OrderMgrView.rc", IDD_ORDMGR)
    dlg~activate


  /*----------------------------------------------------------------------------
    Instance Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    Dialog Setup Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD init
    expose menuBar records idObjectMgr
    --say "OrderMgrView-init-01; next stmt is 'forward class (super) continue'."
    forward class (super) continue
    --say "OrderMgrView-init-02."
    menuBar = .OrderMgrView_IDR_ORDMGR_MENU~new   -- ooDialog: menuBar = .ScriptMenuBar~new("OrderMgr\OrderMgrView.rc", IDR_ORDMGR_MENU, , , .true)
    self~createIconList
    records = self~initRecords
    idObjectMgr = .local~my.ObjectMgr

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD defineDialog
    forward class (super) continue     -- (.NET version) the .rc's controls, made by the superclass's defineDialog
    --say "OrderMgrView-defineDialog-01."


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD activate UNGUARDED
    --say "OrderMgrView-activate-01."
    self~execute("SHOWTOP", IDI_DLG_OOREXX)


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD initDialog
    expose menuBar records iconList
    --say "OrderMgrView-initDialog-01."
    menuBar~attachTo(self)
    menuBar~connectAllCommandEvents    -- (.NET version) ooDialog: new's autoConnect, .true

    -- Create a proxy for the List View and store in instance variable 'lv'.
    self~lv = self~newListView(IDC_ORDMGR_ICONS)

    -- Add the Image List to the ListView:
    self~lv~LargeImageList = iconList  -- ooDialog: self~lv~setImageList(iconList, NORMAL)
    -- Add icons (i.e. records) to the ListView:
    do i=1 to records~items
      self~lv~Items~Add(records[i]~name, i-1)   -- ooDialog: self~lv~addRow(, i-1, records[i]~name)
    end

    self~connectListViewEvent(IDC_ORDMGR_ICONS, "ACTIVATE", "onDoubleClick")
    -- Following line required to allow icons to be dragged around the listview.
    self~connectListViewEvent(IDC_ORDMGR_ICONS, "BEGINDRAG", "DefListDragHandler")
    self~connectButtonEvent("IDC_ORDMGR_EXIT", "CLICKED",exitApp)
    self~connectButtonEvent("IDC_ORDMGR_RESET","CLICKED",resetIcons)
    self~setTitle(.HRSomv~WindowTitle)		-- set dialog title.


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD defineSizing
    --say "OrderMgrView-defineSizing-01."
    -- Called automatically by ooDialog.
    -- Order of arrays: left, top, right, bottom.
    -- Order of array items: pinType, edge-of-other-window, id of other window
    self~controlSizing(IDC_ORDMGR_RESET, -
                       .array~of('STATIONARY', 'LEFT'  ), -
                       .array~of('STATIONARY', 'BOTTOM'), -
                       .array~of('MYLEFT',     'BOTTOM'  ), -
                       .array~of('MYTOP',      'TOP'   )  -
                      )
    self~controlSizing(IDC_ORDMGR_EXIT, -
                       .array~of('STATIONARY', 'RIGHT' ), -
                       .array~of('STATIONARY', 'BOTTOM'), -
                       .array~of('MYLEFT',     'RIGHT' ), -
                       .array~of('MYTOP',      'TOP'   )  -
                      )
    self~controlSizing(IDC_ORDMGR_ICONS, -
                       .array~of('STATIONARY', 'LEFT'  ), -
                       .array~of('STATIONARY', 'TOP'   ), -
                       .array~of('STATIONARY', 'RIGHT' ), -
                       .array~of('STATIONARY', 'BOTTOM')  -
                      )
    return .false


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD createIconList PRIVATE
    -- This method simulates getting the icon "data" for the OrderMgr view.
    -- The icon data is loaded into 'iconList' which is an 'ImageList' as
    -- required by the ListView control.
    expose iconList
    --say "OrderMgrView-createIconList."
    -- (.NET version) the bitmaps as .NET Bitmaps, from the exercise's folder
    -- (ooDialog: .Image~getImage(file)); a .NET ImageList of 64 x 64 images
    -- (ooDialog: .ImageList~create(.Size~new(64, 64), .Image~toId(ILC_COLOR4), 4, 0):
    -- here in 32-bit colour, which shows the 16-colour bitmaps as they are)
    D = .net~System~Drawing
    imgCustList  = D~Bitmap~new("customer\bmp\CustList.bmp")
    imgProdList  = D~Bitmap~new("product\res\ProdList.bmp")
    imgOrderList = D~Bitmap~new("order\bmp\OrderList.bmp")
    imgOrderForm = D~Bitmap~new("order\bmp\OrderForm.bmp")
    iconList = .net~System~Windows~Forms~ImageList~new
    iconList~ImageSize = D~Size~new(64, 64)
    iconList~ColorDepth = "Depth32Bit"

    -- Boldly assume no errors in creating the Image List or in the ~getImage statements.
    iconList~Images~Add(imgCustList)   -- item 0 in iconList (item 1 in records)   ooDialog: iconList~add(...)
    iconList~Images~Add(imgProdList)   -- item 1 in iconList (item 2 in records)
    iconList~Images~Add(imgOrderList)  -- item 2 in iconList (item 3 in records)
    iconList~Images~Add(imgOrderForm)  -- item 3 in iconList (item 4 in records)
    -- ooDialog: imgCustList~release ...: here the ImageList copies them only when
    --   the list view makes its window, so they are left to .NET to free
    return

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD initRecords PRIVATE
    -- This method simulates getting the "data" for the OrderMgr view.
    expose records
    records = .array~new()

    rec = .directory~new
    rec~ID = "CustomerListModel"	-- class name
    rec~name = "Customer List"
    records[1] = rec

    rec = .directory~new
    rec~ID = "ProductListModel"
    rec~name = "Product List"
    records[2] = rec

    rec = .directory~new
    rec~ID = "OrderListModel"
    rec~name = "Sales Orders"
    records[3] = rec

    rec = .directory~new
    rec~ID = "OrderFormModel"
    rec~name = "New Order"
    records[4] = rec

    return records

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
/*  ::METHOD initDialog
    expose records iconList
    --say "OrderMgrView-initDialog."
    self~initDialog:super
    -- Add the Image List to the ListView:
    self~lv~LargeImageList = iconList  -- ooDialog: self~lv~setImageList(iconList, NORMAL)
    -- Add icons (i.e. records) to the ListView:
    do i=1 to records~items
      self~lv~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of(records[i]~name)))   -- ooDialog: ~addRow
    end
*/

  /*----------------------------------------------------------------------------
    Event-Handler Methods - Menu Events
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - Orders  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD newOrder UNGUARDED
    expose records
    self~showModel(records[4])

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD orderList UNGUARDED
    expose records
    self~showModel(records[3])

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD orderSearch UNGUARDED
    self~noMenuFunction(.HRSomv~OrdSrch)

  /*- - Customers - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD customerList UNGUARDED
    expose records
    self~showModel(records[1])

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD customerSearch UNGUARDED
    self~noMenuFunction(.HRSomv~CustSrch)

  /*- - Products  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD productList
    expose records
    self~showModel(records[2])

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD productSearch UNGUARDED
    self~noMenuFunction(.HRSomv~ProdSrch)

  /*- - New - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD product UNGUARDED
    self~noMenuFunction(.HRSomv~NewProd)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD customer UNGUARDED
    self~noMenuFunction(.HRSomv~NewCust)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD order UNGUARDED
    self~newOrder

  /*- - Help - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD about UNGUARDED
    self~noMenuFunction(.HRSomv~HelpAbout)

  /*- - Message Sender- - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD messageSender UNGUARDED
    --say "OrderMgrView-messageSender."
    .MessageSender~newInstance(self)
    --self~noMenuFunction(.HRSomv~HelpAbout)

  /*- - Message Sender- - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD person UNGUARDED
    expose idObjectMgr
    --say "OrderMgrView-Person."
    objectMgr = .local.my.ObjectMgr
    idObjectMgr~showModel("PersonModel","PA150", self)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD noMenuFunction UNGUARDED
    use arg title
    ret = MessageDialog(.HRSomv~NoMenu, self~hwnd, title, 'WARNING')


  /*----------------------------------------------------------------------------
    Event-Handler Methods - Icon Double-Click
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD onDoubleClick UNGUARDED
    expose records
    --use arg id
    --say "OrderMgrView-onDoubleClick-01."
    -- Get the index of the item with the focus, use the index to retrieve
    -- the item's record:
    index = self~lv~FocusedItem~Index	-- lv is an attribute of the superclass.   ooDialog: self~lv~focused
    record = records[index+1]
    --say "OrderMgrView-onDoubleClick-02: Record ID =" record~ID
    self~showModel(record)


  /*----------------------------------------------------------------------------
    Event-Handler Methods - PushButton Events
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD resetIcons
    self~lv~ArrangeIcons               -- ooDialog: r = self~lv~arrange

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD exitApp UNGUARDED
    --say "OrderMgrView-exitApp-01."
    self~cancel

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD cancel
    --say "OrderMgrView-cancel-01."
    response = askDialog(.HRSomv~QExit, "N")
    if response = 1 then forward class (super)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD ok
    -- Invoked when enter key pressed - if passed to superclass, cancels dialog.
    return  -- do not close dialog - appears as a no-op to the user.


  /*----------------------------------------------------------------------------
    Application Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

    /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD showModel UNGUARDED
    /* Surface the view of an icon (i.e. view of the model represented by the icon).
       Ideally, if already instantiated, surface it, else makeInstance.
       In this version, get as many as you like - but all have the same data!.*/
    expose idObjectMgr
    use arg record				-- record is a directory object.
    className = record~ID
    --say "OrderMgrView-showModel-01: className =" className		-- Ex07
    r = idObjectMgr~showModel(classname, "a", self)			-- Ex07


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD autoRun UNGUARDED
    -- (.NET version) unattended: each icon double-clicked, as a user would,
    -- its view running its own autoRun (they are popped up as children of
    -- this one); Help's Person and Message Sender; the menu's other items;
    -- Reset Icons; then Exit Application: it asks, the answer is its
    -- default, No; then the dialog is closed as Yes would.
    expose menuBar records idObjectMgr
    say "(auto) icons:" self~lv~Items~Count", images" self~lv~LargeImageList~Images~Count
    do i = 0 to self~lv~Items~Count - 1
      self~lv~Items[i]~Focused = .true
      self~onDoubleClick
      self~waitForChildren
    end
    do id over .array~of(IDM_PERSON1, IDM_MESSAGE_SENDER1)
      menuBar~item(id)~PerformClick
      self~waitForChildren
    end
    idObjectMgr~list
    do id over .array~of(IDM_ORDMGR_ORDERSEARCH, IDM_ORDMGR_CUSTSEARCH, IDM_ORDMGR_PRODSEARCH, -
                         IDM_ORDMGR_PRODNEW, IDM_ORDMGR_CUSTNEW, IDM_ORDMGR_ABOUT)
      menuBar~item(id)~PerformClick
    end
    self~newPushButton("IDC_ORDMGR_RESET")~PerformClick
    self~newPushButton("IDC_ORDMGR_EXIT")~PerformClick
    say "(auto) still open after No:" self~isDialogActive
    self~endDialog(2)                  -- (ooDialog: the superclass's cancel)

/*============================================================================*/


/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  HRSomv (Human-Readable Strings for OrderMgrView)		  v01-00 07Jun12
  ---
  The HRSomv class provides constant character strings for user-visible messages
  issued by the OrderMgrBaseView class.
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS HRSomv PRIVATE		-- Human-Readable Strings
  ::CONSTANT QExit        "Are you sure you want to close all windows and exit the application?"
  ::CONSTANT NoMenu       "This menu item is not yet implemented."
  ::CONSTANT OM           "Order Manager"
  ::CONSTANT OrdSrch      "Order Search"
  ::CONSTANT CustSrch     "Customer Search"
  ::CONSTANT ProdSrch     "Product Search"
  ::CONSTANT NewCust      "New Customer"
  ::CONSTANT NewProd      "New Product"
  ::CONSTANT HelpAbout    "Help - About"
  ::CONSTANT WindowTitle  "Sales Order Management"	-- Dialog Caption
  ::CONSTANT Reset        "Reset Icons"			-- PushButton
  ::CONSTANT ExitApp      "Exit Application"		-- PushButton

/*============================================================================*/
