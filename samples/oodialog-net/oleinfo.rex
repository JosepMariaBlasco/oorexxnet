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
/****************************************************************************/
/* Name: OLEINFO.REX                                                        */
/* Type: Open Object Rexx Script using ooDialog                             */
/* Resource: OLEINFO.RC                                                     */
/*                                                                          */
/* Description:                                                             */
/* A "small" browser for OLE objects                                        */
/*                                                                          */
/****************************************************************************/

/* (.NET version of ooDialog's oleinfo\oleinfo.rex, on Windows Forms through
   oodnet.cls: OLEINFO.rc's dialogs are Oleinfo_MainDialog,
   Oleinfo_RegistryDialog, Oleinfo_ResultDialog and Oleinfo_HelpDialog, from
   oleinforc.cls (by hand there: the .rc gives a group box the Exit
   button's id). An OLE object is a COM object through the bridge:
   .OLEObject~new(progID, "NOEVENTS") is .net~createObject(progID), and its
   GetKnownMethods / GetKnownEvents are .net~getKnownMethods(o) /
   .net~getKnownEvents(o), the same stems. A method is invoked with its
   arguments as a Rexx Array (.Message's send) rather than by INTERPRET of
   one string, so that an out parameter can be a .NetRef: what it holds after
   the call is what GetOutParameters gave. Each argument is still the Rexx
   expression typed in, evaluated. The registry's ProgIDs are .NET's
   Microsoft.Win32.Registry (ClassesRoot\CLSID's subkeys: their
   VersionIndependentProgID or ProgID). The list view (LVS_SORTASCENDING) is
   sorted by .NET, and each item keeps in its Tag the index of its member in
   the stems: the original's indexStem., which followed where each name went
   in the sorted list, is not needed. The icons are the original's
   icons.bmp (resources\oleinfo-icons.bmp), the help its help.txt
   (resources\oleinfo-help.txt). Enter in the ProgID's combo box creates
   the object, as the original's IDOK did. RxMessageBox is
   messageDialog. Unattended (argument "auto"): Scripting.FileSystemObject
   (on every Windows), a method and a property shown and invoked, the
   registry's ProgIDs, and the help.) */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

/* start the main dialog */
MainDialog = .OLEINFO~new
if MainDialog~InitCode = 0 then do
  rc = MainDialog~Execute("SHOWTOP")
end

exit   /* leave program */

::requires "oleinforc.cls"    /* ooDialog: ::requires "ooDialog.cls", "WINSYSTM.CLS" */

/*****************************************/
/* This routine creates the OLE object   */
/* the code has been placed outside the  */
/* object code to safely catch any error */
/* during creation of the OLE object     */
/*****************************************/
::routine createObject
  use arg target, name
  target~currentObject=.nil
  signal on syntax name returnToObject
  target~currentObject=.net~createObject(name)          -- ooDialog: .OLEObject~new(name,"NOEVENTS")
  signal on syntax
  return
returnToObject:
  signal on syntax
  call RxMessageBox "Error" rc":" errortext(rc)||'0a'x||condition('o')~message, "Error", "OK", "EXCLAMATION"
  return

/*******************************************/
/* This routine calls a method of the OLE  */
/* object. The code has been placed        */
/* outside the object code to safely catch */
/* any error during the invocation         */
/*******************************************/
::routine callMethod
  use arg target, method, args, self                    -- (.NET version) the arguments as an Array
  resultOfCall = ""
  signal on syntax name callFailed
  m = .Message~new(target, method, "A", args)            -- ooDialog: interpret "resultOfCall = target~"method
  m~send
  if m~hasResult then resultOfCall = m~result
  signal on syntax
  return resultOfCall
callFailed:
  call RxMessageBox "Error" rc":" errortext(rc)||'0a'x||condition('o')~message, "Error", "OK", "EXCLAMATION"
  self~lastError=rc
  signal on syntax
  return resultOfCall

/* (.NET version) ooDialog's RxMessageBox(text, title, buttons, icon) */
::routine RxMessageBox
  use arg text, title, buttons = "OK", icon = ""
  return messageDialog(text, , title, buttons, icon)


/**************************/
/* Main Dialog of OLEINFO */
/**************************/
::class OLEINFO subclass Oleinfo_MainDialog

