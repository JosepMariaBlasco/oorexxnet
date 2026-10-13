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
   Exercise 07: The CustomerView component             		  v02-00 01Apr13

   Contains: 	   class "CustomerView";  routine "startCustomerView".
   Pre-requisites: RcView.rex, CustomerView.rc, CustomerView.h.

   Description: A sample Customer View component - part of the sample
        	Order Management application. This is a "leaf" component -
        	it does not invoke other components.

   Changes:
   v01-00 01Jun12: First version (Exercise04).
   v01-01 07Jun12: Minor changes for Exercise06.
   ....
   v02-00 09Aug12: Changed to use MVF.
          09Jan13: Removed stand-alone startup (not now needed).
                   Changes to CustomerView (not at v03-00).
          01Apr13: After ooDialog 4.2.2, Support folder moved to exercise
                   folder, so change to ::Requires needed.

   (.NET version, on Windows Forms through oodnet.cls: CustomerView.rc's
   dialog and menu are the classes of CustomerViewrc.cls, written by
   rc2oodnet.rex -cls; CustomerView subclasses the dialog's and inherits
   RcView (Support\RcView.rex: a mixin here), its menu is a NetMenuBar. The
   edit controls are .NET TextBoxes: ReadOnly, Text and Lines in place of
   setReadOnly, setText and getLine. The dialog's icon is Windows Forms' own.)
------------------------------------------------------------------------------*/


-- ooDialog: .Application~addToConstDir("Customer\CustomerView.h"): here the ids are names


::REQUIRES "CustomerViewrc.cls"            -- ooDialog: ::REQUIRES "ooDialog.cls"
::REQUIRES "support\RcView.rex"

