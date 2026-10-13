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
   Exercise 08: MessageSender.rex 				  v01-01 26Jun13

   Contains:  classes: "MessageSender", "HRSms"

   Message Sender is a test/debug/utility support class that enables a user to
   send a message to a component and see what's returned.

   Pre-requisites: the Object Manager (objectMgr.rex). In addition, Message
                   Sender should be launched from some other dialog, since it
                   uses popupAsChild.

   Description: A sample Message Sender utility for sending messages to
                components. Note that the messages that can be sent are probably
                limited, since a full test has not been done.

   Outstanding Problems: None reported.

   Changes:
     v01-00 07Jun12: First Version
            07Aug12: Changed self~execute() to popupAsChild. Launched via a menu
                     item in the Order Management dialog (OrderMgr.rex)
            14Jan13: Commented-out use of ViewMgr (ViewMgr function incomplete)
            05Feb13: Changed edit controls to comboboxes for Target and Method.
                     Provided for user add of methods and target components
                     (not saved over a dialog close).
            11Feb13: No change to function - minor tidy-up of a few comments.
            14Feb13: Correct text in the Help dialog.
     v01-01 25May13: Added Event Manager to list of target objects.
            26Jun13: Added Drag Manager to list of target objects.
            03Jly13: Changed "Exercise07" to "Exercise08" for .h file folder.

  Description:
    Target: className instanceName
    Method: a single method name
    Data:   Either strings separated by "|" (will be sent as an array), or:
            [name]value [name] value ... (will be sent as a directory), or:
            space-separated strings (each is interpreted as a separate
            attribute, so a parameter such as 'aaa bbb' cannot be sent
            at least not in this version).


   (.NET version, on Windows Forms through oodnet.cls: MessageSender.rc's
   dialog is a class of MessageSenderrc.cls, written by rc2oodnet.rex -cls;
   MessageSender subclasses it in place of RcDialog. The combo boxes, edit
   controls and check boxes are .NET's: Items, Text, Lines, Checked,
   FindStringExact in place of ooDialog's add, setText, getLine, uncheck,
   getCheckState, find.)
------------------------------------------------------------------------------*/

-- ooDialog: .Application~addToConstDir("..\Exercise08\Support\MessageSender.h"): here the ids are names

::REQUIRES "MessageSenderrc.cls"           -- ooDialog: ::REQUIRES "ooDialog.cls"