::method Init
  expose cache
  forward class (super) continue /* call parent constructor */
  InitRet = Result

  cache = .nil
  /* load main dialog: (.NET version) the superclass, from oleinforc.cls */

  /* Connect dialog control items to class methods */
  self~connectButtonEvent(200, "CLICKED", "MyOk")
  self~connectButtonEvent(103, "CLICKED", "Lookup")

  self~connectComboBoxEvent(100,"SELENDOK","Ok")        -- (.NET version: the user's choices, as ooDialog's SELCHANGE)
  self~connectListViewEvent(104,"ACTIVATE","selectDoubleClick")
  self~connectListViewEvent(104,"SELECTCHANGED","selectionChange")   -- ooDialog: CHANGED

  self~connectButtonEvent(107, "CLICKED", "selectionChange")
  self~connectButtonEvent(108, "CLICKED", "selectionChange")
  self~connectButtonEvent(109, "CLICKED", "selectionChange")

  self~currentObject = .nil
  self~currentObjectName = ""
  return InitRet

::method InitDialog
  lv = self~newListView(104)
  lv~Sorting = "Ascending"                               -- (.NET version) the .rc's LVS_SORTASCENDING
  lv~SmallImageList = self~getImages                     -- ooDialog: ~setImageList(self~getImages, SMALL)
  cb = self~newComboBox(100)
  default = .array~of("InternetExplorer.Application","Excel.Application","Freelance.Application",,
                      "Notes.NotesSession","Lotus123.Workbook","Outlook.Application",,
                      "Word.Application","WordPro.Application","Access.Application")
  do i over default
    cb~Items~Add(i)                                      -- ooDialog: cb~add(i)
  end
  cb~KeyDown += .net~handler(self, "COMBOKEY")           -- (.NET version) Enter: Ok, as ooDialog's IDOK

::method comboKey unguarded            -- (.NET version) Enter in the combo box
  use arg sender, e
  if e~KeyCode~string == "Return" then do
    e~Handled = .true
    e~SuppressKeyPress = .true
    self~Ok
  end

  /* Method Ok will be called if enter is pressed in dialog */
::method Ok
  cb = self~newComboBox(100)
  if cb \= .nil then do
    OLEID = cb~Text           /* get ProgID or ClassID of OLE Object */   -- ooDialog: cb~Title
    if OLEID \= self~currentObjectName then do
      call createObject self, OLEID
      if self~currentObject \= .nil then do
        self~currentObjectName=OLEID
        self~updateView
      end
      else do
        call RxMessageBox "Could not create OLE object", "Error", "OK", "EXCLAMATION"
        cb~Text = self~currentObjectName
      end
    end
  end
  return 0  /* don't leave dialog, this is done via method MyOk */

  /* Method MyOk is connected to item 200 */
::method MyOk
  return self~OK:super  /* make sure self~Validate is called and self~InitCode is set to 1 */

  /* Method Help is connected to item 9 */
::method Help
  self~Help:super
  file = .stream~new(self~srcDir"resources\oleinfo-help.txt")   -- ooDialog: .application~srcDir"help.txt"
  text = file~charin(1,file~chars)
  file~close
  temp = .HelpDialog~new                                 -- ooDialog: .HelpDialog~new(data.), data.500 the text
  temp~DATA500 = text~changeStr('0a'x, '0d0a'x)~changeStr('0d0d0a'x, '0d0a'x)   -- (a .NET TextBox: CR LF)
  if temp~InitCode = 0 then do
    rc = temp~execute("SHOWTOP")
  end

  /* Method Lookup is connected to item 103 */