/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  CustomerView							  v03-00 01Apr13
  -------------
  The "view" (or "gui") part of the Customer component - part of the sample
  Order Management application.
  Changes:
    v00-02: Prevented close on enter key by providing no-op "ok" method.
            Changed tab order on window by changing sequence of controls in .rc file
    v00-03: Changed symbolic IDs to conform with naming convention
            Added initAutoDetection method because deleted dlgData. from
	    dlg~new statement in starter.rex.
    v00-04: Took out the OK method - include that in Exercise05.
    v00-05: Modified to use CustomerData and CustomerModel classes.
    Mods after Exercise04:
    v02-00: Added "newInstance" class method - removed routine "StartCustomerView".
    v02-01 19Sep11: Corrected for stand-alone invocation.
    v02-02 04Oct11: Added msgbox for unimplemented menu item.
    v02-03 28Jan12: Changed class name HRS to HRSclv to allow for multiple
     		    HRS classes in same file at some future time.
    v02-04 11Feb12: moved .application~setDefaults() to app startup file.
                    changed to .application~addToConstDir() here.
    v02-05 19Feb12: Moved .Application~addToConstDir statement from newInstance
                    method to top of file - just before ::requires statement(s).
    v03-00 09Aug12: Changed to use MVF. Stand-alone startup removed.
           09Jan13: Removed stand-alone startup (not now needed).
                    Commented out most 'say' instructions.
                    Removed 'getData' method - redundant with MVF.
                    Modified handling of Cust Address due to change in data
                      format of Cust Address (now provided as string via MVF
                      from Customer File).
                    Deleted a number of "say" instructions.

  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

  ::CLASS CustomerView SUBCLASS CustomerView_IDD_CUST_DIALOG INHERIT RcView PUBLIC			       -- v03-00   -- ooDialog: SUBCLASS RcView
  /*----------------------------------------------------------------------------
    Class Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  ::METHOD newInstance CLASS PUBLIC UNGUARDED
    use arg idCustomerModel, rootDlg						-- Ex07
    -- Create an instance of CustomerView and show it:
    dlg = .CustomerView~new   -- ooDialog: .CustomerView~new("Customer\CustomerView.rc", "IDD_CUST_DIALOG")
    dlg~activate(idCustomerModel, rootDlg)					-- Ex07
    return dlg									-- Ex07


  /*----------------------------------------------------------------------------
    Dialog Creation Methods:
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Init - creates the dialog instance but does not make it visible.        --*/
  ::METHOD init
    expose menuBar

    forward class (super) continue

    if \ self~createMenuBar then do		-- if there was a problem
      self~initCode = 1
      return
    end


  /*-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Create Menu Bar - Creates the menu bar on the dialog.                   --*/
  ::METHOD createMenuBar
    expose menuBar
    menuBar = .CustomerView_IDR_CUST_MENU~new   -- ooDialog: menuBar = .ScriptMenuBar~new("Customer\CustomerView.rc", "IDR_CUST_MENU", , , .true)
    return .true


  /*-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Activate - Shows the Dialog - i.e. makes it visible to the user.        --*/
  ::METHOD activate unguarded
    expose custData
    use arg idCustomerModel, rootDlg 	-- ADDED FOR EXERCISE06. Params reversed for Ex07.
    forward class (super) continue	-- Ex07: Required for MV framework.
    custData = RESULT			-- Ex07: instance data returned by super
    					-- Ex07: ('forward' returns any result via 'RESULT'.)
    self~popUpAsChild(rootDlg,"SHOWTOP",,"IDI_CUST_DLGICON")			-- Ex07: deleted "standalone" startup.
    return


  /*-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    InitDialog - Called by ooDialog 					   -- */
  ::METHOD initDialog
    expose menuBar custControls
    menuBar~attachTo(self)
    menuBar~connectAllCommandEvents    -- (.NET version) ooDialog: new's autoConnect, .true
    -- Create objects that map to the edit controls defined by the "customer.rc"
    --   so they can be programmatically used elsewhere in the class:
    custControls = .Directory~new
    custControls[ecCustNo]         = self~newEdit("IDC_CUST_EDT_CUSTNO")
    custControls[ecCustName]       = self~newEdit("IDC_CUST_EDT_CUSTNAME")
    custControls[ecCustAddr]       = self~newEdit("IDC_CUST_EDT_CUSTADDR")
    custControls[ecCustZip]        = self~newEdit("IDC_CUST_EDT_CUSTZIP")
    custControls[ecCustDiscount]   = self~newEdit("IDC_CUST_EDT_DISCOUNT")
    custControls[stLastOrder] = self~newStatic("IDC_CUST_STC_LASTORDERDETAILS")
    -- Create an object for the "Record Change" pushbutton in order to be able
    --   to change its focus later:
    custControls[btnRecordChanges] = self~newPushButton("IDC_CUST_BTN_RECORDCHANGES")
    -- Define event handler methods for push-buttons:
    self~connectButtonEvent("IDC_CUST_BTN_RECORDCHANGES","CLICKED",recordChanges)
    self~connectButtonEvent("IDC_CUST_BTN_SHOWLASTORDER","CLICKED",showLastOrder)

    self~setTitle(.HRScv~dlgTitle)		-- set dialog title.

    -- Show app data:
    self~showData

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */


  /*----------------------------------------------------------------------------
    MenuBar Methods:
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    New Customer... Not fully implemented - merely tells user to use the
                    Customer List object.           		            --*/
  ::METHOD newCustomer unguarded
    answer = MessageDialog(.HRScv~useList, self~hwnd,.HRScv~useListCap,"INFORMATION")


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Update - Sets fields to edit mode so that user can change the data.
             Business Rule: Customer Number cannot be changed.              --*/
  ::METHOD update unguarded
    expose custControls
    custControls[ecCustName]~ReadOnly = .false    -- ooDialog: ~setReadOnly(.false)
    custControls[ecCustAddr]~ReadOnly = .false    -- ooDialog: ~setReadOnly(.false)
    custControls[ecCustZip]~ReadOnly = .false    -- ooDialog: ~setReadOnly(.false)
    custControls[ecCustDiscount]~ReadOnly = .false    -- ooDialog: ~setReadOnly(.false)
    self~enableControl("IDC_CUST_BTN_RECORDCHANGES")
    -- ooDialog: custControls[btnRecordChanges]~state = "FOCUS": the button is
    --   the form's AcceptButton already (DEFPUSHBUTTON in the .rc)
    custControls[ecCustName]~Focus                  -- ooDialog: self~focusControl("IDC_CUST_EDT_CUSTNAME")


  /*-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Last Order - Displays info about the last order placed by this customer.--*/
  ::METHOD lastOrder unguarded
    expose custControls
    use arg button
    orderDate="31/12/11";   orderNum = "ZZ999";   orderTotal = "$999.99"
    lastOrder = orderDate "   " orderNum "   " orderTotal
    custControls[stLastOrder]~Text = lastOrder   -- ooDialog: ~setText


  /*-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Print - Not implemented yet                                             --*/
  ::METHOD print unguarded
    msg = "The 'Print...' menu item is not yet implemented."
    ret = MessageDialog(.HRScv~noPrint, self~hwnd, .HRScv~noPrintCap, 'WARNING')


  /*----------------------------------------------------------------------------
    PushButton Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Record Changes - Collects new data, checks if there has indeed been a
                       change, and if not, issues a warning msg and disables
                       the button.                                          --*/
  ::METHOD recordChanges unguarded
    expose custControls custData newCustData

    newCustData = .directory~new
    newCustData[custName] = custControls[ecCustName]~Text
    newCustData[custAddr] = .array~new
    addrLines = custControls[ecCustAddr]~Lines                -- ooDialog: ~lines, ~getLine(i)
    do i=1 to addrLines~items
      newCustData[custAddr][i] = addrLines[i]
    end
    newCustData[custZip] = custControls[ecCustZip]~Text
    newCustData[custDiscount] = custControls[ecCustDiscount]~Text

    -- Check if anything's changed:
    result = self~checkForChanges
    --if result then say "CustomerView-recordChanges-01: There were changes!"
    --else say "CustomerView-recordChanges-02: No Changes Found"

    /* Send new data to be checked by CustomerModel (not implemented). */

    /* Disable controls that were enabled by menu "File-Update" selection: */
    custControls[ecCustName]~ReadOnly = .true    -- ooDialog: ~setReadOnly(.true)
    custControls[ecCustAddr]~ReadOnly = .true    -- ooDialog: ~setReadOnly(.true)
    custControls[ecCustZip]~ReadOnly = .true    -- ooDialog: ~setReadOnly(.true)
    custControls[ecCustDiscount]~ReadOnly = .true    -- ooDialog: ~setReadOnly(.true)
    self~disableControl("IDC_CUST_BTN_RECORDCHANGES")


  /*----------------------------------------------------------------------------
    Show Last Order - displays mock sales order info in the Last_Order_Details
                        field; info is hard-coded in this method.           --*/
  ::METHOD showLastOrder unguarded
    expose CustControls
    -- Notionally get last order from "SalesOrder" component.
    orderDate="12/2/11";   orderNum = "AB123";   orderTotal = "$524.58"
    lastOrder = orderDate "   " orderNum "   " orderTotal
    custControls[stLastOrder]~Text = lastOrder   -- ooDialog: ~setText


  /*----------------------------------------------------------------------------
    Application Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    showData - displays data in the dialog's controls.                        */
  ::METHOD showData
    expose custData custControls
    -- Show CustNo and CustName:
    custControls[ecCustNo]~Text = custData["CustNo"]   -- ooDialog: ~setText
    custControls[ecCustName]~Text = custData["CustName"]   -- ooDialog: ~setText
    -- Re-format Cust Address from a comma-separated string into a		-- Ex07
    -- line-end-separated string.
    strCustAddr = custData["CustAddr"]~changeStr(",",.endOfLine)
    custControls[ecCustAddr]~Text = strCustAddr   -- ooDialog: ~setText
    -- Finally, show Zip and Discount:
    custControls[ecCustZip]~Text = custData["Zip"]   -- ooDialog: ~setText
    custControls[ecCustDiscount]~Text = custData["CustDisc"]   -- ooDialog: ~setText


  /*--------------------------------------------------------------------------
    checkForChanges - after "Record Changes" actioned by the user, check whether
    any data has actually changed. If it has: (a) assign new data to old data;
    (b) return .true. If it hasn't: return .false.
    Note: cannot just compare the two directories since data format in Address
    is different.                                                           --*/
  ::METHOD checkForChanges
    expose custData newCustData
    changed = .false
    if newCustData[custName] \= custData[custName] then do
      custData[custName] = newCustData[custName]
      changed = .true
    end
    if custData[custAddr] \= newCustData[custAddr] then changed = .true
    if newCustData[custZip] \= custData[custZip] then do
      custdata[custZip] = newCustData[custZip]
      changed = .true
    end
    if newCustData[custDiscount] \= custData[custDiscount] then do
      custData[custDiscount] = newCustData[custDiscount]
      changed = .true
    end
    -- If no changes after all, display message box:
    if \changed then do
      msg = .HRScv~nilChanged
      hwnd = self~dlgHandle
      answer = MessageDialog(msg,hwnd,.HRScv~nilChangedCap,"OK","WARNING","DEFBUTTON2 APPLMODAL")
      end
    else do
      custData = newCustData
    end
    return changed


  /*----------------------------------------------------------------------------
    autoRun - (.NET version) unattended: the menu's items and the buttons, as
              a user would, then the dialog closed.                         --*/
  ::METHOD autoRun unguarded
    expose menuBar custControls
    say "(auto) customer:" custControls[ecCustNo]~Text custControls[ecCustName]~Text
    menuBar~item(IDM_CUST_LAST_ORDER)~PerformClick
    say "(auto) last order:" custControls[stLastOrder]~Text
    menuBar~item(IDM_CUST_UPDATE)~PerformClick
    say "(auto) name read-only:" custControls[ecCustName]~ReadOnly", Record Changes enabled:" custControls[btnRecordChanges]~Enabled
    custControls[btnRecordChanges]~PerformClick               -- (nothing changed: the warning)
    menuBar~item(IDM_CUST_UPDATE)~PerformClick
    custControls[ecCustZip]~Text = "SW1A 2AA"
    custControls[btnRecordChanges]~PerformClick
    self~newPushButton("IDC_CUST_BTN_SHOWLASTORDER")~PerformClick
    say "(auto) show last order:" custControls[stLastOrder]~Text
    menuBar~item(IDM_CUST_NEW)~PerformClick
    menuBar~item(IDM_CUST_PRINT)~PerformClick
    self~cancel

/*============================================================================*/


/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  Human-Readable Strings (HRScv)				  v02-04 13Jan12
  --------
   This class provides constant character strings for user-visible messages.
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS HRScv PRIVATE		-- Human-Readable Strings
  ::CONSTANT nilChanged    "Nothing was changed! Update not done."
  ::CONSTANT nilChangedCap "Update Customer"
  ::CONSTANT noPrint       "The 'Print...' menu item is not yet implemented."
  ::CONSTANT noPrintCap    "*Customer Name*"
  ::CONSTANT dlgTitle	   "*Customer*"
  ::CONSTANT useList       "Please use the Customer List to create a new Customer (not yet implemented)."
  ::CONSTANT useListCap    "Create New Customer"
/*============================================================================*/

