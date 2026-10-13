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
   Exercise 06: The OrderView class				  v01-00 07Jun12

   OrderFormView.rex

   Contains: class "OrderView".
   Pre-requisite files: OrderView.rc, OrderView.h.

   Description: A sample Order View component - part of the sample
        	Order Management application.
        	This is a "leaf" component - invoked by OrderListView.

   Outstanding Problems: None reported.

   Changes:
     v01-00 07Jun12: First Version


   (.NET version, on Windows Forms through oodnet.cls: OrderView.rc's dialog and
   menu are the classes of OrderViewrc.cls, written by rc2oodnet.rex -cls; OrderView
   subclasses the dialog's in place of RcDialog, its menu is a NetMenuBar.
   The dialog's icon is Windows Forms' own.)
------------------------------------------------------------------------------*/


-- ooDialog: .Application~addToConstDir("Order\OrderView.h"): here the ids are names


::REQUIRES "OrderViewrc.cls"                 -- ooDialog: ::REQUIRES "ooDialog.cls"
::REQUIRES "Order\OrderModelData.rex"


/*==============================================================================
  OrderView							  v01-00 07Jun12
  -------------
  The "view" (or "gui") part of the Order component - part of the sample
  Order Management application.

  Changes:
    v01-00 07Jun12: First Version.

  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS OrderView SUBCLASS OrderView_IDD_ORDER_DIALOG PUBLIC   -- ooDialog: SUBCLASS RcDialog

  ::METHOD newInstance CLASS PUBLIC
    expose rootDlg
    use arg rootDlg, orderNo
    say ".OrderView-newInstance: rootDlg =" rootDlg
    dlg = self~new                     -- ooDialog: self~new("Order\OrderView.rc", "IDD_ORDER_DIALOG")
    dlg~activate(rootDlg, orderNo)

  /*----------------------------------------------------------------------------
    Dialog Setup Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD init
    -- creates the dialog instance but does not make it visible.
    expose menuBar
    say "OrderView-init-01"

    forward class (super) continue

    if \ self~createMenuBar then do		-- if there was a problem
      self~initCode = 1
      return
    end


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD createMenuBar
    -- Creates the menu bar on the dialog.
    expose menuBar
    say "OrderView-createMenuBar-01"
    menuBar = .OrderView_IDR_ORDER_MENU~new   -- ooDialog: .ScriptMenuBar~new("Order\OrderView.rc", IDR_ORDER_MENU, , , .true)

    return .true


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD activate unguarded
    use arg rootDlg
    -- Shows the Dialog - i.e. makes it visible to the user.
    say "OrderView-activate-01"
    if rootDlg = "SA" then self~execute("SHOWTOP","IDI_ORDER_DLGICON")
    else self~popUpAsChild(rootDlg,"SHOWTOP",,"IDI_ORDER_DLGICON")
    return


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD initDialog
    -- Called by ooDialog after SHOWTOP.
    expose menuBar custControls
    say "OrderView-initDialog-01"

    menuBar~attachTo(self)
    menuBar~connectAllCommandEvents    -- (.NET version) ooDialog: new's autoConnect, .true

    return

  /*----------------------------------------------------------------------------
    Event-Handler Methods - Menu Events
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD anAction UNGUARDED
    self~noMenuFunction(.HRSov~anAction)

  /*- - Help - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD about UNGUARDED
    self~noMenuFunction(.HRSov~HelpAbout)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD noMenuFunction UNGUARDED
    use arg title
    ret = MessageDialog(.HRSov~NoMenu, self~hwnd, title, 'WARNING')

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
    -- "Cancel" - This method over-rides the default Windows action of
    -- 'cancel window' for an Escape key.
  ::METHOD cancel
    response = askDialog(.HRSov~QExit, "N")
    if response = 1 then forward class (super)
    return

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD autoRun UNGUARDED
    -- (.NET version) unattended: the menu's items, then Cancel: it asks, and
    -- the answer is its default, No; then the dialog is closed as Yes would.
    expose menuBar
    menuBar~item(IDM_ORDER_DOTHIS)~PerformClick
    menuBar~item(IDM_ORDER_ABOUT)~PerformClick
    self~cancel
    say "(auto) still open after No:" self~isDialogActive
    self~endDialog(2)                  -- (ooDialog: the superclass's cancel)

/*============================================================================*/


/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  Human-Readable Strings (HRSov)				  v01-00 07Jun12
  --------
   The HRSofv class provides constant character strings for user-visible messages.
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS HRSov PRIVATE	   -- Human-Readable Strings
  ::CONSTANT anAction    "An Action"
  ::CONSTANT NoMenu      "This menu item is not implemented."
  ::CONSTANT QExit       "Are you sure you want to cancel this Order View?"
  ::CONSTANT HelpAbout   "About Sales Order"

/*============================================================================*/