::method Lookup
  expose cache

  self~form~UseWaitCursor = .true                        -- ooDialog: self~Cursor_Wait

  progressBar = self~newProgressBar(110)
  if cache == .nil then do
    cache = .list~new
    registry = .net~Microsoft~Win32~Registry             -- ooDialog: registry = .WindowsRegistry~new
    handle = registry~ClassesRoot~OpenSubKey("CLSID")    -- ooDialog: registry~open(registry~classes_root, "CLSID", "READ")
    if handle == .nil then return     /* no access to registry? return */

    clslist = handle~GetSubKeyNames                      -- ooDialog: registry~query, registry~list(handle,info.)

    if progressBar \= .nil then do
      progressBar~Step = 1                               -- ooDialog: SetStep(1), SetRange(0, clslist.subkeys)
      progressBar~Minimum = 0
      progressBar~Maximum = clslist~items
    end

    do name over clslist
      temphandle = handle~OpenSubKey(name)
      if temphandle \= .nil then do
        value = self~getProgID(temphandle,progressBar)
        temphandle~Close
        if value \= .nil then cache~insert(value)
      end
    end
    handle~Close
  end

  if progressBar \= .nil then progressBar~Value = 0      -- ooDialog: SetPos(0)
  self~form~UseWaitCursor = .false                       -- ooDialog: self~Cursor_Arrow


  picked = ""
  temp = .RegistryDialog~new(,cache)
  if temp~InitCode = 0 then do
    rc = temp~execute("SHOWTOP")
    if rc =1 then do
      combo = self~newComboBox(100)
      combo~Text = temp~data200
      picked = combo~Text
      self~ok
    end
  end
  cb = self~newComboBox(100)
  if cb \= .nil then do
    cb~BeginUpdate
    cb~Items~Clear                                       -- ooDialog: cb~DeleteAll
    do i over cache
      cb~Items~Add(i)
    end
    cb~EndUpdate
    if picked \== "" then cb~Text = picked
  end

  /* extract ProgID from registry */
::method getProgID
  use arg handle, progressBar
  res = .nil

  /* try to get a version independent ProgID first */
  temphandle = handle~OpenSubKey("VersionIndependentProgID")

  if progressBar \= .nil then progressBar~PerformStep

  if temphandle \= .nil then do
    res = temphandle~GetValue("")                        -- ooDialog: registry~listvalues(temphandle,info.); info.1.data
    temphandle~Close
  end
  else do
    /* this failed, so maybe there's a "normal" ProgID? */
    temphandle = handle~OpenSubKey("ProgID")

    if temphandle \= .nil then do
      res = temphandle~GetValue("")
      temphandle~Close
    end
  end

  return res


::method currentObject ATTRIBUTE                    /* store the current object */
::method currentObjectName ATTRIBUTE                /* store object's name      */

  /* update the list of methods and events */
::method updateView
  expose methods. events.
  lc = self~newListView(104)
  if lc \= .nil then do
    methods. = .net~getKnownMethods(self~currentObject)  /* retrieve info on methods   */   -- ooDialog: self~currentObject~GetKnownMethods
    if methods. = .nil then do
      temp = RxMessageBox("OLE Object did not return any information on known methods.","Information","OK","INFORMATION")
      lc~Items~Clear                                /* remove all items from list */
      return
    end
    events. = .net~getKnownEvents(self~currentObject)    /* retrieve info on events    */
    if events. = .nil then events.0 = 0

    lc~Items~Clear                                  /* remove all items from list */
    if var("methods.!LIBNAME") = 1 then
      self~newEdit(101)~Text = methods.!LIBNAME
    else
      self~newEdit(101)~Text = "unavailable"
    if var("methods.!LIBDOC") = 1 then
      self~newEdit(102)~Text = methods.!LIBDOC
    else
      self~newEdit(102)~Text = "unavailable"

    self~form~UseWaitCursor = .true                 -- ooDialog: self~Cursor_Wait
    pbc = self~newProgressBar(110)
    if pbc \= .nil then do
      pbc~Step = 1
      pbc~Minimum = 0
      pbc~Maximum = methods.0 + events.0
    end

    lc~BeginUpdate
    do i = 1 to methods.0 + events.0
      if i <= methods.0 then do
        /* add method name to list box */
        if methods.i.!INVKIND \= 4 then
          item = lc~Items~Add(methods.i.!NAME, (methods.i.!INVKIND)%2)
        else                                     /* this is a property put, symbolize with "=" */
          item = lc~Items~Add(methods.i.!NAME||"=",2)
        end
      else do
        k = i - methods.0
        item = lc~Items~Add(events.k.!NAME, 3)
      end
      item~Tag = i                                  -- (.NET version) the member's index: the original's indexStem.
      if pbc \= .nil then pbc~PerformStep
    end
    lc~EndUpdate
    self~form~UseWaitCursor = .false                -- ooDialog: self~Cursor_Arrow
    if pbc \= .nil then pbc~Value = 0
  end


  /* (.NET version) the stems' index of the selected member, 0 if none */
::method selectedMember private
  listbox=self~newListView(104)
  if listbox~SelectedItems~Count = 0 then return 0
  return listbox~SelectedItems[0]~Tag

  /* displays information on the selected method */
