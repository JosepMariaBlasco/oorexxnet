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
   Exercise 06: The Order ListView 				  v01-00 07Jun12

   Contains: class "OrderListView", "HRSolv"

   Pre-requisite files: OrderListView.rc, OrderListView.h.

   Description: Provides a list of Orders and supports viewing any given
                Order via a double-click on that Order's item in the list.
                This is an "Intermediate" component - it is invoked by OrderMgmt,
                and invokes OrderView.

   Changes:
     v01-00 07Jun12: First Version

   Outstanding Problems: None reported.


   (.NET version, on Windows Forms through oodnet.cls: OrderListView.rc's
   dialog and menu are the classes of OrderListViewrc.cls, written by
   rc2oodnet.rex -cls. The list view is .NET's: its Columns and Items, and
   GridLines, FullRowSelect in place of ooDialog's styles; its CLICK event
   gives .NET's (sender, e), the item found by HitTest.)
*******************************************************************************/


-- ooDialog: .Application~addToConstDir("Order\OrderListView.h"): here the ids are names


::REQUIRES "OrderListViewrc.cls"             -- ooDialog: ::REQUIRES "ooDialog.cls"
::REQUIRES "Order\OrderView.rex"


/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  OrderListView						  	  v01-00 07Jun12
  -------------
  The view of a list of products.
  Changes:
    v01-00 07Jun12: First version

  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS OrderListView SUBCLASS OrderListView_IDD_ORDLIST_LISTVIEW PUBLIC   -- ooDialog: SUBCLASS RcDialog

  /*----------------------------------------------------------------------------
    Class Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD newInstance CLASS PUBLIC
    use arg rootDlg
    say ".OrderListView-newInstance-01: root =" "'"||rootDlg||"'"
    dlg = self~new                     -- ooDialog: self~new("Order\OrderListView.rc", "IDD_ORDLIST_LISTVIEW")
    say ".OrderListView-newInstance-02."
    dlg~activate(rootDlg)				-- Must be the last statement.


  /*----------------------------------------------------------------------------
    Instance Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    Dialog Setup Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD init
    forward class (super) continue
    if \ self~createMenuBar then do		-- if there was a problem
      self~initCode = 1
      return
    end


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD createMenuBar
    -- Creates the menu bar on the dialog.
    expose menuBar
    say "OrderListView-createMenuBar-01."
    menuBar = .OrderListView_IDR_ORDLIST_MENU~new   -- ooDialog: .ScriptMenuBar~new("Order\OrderListView.rc", "IDR_ORDLIST_MENU", , , .true)
    return .true


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD activate unguarded
    expose rootDlg
    use arg rootDlg
    say "OrderListView-activate-01: root =" rootDlg
    --trace i
    if rootDlg = "SA" then do			-- If standalone operation required
      rootDlg = self				      -- To pass on to children
      self~execute("SHOWTOP","IDI_ORDLIST_DLGICON")
    end
    else self~popupAsChild(rootDlg, "SHOWTOP", ,"IDI_ORDLIST_DLGICON")
    return


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD initDialog
    expose menuBar lvOrders btnShowOrder
    -- Called by ooDialog after SHOWTOP.

    menuBar~attachTo(self)
    menuBar~connectAllCommandEvents    -- (.NET version) ooDialog: new's autoConnect, .true

    say "OrderListView-initDialog-01"; say
    lvOrders = self~newListView("IDC_ORDLIST_LIST");
    lvOrders~GridLines = .true; lvOrders~FullRowSelect = .true   -- ooDialog: ~addExtendedStyle("GRIDLINES FULLROWSELECT")
    lvOrders~Columns~Add("OrderNo", 60, "Left")   -- ooDialog: ~insertColumnPX
    lvOrders~Columns~Add("CustNo", 80, "Left")   -- ooDialog: ~insertColumnPX
    lvOrders~Columns~Add("CustName", 130, "Left")   -- ooDialog: ~insertColumnPX
    lvOrders~Columns~Add("Date", 80, "Left")   -- ooDialog: ~insertColumnPX
    self~connectListViewEvent("IDC_ORDLIST_LIST","CLICK",itemSelected)
    self~connectListViewEvent("IDC_ORDLIST_LIST","ACTIVATE",openItem)
    self~connectButtonEvent("IDC_ORDLIST_SHOWORDER","CLICKED",showOrder)

    self~loadList


  /*----------------------------------------------------------------------------
    Event-Handler Methods - Menu Events
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD newOrder UNGUARDED
    self~noMenuFunction(.HRSolv~newOrder)

  /*- - Help - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD about UNGUARDED
    self~noMenuFunction(.HRSolv~helpAbout)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD noMenuFunction UNGUARDED
    use arg title
    ret = MessageDialog(.HRSolv~noMenu, self~hwnd, title, 'WARNING')


  /*----------------------------------------------------------------------------
    Event Handling Methods - List Items
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD itemSelected unguarded
    expose lvOrders --btnShowOrder
    use arg sender, e                  -- ooDialog: use arg id, itemIndex, columnIndex, keyState
    hit = sender~HitTest(e~Location)   -- (.NET version) the row clicked, if any
    itemIndex = -1
    if hit~Item \== .nil then itemIndex = hit~Item~Index
    if itemIndex > -1 then self~enableControl("IDC_ORDLIST_SHOWORDER")
    else self~disableControl("IDC_ORDLIST_SHOWORDER")


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD openItem UNGUARDED
    say "OrderListView-openItem-01: item selected =" item
    self~showOrder


  /*----------------------------------------------------------------------------
    Application Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD showOrder unguarded
    expose lvOrders rootDlg
    item = -1                          -- ooDialog: item = lvOrders~selected
    if lvOrders~SelectedIndices~Count > 0 then item = lvOrders~SelectedIndices[0]
    say "OrderListView-showOrder-01: item selected =" item
    if item = -1 then do		-- if no item selected.
      ret = MessageDialog(.HRSolv~nilSelected, self~hwnd, title, 'WARNING')
      return
    end
    info=.Directory~new
    info~text = lvOrders~Items[item]~Text   -- ooDialog: lvOrders~getItemInfo(item, info)
    if .true then do
      say "OrderListView-showOrder-02: info~text =" info~text
      .local~my.idOrderData  = .OrderData~new	-- create Order Data instance
      .local~my.idOrderModel = .OrderModel~new	-- create Order Model instance
      .local~my.idOrderData~activate
      .local~my.idOrderModel~activate
      .OrderView~newInstance(rootDlg,"DM00263")
      --say "OrderListView-showOrder-03: after startOrderView"
      self~disableControl("IDC_ORDLIST_SHOWORDER")
    end
    else do
      say "OrderListView-showOrder-04: ~getItemInfo returned .false."
    end

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD loadList
    expose lvOrders

    lvOrders~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of("DM00263", "CU003",   "ABC Inc.",   "21Nov12")))   -- ooDialog: ~addRow
    lvOrders~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of("DM10473", "AB15784", "Frith Inc.", "12Oct12")))   -- ooDialog: ~addRow
    lvOrders~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of("DM13003", "CU001",   "LMN & Co",   "07Jun12")))   -- ooDialog: ~addRow
    lvOrders~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of("AS49005", "CU003",   "EJ Smith",   "30Aug12")))   -- ooDialog: ~addRow
    lvOrders~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of("AM72010", "CU005",   "Red-On Inc.","17Jan13")))   -- ooDialog: ~addRow
    lvOrders~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of("OZ15784", "CU003",   "Joe Bloggs & Co Ltd","28Feb13")))   -- ooDialog: ~addRow
    /*do i = 1 to 50
      lvOrders~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of("Line" i, i)))   -- ooDialog: ~addRow
    end*/
    lvOrders~Columns[1]~Width = -1   -- set width of 2nd column to longest text entry.   (ooDialog: ~setColumnWidth)


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD autoRun UNGUARDED
    -- (.NET version) unattended: a row selected, Show Order, the menu's
    -- items; then the list closed.
    expose lvOrders menuBar
    say "(auto) orders:" lvOrders~Items~Count", the first" lvOrders~Items[0]~Text
    lvOrders~Items[0]~Selected = .true
    self~enableControl("IDC_ORDLIST_SHOWORDER")
    self~newPushButton("IDC_ORDLIST_SHOWORDER")~PerformClick
    self~waitForChildren               -- (the Order view runs its own autoRun)
    menuBar~item(IDM_ORDLIST_NEWORDER)~PerformClick
    menuBar~item(IDM_ORDLIST_ABOUT)~PerformClick
    self~cancel


/*============================================================================*/


/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  HRSolv (Human-Readable Strings for OrderListView)		  v01-00 07Jun12
  ---
  The HRSolv class provides constant character strings for user-visible messages
  issued by the OrderListView class.

  Changes:
   v01-00 07Jun12: First Version
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */


::CLASS HRSolv PRIVATE		-- Human-Readable Strings
  ::CONSTANT noMenu       "This menu item is not yet implemented."
  ::CONSTANT newOrder     "New Order"
  ::CONSTANT helpAbout    "Help - About"
  ::CONSTANT nilSelected  "Please select an item first."

/*============================================================================*/


