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
   Exercise06: The Product List View				  v01-00 06Jun12

   Contains: classes "ProductListView, HRSplv (for human-readable strings)

   Pre-requisites: ProductListView.rc, ProductListView.h, ProdList.ico

   Description: An "intermediate" component - called by OrderMgr,
                invokes "ProductView".

   Changes:
   v01-00 06Jun12: First version.

   Outstanding Problems: None reported.

   (.NET version, on Windows Forms through oodnet.cls: ProductListView.rc's
   dialog and menu are the classes of ProductListViewrc.cls, written by
   rc2oodnet.rex -cls. The list view is .NET's: its Columns and Items, and
   GridLines, FullRowSelect in place of ooDialog's styles; its CLICK event
   gives .NET's (sender, e), the item found by HitTest.)
*******************************************************************************/

-- ooDialog: .Application~addToConstDir("Product\ProductListView.h"): here the ids are names


::REQUIRES "ProductListViewrc.cls"           -- ooDialog: ::REQUIRES "ooDialog.cls"
::REQUIRES "Product\ProductView.rex"


/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  ProductListView						  v01-00 06Jun12
  -------------
  The view of a list of products.
  Changes:
    v01-00: First version

  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS ProductListView SUBCLASS ProductListView_IDD_PRODLIST_DIALOG PUBLIC   -- ooDialog: SUBCLASS RcDialog

  /*----------------------------------------------------------------------------
    Class Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD newInstance CLASS PUBLIC
    use arg rootDlg
    --say ".ProductListView-newInstance-01: rootDlg =" rootDlg
    dlg = self~new                     -- ooDialog: self~new("Product\ProductListView.rc", "IDD_PRODLIST_DIALOG")
    --say ".ProductListView-newInstance-02."
    dlg~activate(rootDlg)


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
    --say "ProductListView-createMenuBar-01."
    menuBar = .ProductListView_IDR_PRODLIST_MENU~new   -- ooDialog: .ScriptMenuBar~new("Product\ProductListView.rc", "IDR_PRODLIST_MENU", , , .true)
    return .true


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD activate unguarded
    expose rootDlg
    use arg rootDlg
    --say "ProductListView-activate-01: root =" root

    if rootDlg = "SA" then do			-- If standalone operation required
      rootDlg = self				      -- To pass on to children
      self~execute("SHOWTOP","IDI_PRODLIST_DLGICON")
    end
    else self~popupAsChild(rootDlg, "SHOWTOP", ,"IDI_PRODLIST_DLGICON")
    return


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD initDialog
    expose menuBar lvProducts btnShowProduct
    -- Called by ooDialog after SHOWTOP.

    menuBar~attachTo(self)
    menuBar~connectAllCommandEvents    -- (.NET version) ooDialog: new's autoConnect, .true

    --say "ProductListView-initDialog-01"; say
    lvProducts = self~newListView("IDC_PRODLIST_LISTVIEW");
    lvProducts~GridLines = .true; lvProducts~FullRowSelect = .true   -- ooDialog: ~addExtendedStyle("GRIDLINES FULLROWSELECT")
    lvProducts~Columns~Add("Number", 60)   -- ooDialog: ~insertColumnPX
    lvProducts~Columns~Add("Name", 150)   -- ooDialog: ~insertColumnPX
    lvProducts~Columns~Add("Zip", 50)   -- ooDialog: ~insertColumnPX
    self~connectListViewEvent("IDC_PRODLIST_LISTVIEW","CLICK",itemSelected)
    self~connectListViewEvent("IDC_PRODLIST_LISTVIEW","ACTIVATE",openItem)
    self~connectButtonEvent("IDC_PRODLIST_SHOWPRODUCT","CLICKED",showProduct)

    self~loadList


  /*----------------------------------------------------------------------------
    Event-Handler Methods - Menu Events
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD newProduct UNGUARDED
    self~noMenuFunction(.HRSplv~newProd)

  /*- - Help - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD about UNGUARDED
    self~noMenuFunction(.HRSplv~helpAbout)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD noMenuFunction UNGUARDED
    use arg caption
    ret = MessageDialog(.HRSplv~noMenu, self~hwnd, caption, 'WARNING')

  /*----------------------------------------------------------------------------
    Event Handling Methods - List Items
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD itemSelected unguarded
    expose lvProducts
    use arg sender, e                  -- ooDialog: use arg id, itemIndex, columnIndex, keyState
    hit = sender~HitTest(e~Location)   -- (.NET version) the row clicked, if any
    itemIndex = -1
    if hit~Item \== .nil then itemIndex = hit~Item~Index
    --say "ProductListView-itemSelected: itemIndex, columnIndex, keyState:" itemIndex columnIndex keyState
    --say "ProductListView-itemSelected: item selected is:"lvProducts~selected
    if itemIndex > -1 then self~enableControl("IDC_PRODLIST_SHOWPRODUCT")
    else self~disableControl("IDC_PRODLIST_SHOWPRODUCT")


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD openItem UNGUARDED
    --say "ProductListView-openItem-01: item selected =" item
    self~showProduct

  /*----------------------------------------------------------------------------
    Application Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD showProduct UNGUARDED
    expose lvProducts rootDlg
    item = -1                          -- ooDialog: item = lvProducts~selected
    if lvProducts~SelectedIndices~Count > 0 then item = lvProducts~SelectedIndices[0]
    say "ProductListView-showProduct-01: item selected =" item
    if item = -1 then do		-- if no item selected.
      ret = MessageDialog(.HRSplv~nilSelected, self~hwnd, title, 'WARNING')
      return
    end
    info=.Directory~new
    info~text = lvProducts~Items[item]~Text   -- ooDialog: lvProducts~getItemInfo(item, info)
    if .true then do
      --say "ProductListView-showProduct-02: info~text =" info~text
      --say "ProductListView-showProduct-03; root =" root
      .local~my.idProductData  = .ProductData~newInstance	-- create a ProductData instance
      .local~my.idProductModel = .ProductModel~newInstance	-- create a ProductModel instance
      .local~my.idProductData~activate
      .local~my.idProductModel~activate
      .ProductView~newInstance(rootDlg,"CU003")
      --say "ProductListView-showProduct-04: after startProductView"
      self~disableControl("IDC_PRODLIST_SHOWPRODUCT")
    end
    else do
      say "ProductListView-showProduct-05: ~getItemInfo returned .false."
    end

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD loadList
    expose lvProducts
    -- (.NET version) ooDialog's addRow(index, , ...) inserts the row at index,
    -- or at the end if there are fewer rows: Items~Insert, the index clamped
    call addRow lvProducts, 2, "CU003","Widget, 5in"                 -- ooDialog: lvProducts~addRow(2, ,"CU003","Widget, 5in")
    call addRow lvProducts, 4, "CU025","Slodget, case of 24", "RG7 3UP"
    call addRow lvProducts, 3, "DX210","Driblet, 5in, 10-pack, no delivery.", "021956"
    do i = 1 to 50
      call addRow lvProducts, i, "Line" i, i
    end
    lvProducts~Columns[1]~Width = -1	-- set width of 2nd column to longest text entry.   ooDialog: ~setColumnWidth(1)


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD autoRun UNGUARDED
    -- (.NET version) unattended: a row selected, Show Product, the menu's
    -- items; then the list closed.
    expose lvProducts menuBar
    say "(auto) products:" lvProducts~Items~Count", the first two" lvProducts~Items[0]~Text"," lvProducts~Items[1]~Text
    lvProducts~Items[0]~Selected = .true
    self~enableControl("IDC_PRODLIST_SHOWPRODUCT")
    self~newPushButton("IDC_PRODLIST_SHOWPRODUCT")~PerformClick
    self~waitForChildren               -- (the Product view runs its own autoRun)
    menuBar~item(IDM_PRODLIST_NEWPROD)~PerformClick
    menuBar~item(IDM_PRODLIST_ABOUT)~PerformClick
    self~cancel

/*============================================================================*/


/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  HRSplv (Human-Readable Strings for ProductListView)		  v01-00 06Jun12
  ------
  The HRS class provides constant character strings for user-visible messages
  issued by the ProductListView class.
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */


::CLASS HRSplv PRIVATE		-- Human-Readable Strings
  ::CONSTANT noMenu       "This menu item is not yet implemented."
  ::CONSTANT newProd      "New Product"
  ::CONSTANT helpAbout    "Help - About"
  ::CONSTANT nilSelected  "Please select an item first."

/*============================================================================*/


/* (.NET version) ooDialog's ListView~addRow(index, , text...): a row of
   texts inserted at index, or at the end */
::ROUTINE addRow
  use arg lv, index
  texts = arg(3, "A")
  lv~Items~Insert(min(index, lv~Items~Count), .net~System~Windows~Forms~ListViewItem~new(texts))