::method selectionChange
  expose methods. events.

  i = self~selectedMember                           -- ooDialog: j = 1 + listbox~Selected; i = indexStem.j
  if i < 1 then return                              /* return if nothing was selected */

  types = self~newCheckBox(107)~Checked             -- ooDialog: self~getCheckBoxData(107)
  flags = self~newCheckBox(108)~Checked

  if i > methods.0 then do
    workstem. = events.
    i = i - methods.0
    infostring = ""
  end
  else do
    workstem. = methods.
    memberID = self~newCheckBox(109)~Checked
    /* show member ID? */
    if memberID \= 0 then
      infostring = "['"||workstem.i.!MEMID||"'x] "
    else
      infostring = ""
    /* show return type? */
    if types \= 0 then
      infostring = infostring||workstem.i.!RETTYPE||" "
  end

  if methods.i.!INVKIND = 4 then                      /* property put */
    infostring = infostring||workstem.i.!NAME||"="
  else                                                /* normal method or property get */
  do
    /* build method signature with name(...) */
    infostring = infostring||workstem.i.!NAME
    do j = 1 to workstem.i.!PARAMS.0
      if j = 1 then infostring = infostring||"("
      /* show flags? */
      if flags \= 0 then
        infostring = infostring||workstem.i.!PARAMS.j.!FLAGS||" "
      /* show types? */
      if types \= 0 then
        infostring = infostring||workstem.i.!PARAMS.j.!TYPE||" "
      /* show name of argument */
      infostring = infostring||workstem.i.!PARAMS.j.!NAME
      if j < workstem.i.!PARAMS.0 then
        infostring = infostring||", "
      else infostring = infostring||")"
    end
  end

  /* set string to dialog */
  signature = self~newEdit(105)
  if signature \= .nil then
    signature~Text = infostring
  desc = self~newEdit(106)
  /* show documentation if available */
  if desc \= .nil then do
    interpret 'exists = var("workstem.'i'.!DOC")'
    if exists = 1 then
      desc~Text = workstem.i.!DOC
    else
      desc~Text="unavailable"
  end

  /* invoke method */
::method selectDoubleClick
  expose methods.

  i = self~selectedMember                           -- ooDialog: j = 1 + listbox~Selected; i = indexStem.j
  if i < 1 then return

  if i > methods.0 then do
    call RxMessageBox "This is an event!"||'0a'x||"Build a subclass of OLEObject and add a method with",
                      "this name if you wish REXX to call it when this event occurs.", "Information", "OK", "EXCLAMATION"
    return
  end

  params.0 = methods.i.!PARAMS.0
  do j = 1 to params.0
    params.j.!NAME = methods.i.!PARAMS.j.!NAME
    params.j.!FLAGS = methods.i.!PARAMS.j.!FLAGS
    params.j.!TYPE = methods.i.!PARAMS.j.!TYPE
  end

  aDialog=.invokeDialog~new(,params.)
  aDialog~create(100,100,200,26+13*params.0,"Method invocation:" methods.i.!NAME)
  rc = aDialog~execute("showtop")
  if rc = 1 then do
    execString = methods.i.!name
    usesOutParms = .FALSE
    self~LastError = 0
    args = .array~new                               -- (.NET version) the arguments, evaluated
    refs = .array~new                               --   and the out parameters' .NetRefs
    /* method call? */
    if methods.i.!INVKIND = 1 then do
      do k = 1 to params.0
        interpret "value = aDialog~param"k
        signal on syntax name badArgument
        interpret "value =" value                   -- (.NET version) the expression typed in
        signal off syntax
        if params.k.!FLAGS~pos("out") > 0 then do
          usesOutParms = .TRUE
          value = .net~ref(value)                   -- (.NET version) its new value after the call
          refs~append(value)
        end
        args~append(value)
      end
      resultOfCall = callMethod(self~currentObject, execstring, args, self)
    end
    /* property put? */
    if methods.i.!INVKIND = 4 then do
      value = aDialog~param1                 /* can only have one argument */
      interpret "value =" value
      resultOfCall = callMethod(self~currentObject, execString"=", .array~of(value), self)   -- ooDialog: interpret "self~currentObject~"execString "=" value
      resultOfCall = ""
    end
    /* property get? */
    if methods.i.!INVKIND = 2 then do
      resultOfCall = callMethod(self~currentObject, execString, .array~new, self)   -- ooDialog: interpret "resultOfCall = self~currentObject~"execString
    end

    if usesOutParms = .TRUE then do
      outp = .array~new                             -- ooDialog: self~currentObject~GetOutParameters
      do r over refs
        outp~append(r~value)
      end
    end
    else
      outp = .nil

    if self~LastError \= 0 then call RxMessageBox ERRORTEXT(self~LastError), "Error", "OK", "EXCLAMATION"
    else do
      temp = .ResultDialog~new(resultOfCall,outp)
      if temp~initcode = 0 then do
        temp~execute("showtop")
        /* if useOLEobject attribute is filled in, change browser to this object */
        if temp~useoleobject \= .nil then do
           self~currentObject = temp~useOLEobject
           self~currentObjectName = "??? (from execution)"
           self~newComboBox(100)~Text = self~currentObjectName
           self~updateView
        end
      end
    end

  end
  return