::CLASS 'MessageSender' SUBCLASS MessageSender_DLG_MESSAGESENDER PUBLIC   -- ooDialog: SUBCLASS rcDialog

  /*----------------------------------------------------------------------------
    Class Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    newInstance - class method to create a msg sender.			      */

  ::METHOD newInstance CLASS PUBLIC
    use arg rootDlg
    --say ".MessageSender-newInstance."
    dlg = .MessageSender~new   -- ooDialog: .MessageSender~new("..\Exercise08\Support\MessageSender.rc", "DLG_MESSAGESENDER") --,,"MessageSender.h")
    dlg~activate(rootDlg)
    return
  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    init
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD init
    expose objectMgr eventMgr dragMgr
    --say "MessageSender-init-01."
    forward class (super) continue
    --objectMgr = .local~my.objectMgr
    eventMgr = .local~my.eventMgr
    dragMgr  = .local~my.dragMgr
    .local~my.MsgSender = self
    return
  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    Activate - Shows the Dialog - i.e. makes it visible to the user.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD activate unguarded
    expose rootDlg
    use arg rootDlg
    --say "MessageSender-activate-01."
    self~popupAsChild(rootDlg, "SHOWTOP") --, ,"IDI_CUSTLIST_DLGICON")
    return
  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    initDialog - initialises the MessageSender
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD initDialog
    expose cbTarget cbMethod ecData ecReply btnSend btnClear stErrorMsg objectMgr -
           chkStoreTarget chkStoreMethod arrTargets arrMethods
    --say "MessageSender-initDialog-01."
    cbTarget    = self~newComboBox("IDC_MS_COMPONENT")
    cbMethod    = self~newComboBox("IDC_MS_METHOD")
    ecData      = self~newEdit("IDC_MS_DATA")
    ecReply     = self~newEdit("IDC_MS_REPLY")
    stErrorMsg  = self~newStatic("IDC_MS_ERRORMSG")
    btnSend     = self~newPushButton("IDC_MS_SEND")
    btnClear    = self~newPushButton("IDC_MS_CLEAR")
    chkStoreTarget = self~newCheckBox("IDC_MS_STORETARGET")
    chkStoreMethod = self~newCheckBox("IDC_MS_STOREMETHOD")
    self~connectButtonEvent("IDC_MS_SEND","CLICKED",sendMessage)
    self~connectButtonEvent("IDC_MS_CLEAR","CLICKED",clearEntries)
    self~connectHelp(onHelp)

    errorFont = self~createFontEx("Arial Italic")
    stErrorMsg~Font = errorFont   -- ooDialog: ~setFont(errorFont)
    stErrorMsg~Text = .HRSms~helpMsg   -- ooDialog: ~setText

    -- Get id of ObjectMgr:
    objectMgr = .local~my.objectMgr
    --say "MessageSender-initDialog-02 - objectMgr =" objectMgr
    if objectMgr = .nil then do	-- Check if ObjectMgr is present - .nil if not.
      stErrorMsg~Text = .HRSms~prefix1||.HRSms~noObjectMgr   -- ooDialog: ~setText
      btnSend~Enabled = .false    -- ooDialog: ~disable
    end

    arrTargets = .array~of("ObjectMgr The","EventMgr The","PersonModel PA150")
    arrMethods = .array~of("showModel","query","list")
    do i over arrTargets
      cbTarget~Items~Add(i)            -- ooDialog: cbTarget~add(i)
    end
    do i over arrMethods
      cbMethod~Items~Add(i)            -- ooDialog: cbMethod~add(i)
    end

    return


  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    Event Handler Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    sendMessage - Sends a message to the specified component.
                  Returns .false if error found.
                  Note 1: the return from the target object must be either a bool
                    or a directory. (Later versions may add array and string).
                  Note 2: The "parseData" method displays any error messages
                    resulting from errors in the data provided by the user.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD sendMessage
    expose objectMgr eventMgr ecReply stErrorMsg btnClear chkStoreTarget -
           chkStoreMethod cbTarget cbMethod arrTargets arrMethods
    --say; say "---------------------------------------------------------"
    --say "MessageSender-sendMessage-01."
    ecReply~Text = ""   -- ooDialog: ~setText
    --error = .false		-- if true, indicates error in data provided.
    message = self~parseData	-- data is a directory, array, string; .false if error.

    if message = .false then do -- if errors found in the data.
      --say "MessageSender-sendMessage-02: message =" message
      btnClear~Enabled = .true    -- ooDialog: ~enable
      chkStoreTarget~Checked = .false; chkStoreMethod~Checked = .false   -- ooDialog: ~uncheck
      return .false
    end
    if message = "special" then do	-- message to ObjectMgr has been dealt with.
      btnClear~Enabled = .true    -- ooDialog: ~enable
      chkStoreTarget~Checked = .false; chkStoreMethod~Checked = .false   -- ooDialog: ~uncheck
      return .true
    end

    -- Get the component ID (object ref) from the Object Manager:
    componentRef = objectMgr~getComponentId(message["class"], message["instance"])
    if componentRef = .false then do
      chkStoreTarget~Checked = .false; chkStoreMethod~Checked = .false   -- ooDialog: ~uncheck
      ecReply~Text = .HRSms~rc||" "||componentRef   -- ooDialog: ~setText
      stErrorMsg~Text = .HRSms~prefix1||" "||.HRSms~noObject   -- ooDialog: ~setText
      btnClear~Enabled = .true    -- ooDialog: ~enable
      return .false
    end

    -- Send the Message and Display the response:
    --say "MessageSender-sendMessage-03: message[data] =" message["data"]
    response = sendMsg(componentRef, message["method"],message["data"])
    select
      when response = "SendMsg - Syntax Error" then do
        chkStoreTarget~Checked = .false; chkStoreMethod~Checked = .false   -- ooDialog: ~uncheck
        stErrorMsg~Text = .HRSms~noResponse   -- ooDialog: ~setText
        btnClear~Enabled = .true    -- ooDialog: ~enable
        return
      end
      when response = "SendMsg - No Method" then do
        chkStoreTarget~Checked = .false; chkStoreMethod~Checked = .false   -- ooDialog: ~uncheck
        stErrorMsg~Text = .HRSms~noTgtMethod   -- ooDialog: ~setText
        btnClear~Enabled = .true    -- ooDialog: ~enable
        return
      end
      when response = .false then do
        chkStoreTarget~Checked = .false; chkStoreMethod~Checked = .false   -- ooDialog: ~uncheck
        ecReply~Text = .HRSms~rc||" "||response   -- ooDialog: ~setText
        return
      end

      when response~isa(.String) then do
        ecReply~Text = response   -- ooDialog: ~setText
      end
      when response~isa(.Directory) then do
        replyText = ""
        do i over response
          replyText = replyText||i||":" response[i]||";  "
        end
        ecReply~Text = replyText   -- ooDialog: ~setText
      end
      otherwise do
        ecReply~Text = .HRSms~noDir1 response .HRSms~noDir2   -- ooDialog: ~setText
      end
    end
    btnClear~Enabled = .true    -- ooDialog: ~enable
    -- say "MessageSender-sendMessage-04: response =" response

    -- Message sent successfully - so now action the checkboxes:
    self~storeEntry(cbTarget, chkStoreTarget)
    self~storeEntry(cbMethod, chkStoreMethod)

    return

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */


  /*----------------------------------------------------------------------------
   storeEntry - Store a new item in either Target or Method comboboxes if a
       		checkbox has been checked.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD storeEntry PRIVATE
    use strict arg comboBox, checkBox
    --say "MessageSender-storeEntry-01."
    if checkBox~Checked then do         -- ooDialog: checkBox~getCheckState = "CHECKED"
      newItem = comboBox~Text
      ix = comboBox~FindStringExact(newItem) + 1	-- case-insensitive find   ooDialog: comboBox~find(newitem): 0 if none
      if ix = 0 then do			-- if item not found, then add it.
        comboBox~Items~Add(newItem)    -- ooDialog: comboBox~add(newItem)
      end
      checkBox~Checked = .false        -- ooDialog: checkBox~uncheck()
    end
    return

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */


  /*----------------------------------------------------------------------------
   clearEntries - Clear user entries and error messages.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD clearEntries
    expose cbTarget cbMethod ecData ecReply stErrorMsg btnClear
    cbTarget~Text = ""   -- ooDialog: ~setText
    cbMethod~Text = ""   -- ooDialog: ~setText
    ecData~Text = ""   -- ooDialog: ~setText
    ecReply~Text = ""   -- ooDialog: ~setText
    stErrorMsg~Text = ""   -- ooDialog: ~setText
    btnClear~Enabled = .false    -- ooDialog: ~disable
  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */


  /*----------------------------------------------------------------------------
   onHelp - Display help.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD onHelp
    cr = .endOfLine
    msg =    .HRSms~help2||cr||.HRSms~help3||cr -
           ||.HRSms~help4||cr||.HRSms~help5||cr -
           ||.HRSms~help6||cr||.HRSms~help7||cr -
           ||.HRSms~help8
    title = .HRSms~help1
    buttons = "OK"
    --ans = MessageDialog(msg, 0, title, "OK", "INFORMATION")
    ans = MessageDialog(msg, self~dlgHandle, title, "OK", "INFORMATION")
  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */


  /*----------------------------------------------------------------------------
    Application Methods
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    parseData - Check the message info provided by the user.

    Required data formats are:
    Target component: "class instance". Allowed are: multiple spaces between
      "class" and "instance"; leading spaces before "class". (Later version may
      provide for class messages).
    Method: a method name - a single string, e.d. "doThat". Any leading or
      trailing spaces are removed.
    Message Parameters: A string, and array, or a directory, as follows:
      String, e.g.: "AB123, Joe Bloggs Inc., 124.50" The first non-white-space
        character must not be "[" or "|", as these characters are used to decide
        whether the data format is string, array or directory.
      Array, e.g.: "| AB123 | Joe Bloggs Inc. | 124.50 "
        The separator between elements is "|". Leading and trailingspaces are
        removed from each array item. Thus the result of the above example would
        be: "AB123|Joe Bloggs Inc.|124.50".
      Directory, e.g.: "[CustNo] AB123 [Name] Joe Bloggs Inc. [Debt] 124.50".
        The indices are in square brackets. Leading and trailing spaces of both
        indices and items are removed.
    Returns:
      If no errors found, this method returns the message data in the directory
      "message". This has four indexes: "class", "instance", "method", "data".
      If format errors are found, a message is displayed, and .false is returned.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD parseData
    expose cbTarget cbMethod ecData stErrorMsg objectMgr eventMgr dragMgr rootDlg
    stErrorMsg~Text = ""   -- ooDialog: ~setText
    --say; say "MessageSender-parseData-01."
    message = .Directory~new

    -- get target component name:
    --target = cbTarget~getText(1)
    target = cbTarget~Text
    --say "MessageSender-parseData-02 target =" target
    parse var target class instance
    targetError = .false
    if class = "" | instance = "" then targetError = .true
    else do
      message["class"]    = class~strip;
      message["instance"] = instance~strip
    end

    -- get Method/Message Name:
    targetMethodError = .false
    targetMethod = cbMethod~Text
    --say "MessageSender-parseData-03 targetMethod =" targetMethod
    if targetMethod~words \= 1 then targetMethodError = .true
    else message["method"] = targetMethod~strip

    -- Special Treatments:
    if message["class"] = "ObjectMgr" & message["instance"] = "The" then do
      -- Only List and ShowModel allowed (at present).
      --say "MessageSender-parseData-04: msg to ObjectMgr."
      method = message["method"]
      method = method~upper
      select
        when method = "LIST" then do
          objectMgr~list
          return "special"
        end
        when method = "SHOWMODEL" then do	-- assume data is a string
          parse value ecData~Text with modelName (.endOfLine)   -- ooDialog: modelName = ecData~getLine(1)
          parse var modelName modelClass " " modelInstance
          modelClass = modelClass~strip; modelInstance = modelInstance~strip
          --say "MessageSender-parseData-05: ViewMgr~parentOffsetDialog = self."
          -- Setup self as "Parent" dialog for offsetting the view to be shown
          --(do it here because other components may have done it previously):
          .local~my.ViewMgr~parentOffsetDlg = self
          -- Now show the model:
          --say "MessageSender-parseData-06: objectMgr~showModel."
          r = objectMgr~showModel(modelClass, modelInstance, rootDlg)
          --say "MessageSender-parseData-07: return =" r
          return "special"
        end
        otherwise do
          --say "MessageSender-parseData-08:" method "is invalid."
          targetMethodError = .true
          --return .false
        end
      end
    end
    if message["class"] = "EventMgr" & message["instance"] = "The" then do
      method = message["method"]
      method = method~upper
      if method = "LIST" then do
        eventMgr~list
        return "special"
      end
      else do
        targetMethodError = .true
        return .false
      end
    end
    if message["class"] = "DragMgr" & message["instance"] = "The" then do
      method = message["method"]
      method = method~upper
      if method = "LIST" then do
        dragMgr~list
        return "special"
      end
      else do
        targetMethodError = .true
        return .false
      end
    end

-- Following Code does not work - left here in case needed in any following exercises.
/*    else do
      --say "MessageSender-parseData-01d."
      if message["class"] = "ViewMgr" & message["instance"] = "The" then do
        method = message["method"]
        method = method~upper
        if method = "SHOWMODEL" then do
          modelName = ecData~Text
          parse var modelName modelClass " " modelInstance
          modelClass = modelClass~strip; modelInstance = modelInstance~strip
          .local~my.ViewMgr~parentOffsetDlg = self
          -- Now show the model:
          r = .local~my.ViewMgr~showModel(modelClass, modelInstance, rootDlg)
          --say "MessageSender-parseData-01e: return =" r
          return "special"
        end
      end
    end
*/

    -- Normal treatments:

    -- get Message Data, and put in an array, directory or string:
    -- Note: ecData~lines returns 1 if control is empty(!).
    msgData = ""
    dataLines = ecData~Lines           -- ooDialog: ecData~lines(), ecData~getLine(i)
    do i=1 to dataLines~items
      msgData = msgData||dataLines[i]
      --say "MessageSender-parseData-02: Data = '"||msgData||"'"
    end
    -- Everything now in a single text string. So now check the data type:
    --say "chars = '"||msgData||"'"
    msgData = strip(msgData)  		-- remove leading & trailing blanks.
    if left(msgData,1) = "" then msgDataType = .false 	-- i.e. no data
    else if left(msgData,1) = "[" then msgDataType = "dir"
      else if left(msgData,1) = "|" then msgDataType = "arr"
        else msgDataType = "str"
    --say "msgDataType =" msgDataType;

    formatError = .false
    Select
      when msgDataType = .false then msgData = ""

      when msgDataType = "dir" then do
        dirMsgData = .Directory~new
        separators = msgData~countStr("["); closers = msgData~countStr("]")
        if separators \= closers then formatError = .true
        if \formatError then do
          do i = 1 to separators
            parse var msgData "[" index "]" msgData
            parse var msgData item "["
            dirMsgData[index] = item~strip
          end
          message["data"] = dirMsgData
        end
      end

      when msgDataType = "arr" then do
        arrMsgData = .Array~new
        separators = msgData~countStr("|")
        --say "No. Separators =" separators
        msgData = msgData~substr(2) 	-- strip leading "|"
        do i=1 to separators
          parse var msgData item "|" msgData
          item = item~strip
          arrMsgData[i] = item
          --say "item =" "'"||item||"'"
        end
        message["data"] = arrMsgData
      end

      otherwise do 		-- msgDataType = "str"
      	message["data"] = msgData
      end
    end -- Select

    -- Check for errors:
    errors = 0
    if targetError then errors += 1; if targetMethodError then errors += 1
    if formatError then errors += 1
    if errors = 1 then errortext = .HRSms~prefix1
    if errors > 1 then errortext = .HRSms~prefix2
    if errors > 0 then do
      if targetError then errorText = errorText||.HRSms~badTarget
      if targetMethodError then errorText = errorText||" "||.HRSms~badMethod
      if formatError then errorText = errorText||" "||.HRSms~badData
      stErrorMsg~Text = errorText   -- ooDialog: ~setText
      return .false
    end

    return message
  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

  /*----------------------------------------------------------------------------
    autoRun - (.NET version) unattended: a few messages, as a user would send
              them: the ObjectMgr's list, a Person's query, a bad target;
              help (F1); Clear; then the dialog closed.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD autoRun UNGUARDED
    expose cbTarget cbMethod ecData ecReply stErrorMsg chkStoreTarget
    do msg over .array~of("ObjectMgr The|list|", "PersonModel PA150|query|", "NoSuchModel X1|query|")
      parse var msg target "|" method "|" data
      cbTarget~Text = target; cbMethod~Text = method; ecData~Text = data
      chkStoreTarget~Checked = .true
      self~newPushButton("IDC_MS_SEND")~PerformClick
      say "(auto) sent" target"~"method": reply" ecReply~Text"; message" stErrorMsg~Text
    end
    say "(auto) targets stored:" cbTarget~Items~Count
    self~onHelp
    self~newPushButton("IDC_MS_CLEAR")~PerformClick
    self~cancel



  /*----------------------------------------------------------------------------

    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD getObjectRef
    expose objectMgr
    use arg target
    parse var target class "-" instance
    ref = objectMgr~getComponentRef(class, instance)

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */


/*============================================================================*/


/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  sendMsg - a 'Send Message' Routine.				  v00-01 08May12
  --------
   This routine sends the message to the specified component instance.
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::ROUTINE sendMsg
  use arg targetObject, targetMethod, data
  --say "MessageSender-sendMsg-01: targetObject targetMethod data =" targetObject targetMethod data
  SIGNAL ON SYNTAX NAME catchIt1
  SIGNAL ON NOMETHOD NAME catchIt2
  msg = .Message~new(targetObject, targetMethod, i, data)
  response = msg~send
  --say "MessageSender-sendMsg-02: response =" response
  return response
  catchIt1: say "MessageSender-sendMsg-03: CatchIt1 - Syntax."
  SIGNAL OFF SYNTAX
  return "SendMsg - Syntax Error"
  catchIt2: say "MessageSender-sendMsg-04: CatchIt2 - NoMethod."
  SIGNAL OFF NOMETHOD
  return "SendMsg - No Method"
/*============================================================================*/


/*//////////////////////////////////////////////////////////////////////////////
  ==============================================================================
  Human-Readable Strings (HRSms)				  v01-00 05May12
  --------
   This class provides constant character strings for user-visible messages.
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS HRSms PRIVATE
  ::CONSTANT prefix1      "*** Error: "
  ::CONSTANT prefix2      "*** Errors: "
  ::CONSTANT badTarget    "Invalid class or Instance name."
  ::CONSTANT badMethod    "Invalid method."
  ::CONSTANT badData      "Invalid data format."
  ::CONSTANT noObject     "Target component not found."
  ::CONSTANT noTgtMethod  "No such method in target component."
  ::CONSTANT noResponse   "Note: No response received from target object."
  ::CONSTANT rc           "Return Code:"
  ::CONSTANT noObjectMgr  "The Object Manager was not found. Cannot work without it."
  ::CONSTANT noDir1       "Reply is a"
  ::CONSTANT noDir2       "- cannot display with this version."
  ::CONSTANT help1        "Formats for data parameters:"
  ::CONSTANT help2        "Target: Class Instance - e.g. 'CustomerModel CU0003'"
  ::CONSTANT help3        "Method: method name - e.g. 'query'"
  ::CONSTANT help4        "Data: Formats for message data are:"
  ::CONSTANT help5        "  Directory: '[aaa] [bbb] [c cc]'"
  ::CONSTANT help6        "  Array:     '|aaa|bbb|c cc'"
  ::CONSTANT help7        "  String:    'aaa bbb'"
  ::CONSTANT help8        "Note: a 'saved' target or method is not saved over a close."
  ::CONSTANT helpMsg      "Press F1 for help on allowable data formats."
/*============================================================================*/



