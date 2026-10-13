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
   Exercise 08: The Order ListView 				  v03-00 24May13

   Contains: class "OrderListView", "HRSolv"

   Pre-requisite files: OrderListView.rc, OrderListView.h.

   Description: Provides a list of Orders and supports viewing any given
                Order via a double-click on that Order's item in the list.
                This is an "Intermediate" component - it is invoked by OrderMgmt,
                and invokes OrderView.

   Changes:
   v01-00 07Jun12: First Version (Ex06).
   v02-00 25Aug12: Updated for Ex07 using the MVF.
          08Jan13: Removed stand-alone startup (not now needed).
          11Jan13: Commented-out 'say' instructions.
          01Apr13: After ooDialog 4.2.2, Support folder moved to exercise
                   folder, so change to ::Requires needed.
   v03-00 24May13: Exercice08 Update to use View & Component mixin.

   Outstanding Problems: None reported.


   (.NET version, on Windows Forms through oodnet.cls: OrderListView.rc's dialog and
   menu are the classes of OrderListViewrc.cls, written by rc2oodnet.rex -cls; OrderListView
   subclasses the dialog's and inherits the View and Component mixins (Support\View.rex, Component.rex). The list view is .NET's: its Columns and Items, and GridLines,
   FullRowSelect in place of ooDialog's styles; its CLICK event gives .NET's
   (sender, e), the item found by HitTest.)
*******************************************************************************/


-- ooDialog: .Application~addToConstDir("Order\OrderListView.h"): here the ids are names


::REQUIRES "OrderListViewrc.cls"           -- ooDialog: ::REQUIRES "ooDialog.cls"
::REQUIRES "Order\OrderView.rex"
--::REQUIRES "Support\RcView.rex"
::REQUIRES "Support\View.rex"

/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  OrderListView						  	  v01-01 25Aug12
  -------------
  The view of a list of products.
  Changes:
    v01-00 07Jun12: First version

  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */
::CLASS OrderListView SUBCLASS OrderListView_IDD_ORDLIST_LISTVIEW PUBLIC INHERIT View Component   -- ooDialog: SUBCLASS RcDialog PUBLIC INHERIT View Component

  /*----------------------------------------------------------------------------
    Class Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD newInstance CLASS PUBLIC
    use strict arg idModel, rootDlg						  --Ex07
    --say ".OrderListView-newInstance-01: root, idModel =" rootDlg idModel
    dlg = self~new   -- ooDialog: self~new("Order\OrderListView.rc", "IDD_ORDLIST_LISTVIEW")
    --say ".OrderListView-newInstance-02."
    dlg~activate(idModel, rootDlg)					  --Ex07
    return dlg								  --Ex07

  /*----------------------------------------------------------------------------
    Instance Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    Dialog Setup Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD init
    forward class (super) continue
    self~initView
    if \ self~createMenuBar then do		-- if there was a problem
      self~initCode = 1
      return
    end


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD createMenuBar
    -- Creates the menu bar on the dialog.
    expose menuBar
    --say "OrderListView-createMenuBar-01."
    menuBar = .OrderListView_IDR_ORDLIST_MENU~new   -- ooDialog: menuBar = .ScriptMenuBar~new("Order\OrderListView.rc", "IDR_ORDLIST_MENU", , , .true)
    return .true


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD activate UNGUARDED
    expose rootDlg modelData						  --Ex07
    use strict arg idModel, rootDlg					  --Ex07
    --say "OrderListView-activate-01: idModel, root =" idModel rootDlg
    forward class (super) continue					  --Ex07
    modelData = RESULT							  --Ex07
    --say "OrderListView-activate-02: modelData =" modelData
    self~popupAsChild(rootDlg, "SHOWTOP", ,"IDI_ORDLIST_DLGICON")
    --return self								  --Ex07


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD initDialog
    expose menuBar lvOrders btnShowOrder modelData			  --Ex07
    -- Called by ooDialog after SHOWTOP.

    menuBar~attachTo(self)

    menuBar~connectAllCommandEvents    -- (.NET version) ooDialog: new's autoConnect, .true

    --say "OrderListView-initDialog-01"; say
    lvOrders = self~newListView("IDC_ORDLIST_LIST");
    lvOrders~GridLines = .true; lvOrders~FullRowSelect = .true   -- ooDialog: ~addExtendedStyle("GRIDLINES FULLROWSELECT")
    lvOrders~Columns~Add("OrderNo", 60)   -- ooDialog: ~insertColumnPX
    lvOrders~Columns~Add("CustNo", 80)   -- ooDialog: ~insertColumnPX
    lvOrders~Columns~Add("CustName", 130)   -- ooDialog: ~insertColumnPX
    lvOrders~Columns~Add("Date", 80)   -- ooDialog: ~insertColumnPX
    self~connectListViewEvent("IDC_ORDLIST_LIST","CLICK",itemSelected)
    self~connectListViewEvent("IDC_ORDLIST_LIST","ACTIVATE",openItem)	-- double-click
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
    --say "OrderListView-openItem-01: item selected =" item
    self~showOrder


  /*----------------------------------------------------------------------------
    Application Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD showOrder unguarded
    expose lvOrders rootDlg
    item = -1                          -- ooDialog: item = lvOrders~selected
    if lvOrders~SelectedIndices~Count > 0 then item = lvOrders~SelectedIndices[0]
    --say "OrderListView-showOrder-01: item selected =" item
    if item = -1 then do		-- if no item selected.
      ret = MessageDialog(.HRSolv~nilSelected, self~hwnd, title, 'WARNING')
      return
    end
    info=.Directory~new
    info~text = lvOrders~Items[item]~Text   -- ooDialog: lvOrders~getItemInfo(item, info)
    if .true then do
      --say "OrderListView-showOrder-02: info~text =" info~text
      objectMgr = .local~my.ObjectMgr
      objectMgr~showModel("OrderModel", info~text, rootDlg)		--Ex07
      self~disableControl("IDC_ORDLIST_SHOWORDER")
    end
    else do
      say "OrderListView-showOrder-04: ~getItemInfo returned .false."
    end

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD loadList
    expose lvOrders modelData						-- Ex07
    --say "OrderListView-loadList-01: dataArray =" modelData		-- Ex07
    rows = modelData[count]						-- Ex07 - number of rows
    arrData = modelData[records]
    --say "OrderListView-loadList-02:Dims =" modelData~dimension(1) modelData~dimension(2)
    do i = 1 to rows
      --say "OrderListView-loadList-04a: modelData[i,2] =" modelData[i,2]
      -- Change date to display format - i.e. yymmdd to (US format!) mm-dd-yy):
      date = arrData[i,3]
      displayDate = date~substr(3,2)||"/"||date~substr(5)||"/"||date~substr(1,2)
      lvOrders~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of(arrData[i,1], arrData[i,2], arrData[i,6], displayDate)))   -- ooDialog: ~addRow
    end
    lvOrders~Columns[2]~Width = -1   -- set width of 3rd column to longest text entry.   (ooDialog: ~setColumnWidth)



  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD autoRun UNGUARDED
    -- (.NET version) unattended: a row selected, Show Order, the menu's
    -- items; then the list closed.
    expose lvOrders menuBar
    say "(auto) rows:" lvOrders~Items~Count", the first" lvOrders~Items[0]~Text
    lvOrders~Items[0]~Selected = .true
    self~enableControl("IDC_ORDLIST_SHOWORDER")
    self~newPushButton("IDC_ORDLIST_SHOWORDER")~PerformClick
    self~waitForChildren               -- (its view, if this list owns it, runs its own autoRun)
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