badArgument:                                        -- (.NET version) an argument that is no Rexx expression
  call RxMessageBox "Argument" k":" condition("O")~message, "Error", "OK", "EXCLAMATION"
  return

::method getImages private
  -- ooDialog: .Image~getImage(srcDir"icons.bmp"), .ImageList~create(.Size~new(16, 12), COLOR4, 6, 0), imageList~add(image)
  imageList = .net~System~Windows~Forms~ImageList~new
  imageList~ImageSize = .net~System~Drawing~Size~new(16, 12)
  imageList~ColorDepth = "Depth4Bit"
  file = self~srcDir"resources\oleinfo-icons.bmp"
  if \SysFileExists(file) then return .nil
  imageList~Images~AddStrip(.net~System~Drawing~Image~FromFile(file))
  return imageList

::method srcDir                        -- (.NET version) this program's folder: ooDialog's .application~srcDir
  return filespec("location", .context~package~name)

::method LastError ATTRIBUTE

::method autoRun unguarded             -- (.NET version) unattended: what a user would try
  cb = self~newComboBox(100)
  cb~Text = "Scripting.FileSystemObject"
  self~Ok
  lv = self~newListView(104)
  say "(auto)" self~currentObjectName":" lv~Items~Count "members; library" self~newEdit(101)~Text
  do name over .array~of("BuildPath", "Drives")       -- a method, then a property
    do k = 0 to lv~Items~Count - 1
      if lv~Items[k]~Text == name then leave
    end
    lv~Items[k]~Selected = .true
    self~newCheckBox(107)~Checked = .true
    self~selectionChange
    say "(auto)" name":" self~newEdit(105)~Text
    self~selectDoubleClick                  -- the invocation's dialog, then the result's (they run by themselves)
  end
  self~Lookup                               -- the registry's ProgIDs (the dialog runs by itself)
  say "(auto) ProgIDs in the registry:" self~newComboBox(100)~Items~Count
  self~Help
  self~MyOk



/*************************************/
/* Dialog for invoking an OLE method */
/*************************************/
::CLASS invokeDialog SUBCLASS NetDialog            -- ooDialog: SUBCLASS UserDialog

::METHOD resultObject ATTRIBUTE     /* takes the result of the invocation */

::METHOD init
  expose params.
  use arg initstem., params.
  self~init:super

::METHOD DefineDialog
  expose params.

  self~DefineDialog:super

  do i = 1 to params.0
    self~createEdit(300+i, 64, -5+(13*i), 128, 11, "AUTOSCROLLH", "Param"i)
    self~createStaticText(-1, 8, -5+(13*i), 56, 11, , params.i.!NAME)
  end
  -- ooDialog: self~createOkCancelRightBottom (the dialog 200 wide, 26+13*n high)
  bottom = 26 + 13 * params.0 - 19
  self~createPushButton(IDOK, 200 - 5 - 50 - 4 - 50, bottom, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 200 - 5 - 50, bottom, 50, 14, "", "Cancel")

::METHOD InitDialog
  expose params.
  self~resultObject = .nil
  do i = 1 to params.0
    /* plain out parameters can not be edited */
    if params.i.!FLAGS = "[out]" then do
      interpret "self~Param"i"='.NIL'"
      self~newEdit(300+i)~Enabled = .false            -- ooDialog: ~disable
    end
    /* set .true if BOOL expected */
    if params.i.!TYPE = "VT_BOOL" then interpret "self~param"i"='.TRUE'"
    /* set empty string if string expected */
    if params.i.!TYPE = "VT_BSTR" then interpret "self~param"i"='""""'"
  end


::METHOD ok
  return self~OK:super  /* make sure self~Validate is called and self~InitCode is set to 1 */

::method autoRun unguarded             -- (.NET version) unattended: arguments a user might type, then OK
  expose params.
  do i = 1 to params.0
    if params.i.!TYPE = "VT_BSTR" then interpret "self~Param"i"='""part'i'""'"
  end
  self~ok




/*******************************************************/
/* Dialog that shows the result of a method invocation */
/*******************************************************/
::class ResultDialog subclass Oleinfo_ResultDialog

::method Init
  expose outarray
  use arg rvalue, outarray
  InitRet = self~init:super
  /* (.NET version) its .rc dialog: the superclass, from oleinforc.cls */

  self~data400=rvalue~string
  if rvalue~isA(.NetObject) then self~useOLEobject = rvalue   -- ooDialog: if self~data400 = "an OLEOBJECT"
  else self~useOLEobject = .nil
  return InitRet

::method InitDialog
  expose outarray

  lc = self~newListBox(401)

  if outarray \= .nil then do
    if lc \= .nil then do
      i = 1
      do j over outarray
        lc~Items~Add(i||'09'x||j~string)                -- ooDialog: lc~add
        i = i + 1
      end
    end
  end
  else
    if lc \= .nil then do; lc~Items~Add("object did not return out parameters")
  end

::METHOD ok
  if self~useOLEobject \= .nil then do
    keep = RxMessageBox("An OLE object was returned from the method invocation. Do you want to use it as the active object?","Question","OKCANCEL","QUESTION")
    if keep \= 1 then self~useOLEobject = .nil
  end
  return self~ok:super

::method useOLEobject ATTRIBUTE

::method autoRun unguarded             -- (.NET version) unattended: the result, then OK
  say "(auto) result:" self~data400
  self~ok






/********************************************************/
/* Dialog that shows all ProgIDs obtained from Registry */
/********************************************************/
::class RegistryDialog subclass Oleinfo_RegistryDialog

::method Init
  expose cache
  use arg stem., cache
  forward class (super) continue /* call parent constructor */
  InitRet = Result
  /* (.NET version) its .rc dialog: the superclass, from oleinforc.cls */

  self~connectListBoxEvent(200, "DBLCLK", "selectDoubleClick")
  self~connectButtonEvent(201, "CLICKED", "search")

  return InitRet

::method GetCache
  expose cache
  return cache

::method InitDialog
  expose cache
  lc = self~newListBox(200)
  if lc \= .nil then do
    lc~BeginUpdate
    do item over cache
      lc~Items~Add(item)                                 -- ooDialog: lc~add(item)
    end
    lc~EndUpdate
  end

::method OK
  res = self~OK:super
  return res

  /* double clicking in the list closes this dialog window */
::method selectDoubleClick
  self~OK  /* make sure self~Validate is called and self~InitCode is set to 1 */

::method search
  dlg = .InputBox~new("String:", "String search", "", 150)
  value = dlg~Execute
  drop dlg

  lb = self~newListBox(200)
  startindex = lb~SelectedIndex                          -- ooDialog: lb~selectedindex (from 1; .NET from 0)
  found = lb~FindString(value, startindex)               -- ooDialog: lb~find(value,startindex,0)
  if found >= 0 then lb~SelectedIndex = found            -- ooDialog: lb~selectindex(...)

::method autoRun unguarded             -- (.NET version) unattended: a search, then OK with what it found
  lb = self~newListBox(200)
  found = lb~FindStringExact("Scripting.FileSystemObject")
  if found >= 0 then lb~SelectedIndex = found
  say "(auto) registry: found Scripting.FileSystemObject:" (found >= 0)
  self~ok



/******************************/
/* Dialog that shows the help */
/******************************/
::class HelpDialog subclass Oleinfo_HelpDialog

::method Init
  forward class (super) continue /* call parent constructor */
  InitRet = Result
  /* (.NET version) its .rc dialog: the superclass, from oleinforc.cls */

  return InitRet

::method autoRun unguarded             -- (.NET version) unattended: the help's first line, then OK
  say "(auto) help:" self~DATA500~left(40)~strip
  self~ok
