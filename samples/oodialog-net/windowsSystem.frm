/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2008-2014 Rexx Language Association. All rights reserved.    */
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
 *   Name: windowsSystem.frm
 *   Type: Framework
 *
 *   Description:  A collection of public routines and classes to help work with
 *                 the winsystm.cls package.
 *
 *                 This is an example of how to extract common function into a
 *                 package, and the use the package to help in writting similar
 *                 programs.  A number of the sample programs that use
 *                 winsystm.cls make use of this framework.
 *
 * (.NET version of ooDialog's winsystem\windowsSystem.frm: winsystm.cls's
 * WindowsManager, WindowObject and MenuObject become .NET's UI Automation
 * (System.Windows.Automation), the API .NET has to work with other
 * programs' windows. A window, or anything in it (a button, an edit field, a
 * menu item), is an AutomationElement:
 *
 *   winsystm.cls                         UI Automation
 *   ------------------------------------------------------------------------
 *   WindowsManager~desktopWindow         AutomationElement~RootElement
 *   ~find(title)                         root~FindFirst(TreeScope Children,
 *                                          a PropertyCondition on NameProperty)
 *   ~foregroundWindow                    AutomationElement~FocusedElement
 *   wnd~firstChild, ~next                TreeWalker~ControlViewWalker's
 *                                          GetFirstChild, GetNextSibling
 *   wnd~title, ~wClass, ~id, ~hwnd       ~Current's Name, ClassName,
 *                                          AutomationId, NativeWindowHandle
 *   wnd~coordinates                      ~Current~BoundingRectangle
 *   wnd~minimize, ~maximize, ~restore    WindowPattern's SetWindowVisualState
 *   wnd~resize(w, h)                     TransformPattern's Resize
 *   wnd~sendSysCommand("Close")          WindowPattern's Close
 *   wnd~sendText, ~sendKey               SetFocus, then .NET's SendKeys
 *   wnd~menu, MenuObject's items         the window's MenuBar element; its
 *                                          menus are read by opening them
 *                                          (ExpandCollapsePattern), as a
 *                                          user would
 *   wnd~processMenuCommand(menu, item)   menuCommand(wnd, menu, item): the
 *                                          item's InvokePattern
 *   wnd~sendCommand(id), ~pushButton     the button's InvokePattern
 *
 * A window's handle, class and id exist only for what Windows draws as
 * windows: much of today's programs (the Windows 11 Notepad and Calculator)
 * draw their controls themselves, and UI Automation still shows them, with
 * their names, AutomationIds and rectangles. What UI Automation cannot do,
 * because a user cannot: disable another program's window, hide one of its
 * controls, change its title.
 *
 * The dialogs of winSystemDlgs.rc are the classes of winSystemDlgsrc.cls
 * (rc2oodnet.rex -cls); WindowTreeDlg and the dialog of MenuDetailer
 * subclass them. MenuDetailer is not a dialog itself here: its display()
 * shows one, a MenuTreeDlg.
 */

::requires "winSystemDlgsrc.cls"                       -- (oodnet.cls, net.cls)

/** findTheWindow()
 * Finds a top-level window currently open on the system, by its title, as an
 * AutomationElement.
 *
 * When an application is started up, it takes some finite amount of time before
 * the window for the application is created by the operating system.  The
 * window can not be found until it has been created.  This function loops a
 * number of times trying to find the window, then eventually gives up.
 *
 * How long to wait for to find the window before giving up can be adjusted by
 * the caller.
 *
 * @param   title  The title of the window being sought.
 * @param   loops  Optional.  The number of loops to perform looking for the
 *                 window.  The default is 20.
 * @param   pause  Optional.  The time to sleep during each loop.  The default
 *                 is .2 of a second.
 *
 * @return         An AutomationElement representing the desired window on
 *                 success.  If the function fails, .nil is returned.
 *
 * @note           To find a window, you must use its exact title.
 */
::routine findTheWindow public
  use strict arg title, loops = 20, pause = .2

  A = .net~System~Windows~Automation
  AE = A~AutomationElement
  byTitle = A~PropertyCondition~new(AE~NameProperty, title)   -- ooDialog: windowMgr~find(title)

  do loops
    j = SysSleep(pause)
    wnd = AE~RootElement~FindFirst(A~TreeScope~Children, byTitle)
    if wnd \== .nil then leave
  end

return wnd

/** sendTextWithPause()
 * Sends text to a window and pauses slightly before returning.
 *
 * @param  wnd   The element (a window, an edit field) to send the text to.
 * @param  text  The text to send.
 *
 * @return  The return from SysSleep()
 *
 * @note  The text is typed: the element gets the focus (its window comes to
 *        the foreground), then .NET's SendKeys sends the keys.  The pause
 *        mimics more closely a user entering the data on a keyboard.  Anyone
 *        familiar with Expect, probably knows that Expect provides a similiar
 *        function.
 */
::routine sendTextWithPause public
  use strict arg wnd, text
  call sendText wnd, text
return SysSleep(.01)

/** sendKeyWithPause()
 * Sends a key press to a window and pauses slightly before returning.
 *
 * @param  wnd   The element to send the key press to.
 * @param  key   The key press to send: winsystm.cls's names (RETURN, SPACE,
 *               TAB, ESCAPE, BACK, DELETE, UP, DOWN, LEFT, RIGHT, HOME, END,
 *               F1 to F12...)
 *
 * @return  The return from SysSleep()
 *
 * @see  sendTextWithPause()
 */
::routine sendKeyWithPause public
  use strict arg wnd, key
  call sendKey wnd, key
return SysSleep(.01)

/** sendText()
 * (.NET version) winsystm.cls's sendText: the text typed into an element
 * (SendKeys' special characters escaped).
 */
::routine sendText public
  use strict arg wnd, text
  call focusOn wnd
  escaped = .mutableBuffer~new
  do i = 1 to text~length
    c = text~subchar(i)
    if "+^%~(){}[]"~pos(c) > 0 then escaped~append("{" || c || "}")
    else escaped~append(c)
  end
  .net~System~Windows~Forms~SendKeys~SendWait(escaped~string)
  return 0

/** sendKey()
 * (.NET version) winsystm.cls's sendKey: a key, by its virtual-key name, typed
 * into an element.
 */
::routine sendKey public
  use strict arg wnd, key
  call focusOn wnd
  k = key~upper
  select
    when k == "RETURN" | k == "ENTER" then keys = "{ENTER}"
    when k == "SPACE" then keys = " "
    when k == "ESCAPE" then keys = "{ESC}"
    when k == "BACK" then keys = "{BACKSPACE}"
    when k == "PRIOR" then keys = "{PGUP}"
    when k == "NEXT" then keys = "{PGDN}"
    when "TAB DELETE INSERT UP DOWN LEFT RIGHT HOME END"~wordPos(k) > 0 then keys = "{" || k || "}"
    when k~left(1) == "F", k~substr(2)~dataType("W") then keys = "{" || k || "}"
    otherwise keys = key
  end
  .net~System~Windows~Forms~SendKeys~SendWait(keys)
  return 0

/* (.NET version) The keyboard focus on an element, unless it has it: its
   window comes to the foreground (winsystm.cls's toForeground). A short
   pause lets the focus settle before keys are typed. An element that does
   not take the focus (a classic Calculator's window, a console window)
   stays as it is. */
::routine focusOn public
  use strict arg wnd
  A = .net~System~Windows~Automation
  focused = A~AutomationElement~FocusedElement
  if focused \== .nil then if A~Automation~Compare(focused, wnd) then return
  signal on syntax                     -- (an element that cannot take the focus: a console window)
  wnd~SetFocus
  j = SysSleep(.2)
syntax:
  return

/** printChildren()
 * Given a window, enumerates all descendent elements of that window and
 * prints the results to the screen.
 *
 * @param wnd     The parent element.
 * @param indent  When printing to the console, the amount of indentation.
 *
 * @return  True if this function recursed, otherwise false.
 */
::routine printChildren public
  use strict arg wnd, indent

  c = wnd~Current
  line = indent || c~NativeWindowHandle ":" c~AutomationId ":" c~ClassName ":" c~Name~left(15) ":" coordinates(wnd)

  walker = .net~System~Windows~Automation~TreeWalker~ControlViewWalker   -- ooDialog: childs. = wnd~enumerateChildren
  childs = .array~new
  child = walker~GetFirstChild(wnd)
  do while child \== .nil
    childs~append(child)
    child = walker~GetNextSibling(child)
  end

  select
    when childs~items == 0 then do
      line = line "no children"
      say line
      return .false
    end

    when childs~items == 1 then do
      line = line "1 child"
    end

    otherwise do
      line = line childs~items "children"
    end
  end
  -- End select

  say line

  indent = indent || "  "

  do childWnd over childs
    ret = printChildren(childWnd, indent)
  end

return .true

/** findDescendent()
 * Finds a descendent element with the window title (its name) specified, if
 * any: a button by its label, for instance.
 *
 * @param  wnd   The parent element whose descendents are searched.
 * @param  title The title (label) of the element being searched for.  Case
 *               does not matter, nor the '&' that marks a mnemonic in it.
 *
 * @return  The AutomationElement if found.  If not found then .nil is
 *          returned.
 *
 * @note  UI Automation searches the descendents itself: FindFirst with
 *        TreeScope Descendants.  The original searched the immediate children
 *        with findChild(), then recursed.
 */
::routine findDescendent public
  use strict arg wnd, title

  A = .net~System~Windows~Automation
  byName = A~PropertyCondition~new(A~AutomationElement~NameProperty, title~changeStr("&", ""), -
             A~PropertyConditionFlags~IgnoreCase)

return wnd~FindFirst(A~TreeScope~Descendants, byName)

/** isVistaOrLater()
 * Simple convenience function to determine if the operating system is at least
 * Windows Vista.
 *
 * @return True if the current OS is Vista or a later version of Windows,
 *         otherwise false.
 */
::routine isVistaOrLater public
  -- (.NET version: .NET's Environment~OSVersion. The original compared
  -- SysVersion's version with 6, which today's "10.0.20348" fails: compared
  -- as strings, "1" comes before "6".)
  return .net~System~Environment~OSVersion~Version~Major >= 6


/** getPathToSystemExe()
 * Gets the complete path to an executable that is a standard application
 * shipped with a Windows system.  In a Windows distributions, these
 * applications are in the system directory.  Getting the complete path ensures
 * that the correct application is started.
 *
 * For instance, there are a surprisingly large number of applications named
 * 'calc.'  If a user has set up her system with a 'calc' program in a directory
 * ahead of the system directory in the path, then that calc program can end up
 * being started rather than the expected Windows calculator application.
 *
 * @param  prgName  The program whose path is being sought.  The .exe is
 *                  expected.
 *
 * @return  The fully qualified path name of the program, if it exists in the
 *          system directory.  If not found, then .nil is returned.
 */
::routine getPathToSystemExe public
  use strict arg prgName

  -- .NET's Environment knows the well known folders: "System" is the Windows
  -- System folder (the original asked the Shell.Application OLE object for
  -- its CSIDL_SYSTEM folder).
  sysFolderPath = .net~System~Environment~GetFolderPath("System")
  if sysFolderPath~right(1) \== '\' then sysFolderPath = sysFolderPath'\'

  prgPathName = sysFolderPath || prgName
  if \ SysIsFile(prgPathName) then prgPathName = .nil

return prgPathName

/** startProgram()
 * (.NET version) Starts a program as a separate process: the original's
 * "start" command, as .NET's Process~Start.
 */
::routine startProgram public
  use strict arg prgPathName
  .net~System~Diagnostics~Process~Start(prgPathName)
  return 0

/** getWindowTree()
 * Constructs a data structure that represents the entire element hierarchy of
 * a window.
 *
 * Each node in the structure represents an element.  The node is a .directory
 * object whose items contain the important attributes of the element.  This
 * directory object has an item: children, that is an array of nodes
 * representing the children of the node.
 *
 * Each node has these indexes:
 *
 * node~handle         (0 for an element that is not a window)
 * node~title
 * node~windowClass
 * node~controlType    (.NET version: UI Automation's control type)
 * node~state
 * node~id             (UI Automation's AutomationId)
 * node~coordinates
 * node~children
 * node~hasChildren
 * node~childrenCount
 *
 * @param  wnd  The element to construct a node for.
 *
 * @return  A tree of nodes representing the element specified and all its
 *          children.
 *
 * @note  This is a recursive function.
 */
::routine getWindowTree public
  use strict arg wnd

  walker = .net~System~Windows~Automation~TreeWalker~ControlViewWalker
  tree = buildWindowDetails(wnd)
  child = walker~GetFirstChild(wnd)
  if child == .nil then return tree

  tree~children = .array~new
  tree~hasChildren = .true
  do while child \== .nil
    tree~children~append(getWindowTree(child))
    tree~childrenCount += 1
    child = walker~GetNextSibling(child)
  end

return tree

/** buildWindowDetails()
 * Private helper function for getWindowTree().
 *
 * @param  wnd  The AutomationElement whose details are desired.
 *
 * @return  A directory object whose items reflect a number of attributes of
 *          an element.
 */
::routine buildWindowDetails
  use strict arg wnd

  c = wnd~Current
  d = .directory~new
  d~handle = c~NativeWindowHandle
  d~text = c~Name
  d~windowClass = c~ClassName
  d~controlType = c~ControlType~ProgrammaticName~changeStr("ControlType.", "")
  d~state = state(wnd)
  d~id = c~AutomationId
  d~coordinates = coordinates(wnd)
  d~children = .nil
  d~hasChildren = .false
  d~childrenCount = 0

return d

/* (.NET version) An element's rectangle on the screen: left, top, right,
   bottom (winsystm.cls's coordinates); 0, 0, 0, 0 when it has none */
::routine coordinates public
  use strict arg wnd
  r = wnd~Current~BoundingRectangle
  if r~IsEmpty then return "0, 0, 0, 0"
  return r~Left~format(, 0)"," r~Top~format(, 0)"," r~Right~format(, 0)"," r~Bottom~format(, 0)

/* (.NET version) An element's state, in words, as winsystm.cls's state:
   Enabled or Disabled, Visible or Invisible (off the screen), Focused */
::routine state public
  use strict arg wnd
  c = wnd~Current
  s = c~IsEnabled~?("Enabled", "Disabled") c~IsOffscreen~?("Invisible", "Visible")
  if c~HasKeyboardFocus then s = s "Focused"
  return s

/** printWindowTree
 * Given a tree of window nodes, prints out the tree to the console.
 *
 * @param  tree    The tree of window nodes to print.
 * @param  indent  The current indentation.  Note that this is a recursive
 *                 function and the indent is increased with each recursion.
 *
 * @return  True if the function has recursed, othewise false.
 *
 * @see getWindowTree()
 * @see printChildren()
 *
 * @note  The function produces the exact same output as printChildren().  Its
 *        main purpose was to debug getWindowTree().  However, it could serve
 *        as a useful template if one wanted to change how the information or
 *        what information is printed to the console.
 */
::routine printWindowTree public
  use strict arg tree, indent

  -- A little defensive programming.
  if \ tree~isA(.directory) then return .false

  line = indent || tree~handle ":" tree~id ":" tree~windowClass ":" tree~text~left(15) ":" tree~coordinates

  select
    when tree~childrenCount == 0 then do
      line = line "no children"
      say line
      return .false
    end

    when tree~childrenCount == 1 then do
      line = line "1 child"
    end

    otherwise do
      line = line tree~childrenCount "children"
    end
  end
  -- End select

  say line

  indent = indent || "  "

  do child over tree~children
    ret = printWindowTree(child, indent)
  end

return .true

/** showWindowTree()
 * Puts up a dialog that displays the element hierarchy of a window in a tree
 * view control.
 *
 * @param  tree  A tree node data structure produced by the getWindowTree()
 *               function.
 *
 * @return True if the dialog was shown, false if it was not.
 *
 * @see getWindowTree()
 *
 * @note  The dialog is WinSystemDlgs_IDD_WINDOW_TREE, from winSystemDlgsrc.cls
 *        (the original read winSystemDlgs.rc and its .h, found through the
 *        locate() function).
 */
::routine showWindowTree public
  use strict arg tree

  dlg = .WindowTreeDlg~new                               -- ooDialog: .WindowTreeDlg~new(sd"winSystemDlgs.rc", IDD_WINDOW_TREE, , sd"winSystemDlgs.h")
  if dlg~initCode == 0 then do
    dlg~useTree(tree)
    dlg~execute("SHOWTOP")
    return .true
  end

return .false

/** menuCommand()
 * (.NET version) winsystm.cls's processMenuCommand(menu, item): opens a menu
 * of a window's menu bar and invokes one of its items, as a user would.
 * The names are compared without their '&' and without case.
 *
 * @return  True if the item was invoked.
 */
::routine menuCommand public
  use strict arg wnd, menuName, itemName

  A = .net~System~Windows~Automation
  menuBar = findMenuBar(wnd)
  if menuBar == .nil then return .false
  call focusOn wnd
  item = findDescendent(menuBar, menuName)
  if item == .nil then return .false
  popup = openSubmenu(wnd, item)
  if popup == .nil then return .false
  target = findDescendent(popup, itemName)
  if target == .nil then do
    call closeSubmenu item
    return .false
  end
  target~GetCurrentPattern(A~InvokePattern~Pattern)~Invoke
  return .true

/** pushButton()
 * (.NET version) winsystm.cls's pushButton(label) and sendCommand(id): a
 * button, radio button or check box of a window pushed, found by its label
 * (or, with "ID", by its AutomationId: a classic dialog's control id).  The
 * control's InvokePattern, SelectionItemPattern or TogglePattern.
 *
 * @return  True if the control was found.
 */
::routine pushButton public
  use strict arg wnd, label, by = "NAME"

  A = .net~System~Windows~Automation
  AE = A~AutomationElement
  if by~upper == "ID" then cond = A~PropertyCondition~new(AE~AutomationIdProperty, label)
  else cond = A~PropertyCondition~new(AE~NameProperty, label~changeStr("&", ""), A~PropertyConditionFlags~IgnoreCase)
  ctl = wnd~FindFirst(A~TreeScope~Descendants, cond)
  if ctl == .nil then return .false
  r = .net~ref
  select
    when ctl~TryGetCurrentPattern(A~InvokePattern~Pattern, r) then r~value~Invoke
    when ctl~TryGetCurrentPattern(A~SelectionItemPattern~Pattern, r) then r~value~Select
    when ctl~TryGetCurrentPattern(A~TogglePattern~Pattern, r) then r~value~Toggle
    otherwise return .false
  end
  return .true

/** windowPattern()
 * (.NET version) A window's WindowPattern: minimize, maximize, restore,
 * close (winsystm.cls's minimize, maximize, restore, sendSysCommand("Close")):
 *
 *   windowPattern(wnd)~SetWindowVisualState("Minimized")   (or Maximized, Normal)
 *   windowPattern(wnd)~Close
 */
::routine windowPattern public
  use strict arg wnd
  return wnd~GetCurrentPattern(.net~System~Windows~Automation~WindowPattern~Pattern)

/** resizeWindow()
 * (.NET version) winsystm.cls's resize(width, height): TransformPattern's
 * Resize, when the window can be resized.
 */
::routine resizeWindow public
  use strict arg wnd, width, height
  r = .net~ref
  if \wnd~TryGetCurrentPattern(.net~System~Windows~Automation~TransformPattern~Pattern, r) then return .false
  if \r~value~Current~CanResize then return .false
  r~value~Resize(width, height)
  return .true

/** findMenuBar()
 * (.NET version) A window's menu bar (winsystm.cls's wnd~menu), or .nil: an
 * element of type MenuBar that is not the system menu's (in its title bar).
 * A classic window's menu bar is one of its children; a program that draws
 * its own (the Windows 11 Notepad) has it deeper.
 */
::routine findMenuBar public
  use strict arg wnd

  A = .net~System~Windows~Automation
  AE = A~AutomationElement
  isMenuBar = A~AndCondition~new(A~PropertyCondition~new(AE~ControlTypeProperty, A~ControlType~MenuBar), -
                A~NotCondition~new(A~PropertyCondition~new(AE~AutomationIdProperty, "SystemMenuBar")))
  bar = wnd~FindFirst(A~TreeScope~Children, isMenuBar)
  if bar == .nil then bar = wnd~FindFirst(A~TreeScope~Descendants, isMenuBar)
  return bar

/* (.NET version) A menu item's submenu, opened: its ExpandCollapsePattern's
   Expand, then the menu that appears (an element of type Menu, in the window
   or in a window of its own of the same program: compared with those there
   were before). .nil if the item has no submenu, or none appeared. */
::routine openSubmenu public
  use strict arg wnd, item

  A = .net~System~Windows~Automation
  r = .net~ref
  if \item~TryGetCurrentPattern(A~ExpandCollapsePattern~Pattern, r) then return .nil
  ec = r~value
  if ec~Current~ExpandCollapseState = "LeafNode" then return .nil
  before = .set~new
  do m over menusOf(wnd); before~put(runtimeId(m)); end
  ec~Expand
  do 40
    j = SysSleep(.05)
    do m over menusOf(wnd)
      if \before~hasIndex(runtimeId(m)) then return m
    end
  end
  call closeSubmenu item
  return .nil

/* (.NET version) A menu item's submenu closed again */
::routine closeSubmenu public
  use strict arg item
  r = .net~ref
  signal on syntax                     -- (a menu that closed by itself)
  if item~TryGetCurrentPattern(.net~System~Windows~Automation~ExpandCollapsePattern~Pattern, r) then r~value~Collapse
syntax:
  return

/* The menus open in a window's program: in the window, or top-level windows
   of the same process */
::routine menusOf
  use strict arg wnd

  A = .net~System~Windows~Automation
  AE = A~AutomationElement
  isMenu = A~PropertyCondition~new(AE~ControlTypeProperty, A~ControlType~Menu)
  menus = .array~new
  do m over wnd~FindAll(A~TreeScope~Descendants, isMenu); menus~append(m); end
  pid = .net~int32(wnd~Current~ProcessId)
  sameProcess = A~PropertyCondition~new(AE~ProcessIdProperty, pid)
  do top over AE~RootElement~FindAll(A~TreeScope~Children, sameProcess)
    if A~Automation~Compare(top, wnd) then iterate
    if top~Current~ControlType~ProgrammaticName == "ControlType.Menu" then menus~append(top)
    do m over top~FindAll(A~TreeScope~Descendants, isMenu); menus~append(m); end
  end
  return menus

::routine runtimeId
  use strict arg e
  return e~GetRuntimeId~makeString("L", ".")

/** class: WindowTreeDlg
 *
 * A simple dialog class to display the element hierarchy, parent and
 * descendent elements, of any window.
 *
 * The only caveat is that the class requires a window tree structure created by
 * the getWindowTree() public routine in this framework.
 *
 * This is a subclass of WinSystemDlgs_IDD_WINDOW_TREE, from
 * winSystemDlgsrc.cls: the dialog template of winSystemDlgs.rc, written as an
 * oodnet.cls class by rc2oodnet.rex.
 *
 * @note For an example of how to use this class see the showWindowTree()
 *       public routine in this framework.
 */
::class 'WindowTreeDlg' public subclass WinSystemDlgs_IDD_WINDOW_TREE

/** useTree()
 * Sets the window tree structure for this dialog.  The structure must be set
 * prior to executing the dialog, otherwise the dialog will display an empty
 * tree view control.
 *
 * @param  windowTree  A tree node structure in the same format as that produced
 *                     by the getWindowTree() function.
 *
 * @see getWindowTree()
 */
::method useTree
  expose windowTree
  use arg windowTree

/** initDialog()
 * Initializes the dialog controls for this dialog.  The only control is the
 * Tree control.
 */
::method initDialog
  expose windowTree

  if var("WINDOWTREE"), windowTree~isA(.directory), windowTree~hasIndex("WINDOWCLASS") then self~doInit(windowTree)

/** doInit()
 * A private method that does the actuall work of initializing the tree control.
 *
 * @param windowTree  The window tree node structure for this dialog.
 */
::method doInit private
  expose count
  use strict arg windowTree

  -- Get the tree-view control (a .NET TreeView) and then invoke the addNode()
  -- recursive method to add all the items to the control.
  count = 0
  tree = self~newTreeView(IDC_TREE_WINDOWS)
  rootNode = self~addNode(tree~Nodes, windowTree)

  -- Set the title of this dialog, which will contain the window handle for the
  -- window we represent.
  title = "The" windowTree~text "(" || windowTree~handle || ") Window Hierarchy"
  self~setTitle(title)

  -- Expand the root item in the tree-view control.
  rootNode~Expand                                        -- ooDialog: tree~expand(rootNode)

/** addNode()
 * A private recursive function that adds each node to the tree control.  Each
 * node represents a single element in the hiearchy.
 *
 * @param  nodes  The TreeNodeCollection the node goes into: the tree's
 *                Nodes, or a node's.
 *
 * @param  node  The current node in the window tree structure we are working
 *               with.
 */
::method addNode private
  expose count
  use strict arg nodes, node

  -- The text displayed for this item.
  text = node~handle || ":" node~text "["node~controlType"]"

  -- Add a new item, the element's, at the end of the nodes.
  newRoot = nodes~Add(text)                              -- ooDialog: tree~insert(root, "LAST", text, , , , node~childrenCount)
  count += 1

  -- Insert sub-items.  Each of these sub-items is an attribute of the element
  newRoot~Nodes~Add("Text:" node~text)
  newRoot~Nodes~Add("Handle:" node~handle)
  newRoot~Nodes~Add("Class:" node~windowClass)
  newRoot~Nodes~Add("Control type:" node~controlType)
  newRoot~Nodes~Add("ID:" node~id)
  newRoot~Nodes~Add("Coordinates:" node~coordinates)
  newRoot~Nodes~Add("State:" node~state)

  -- Now, if the element has children, recursively add them to the tree-view
  -- control.
  if node~hasChildren then do n over node~children
    self~addNode(newRoot~Nodes, n)
  end

return newRoot

::method autoRun                       -- (.NET version) unattended: what it shows, then OK
  expose count
  say "(auto)" self~form~Text":" count "elements"
  self~ok

/** class: MenuDetailer
 *
 * A class to read and display the details of a menu bar.
 *
 * In Windows, a menu bar is similar to a top level window in that they both
 * have a hierarchy of contained objects.  A top-level window can contain other
 * windows, which themselves can contain other windows.  A menu bar can contain
 * submenus, which can contain submenus.
 *
 * This hierarchy is easily displayed in a tree-like structure, for both windows
 * and menus.  The function of displaying a menu hierachy is therefore very
 * similar to the set of functions used to display a window hierarchy provided
 * in this framework.
 *
 * However, the MenuDetailer is a more object-orientated approach than that used
 * for displaying a window hierarchy.  The data and the means to manipulate the
 * data are all contained within a single object, the MenuDetailer object.
 *
 * (.NET version) UI Automation sees a menu's items only while the menu is
 * open: the MenuDetailer opens each menu and submenu (and closes it again),
 * as a user would, to read it; the window comes to the foreground for that.
 * An item's id is its AutomationId ("Item 25" in a classic menu: its
 * position's, not the command's id). The original subclassed RcDialog to
 * display(); here display() shows a MenuTreeDlg.
 */
::class 'MenuDetailer' public

::method init
  use strict arg wnd
  self~newWindow(wnd)


/** newWindow()
 * This method is called to create a menu tree node structure that represents
 * the menu of the specified window.  It is used when a new MenuDetailer object
 * is created and when / if the user of the class sets a new window.
 *
 * @param  wnd  An AutomationElement (a window) whose menu is to be 'detailed.'
 */
::method newWindow private
  expose menubar maxTextLength textFormat mainWindow
  use strict arg wnd

  -- Ensure wnd is an AutomationElement.
  if .net~typeOf(wnd) \== "System.Windows.Automation.AutomationElement" then
    raise syntax 93.948 array ("1 'wnd'", "AutomationElement")

  -- Set / reset some state variables.
  maxTextLength = 0
  textFormat = .nil
  menubar = .nil
  mainWindow = wnd

  -- Create the menu tree node structure.
  self~createMenubar

/** createMenubar()
 * Creates a menu tree node structure that represents the menu of the main
 * window.
 *
 * Conceptually, a menu consists of a container with some number of menu items,
 * where each menu item can, possibly, be a submenu.  Typically in Windows, the
 * top-level container is called a menubar.  A tree is a natural data
 * structure to represent this.
 *
 * The menu tree node structure consists of a directory that represents the
 * menubar and has this structure:
 *
 *   menubar~ownerHwnd
 *   menubar~ownerTitle
 *   menubar~itemCount
 *   menubar~menuItems  an array of menu items where each menu item is a
 *                      directory.
 *
 *     menuitem~pos
 *     menuitem~id
 *     menuitem~text
 *     menuitem~isSubmenu
 *     menuitem~isSeparator
 *     menuitem~isTextItem
 *     menuitem~isChecked
 *     menuitem~itemCount
 *     menuitem~menuItems  an array of menu items
 *
 */
::method createMenubar private
  expose menubar mainWindow

  menubar = .directory~new
  menubar~ownerTitle = mainWindow~Current~Name
  menubar~ownerHwnd = mainWindow~Current~NativeWindowHandle

  menu = findMenuBar(mainWindow)                         -- ooDialog: mainWindow~menu
  if menu == .nil then do
    menubar~itemCount = -1
    menubar~menuItems = .nil
  end
  else do
    call focusOn mainWindow                              -- (.NET version: the menus are opened)
    menubar~menuItems = self~populate(menu)
    menubar~itemCount = menubar~menuItems~items
  end

/** populate()
 * A recursive function to create and return an array of menu items.
 *
 * @param  A menu bar or menu (an AutomationElement) whose menu items will be
 *         used to create and populate an array.
 *
 * @return The populated array.
 *
 * @see createMenubar()
 */
::method populate private
  expose maxTextLength mainWindow
  use strict arg menu

  A = .net~System~Windows~Automation
  r = .net~ref

  items = .array~new                                     -- (not "a": Rexx's names know no case, A is the namespace)
  i = 0
  do item over menu~FindAll(A~TreeScope~Children, A~Condition~TrueCondition)
    c = item~Current
    type = c~ControlType~ProgrammaticName
    if type \== "ControlType.MenuItem", type \== "ControlType.Separator" then iterate
    d = .directory~new
    d~pos = i
    d~id = c~AutomationId
    d~text = c~Name
    d~isSeparator = (type == "ControlType.Separator")
    d~isChecked = .false
    if item~TryGetCurrentPattern(A~TogglePattern~Pattern, r) then d~isChecked = (r~value~Current~ToggleState = "On")
    submenu = .nil
    if \d~isSeparator then submenu = openSubmenu(mainWindow, item)   -- ooDialog: menu~submenu(i)
    d~isSubmenu = (submenu \== .nil)
    d~isTextItem = \(d~isSeparator | d~isSubmenu)

    if d~text~length > maxTextLength then maxTextLength = d~text~length

    if d~isSubmenu then do
      d~menuItems = self~populate(submenu)
      d~itemCount = d~menuItems~items
      call closeSubmenu item
    end
    else do
      d~itemCount = 0
      d~menuItems = .nil
    end

    items~append(d)
    i += 1
  end

return items

/** print()
 * Outputs a text representation of the menu to the console.
 */
::method print
  expose textFormat

  -- If not already created, construct an array of text lines that represents
  -- the menu.  Then output the lines to the console.
  if textFormat == .nil then self~toArray
  do l over textFormat
    say l
  end

/** getOutline()
 * Return the array of text lines representing the menu to the caller.  The
 * caller can then use the array as they see fit.
 */
::method getOutline
  expose textFormat

  -- Return a copy of the array to the caller so that an outsider can not
  -- unintentionally or intentionally change our internal data.
  if textFormat == .nil then self~toArray
  return textFormat~copy

/** getMenubar()
 * Return the menu tree node structure to the caller.  The caller can then
 * format and / or use the data as desired.
 */
::method getMenubar
  expose menubar

  -- Recreate the menubar if needed.
  if menubar == .nil then self~createMenubar

  -- Since ooRexx does not have a deep copy, we save a reference to the menuBar
  -- object, set our internal reference to the menubar to .nil, and return the
  -- saved reference.  This allows the caller to change the menubar without
  -- changing our internal representation.  If we need the menubar structure
  -- again, we will re-create it.
  populatedMenubar = menubar
  menubar = .nil

return populatedMenubar

/** setWindow()
 * Changes the main window to a new one.
 */
::method setWindow
  use strict arg wnd
  self~newWindow(wnd)

/** toArray()
 * Transforms the menu tree node structure that represents our menu into an
 * array of text lines that represents the menu.
 */
::method toArray private
  expose menubar textFormat

  -- Check if we need to recreated the menubar.
  if menubar == .nil then self~createMenubar

  textFormat = .array~new

  -- The first line will show data about the main window.  It is possible that
  -- the window will were initialized with does not have a menu.  In addition,
  -- many applications now create their menus dynamically.  Those types of menus
  -- may not contain any menu items until the user actually selects a menu item.
  -- For these two cases we return immediately.

  line = menubar~ownerTitle "(" || menubar~ownerHwnd || ")"
  if menubar~itemCount == -1 then do
    textFormat[1] = line "does not have a menu"
    return textFormat
  end
  else if menubar~itemCount == 0 then do
    textFormat[1] = line "menu is not populated"
    return textFormat
  end

  -- Add the first line, then recursively add a line for every menu item.
  textFormat[1] = line
  do item over menubar~menuItems
    self~addArrayItem(item, "  ")
  end

/** addArrayItem()
 * A recursive method that adds a line of text for every menu item to an array
 * of lines.
 *
 * @param  item    A node in the menu tree node structure representing a menu
 *                 item.
 *
 * @param  indent  A string of spaces, the length of which shows the depth of
 *                 the menu item within the overall menu.
 */
::method addArrayItem private
  expose maxTextLength textFormat
  use strict arg item, indent

  -- Build up a line of text for the menu item
  line = indent
  sep = '-'~copies(maxTextLength)
  pos = item~pos~right(2) || ':'
  id = '[id:' item~id~left(11) || ']'                    -- (an AutomationId: "Item 25", "Separator 6")

  select
    when item~isSubmenu then do
      line = line || pos id 'popup menu' item~text~left(maxTextLength)
    end
    when item~isSeparator then do
      line = line || pos id 'separator ' sep
    end
    otherwise do
      line = line || pos id 'menu item ' item~text~left(maxTextLength)
      if item~isChecked then line = line '[checked]'
    end
  end
  -- End select

  -- Add the line to our array of lines.
  textFormat~append(line)

  -- If item is itself a menu, recursively add its menu items to the array.
  if item~isSubmenu then do
    -- Increase our indent by 2 spaces.
    indent = indent || "  "
    do menuItem over item~menuItems
      self~addArrayItem(menuItem, indent)
    end
  end

/** display()
 * Displays our menu in a graphical format using a tree control in a dialog.
 *
 * The dialog is a MenuTreeDlg: WinSystemDlgs_IDD_MENU_TREE, from
 * winSystemDlgsrc.cls (the original initialized its own RcDialog superclass
 * here, with winSystemDlgs.rc).
 */
::method display
  expose menubar maxTextLength

  -- Check if we need to recreate the menubar.
  if menubar == .nil then self~createMenubar
  dlg = .MenuTreeDlg~new(menubar, maxTextLength)
  dlg~execute("SHOWTOP")

/** class: MenuTreeDlg
 * (.NET version) The dialog MenuDetailer~display shows: the original's
 * MenuDetailer initDialog, addNode and logicalToString.
 */
::class 'MenuTreeDlg' subclass WinSystemDlgs_IDD_MENU_TREE

::method init
  expose menubar maxTextLength count
  use strict arg menubar, maxTextLength
  count = 0
  self~init:super

/** initDialog()
 * Initializes the dialog controls for this dialog.  The only control is the
 * Tree control.
 *
 * @see WindowTreeDlg::initDialog()
 */
::method initDialog
  expose menubar

  -- Set the dialog title to a subset of what will be the text for the first
  -- item in the tree-view control.
  rootText = menubar~ownerTitle "(" || menubar~ownerHwnd || ")"
  self~setTitle(rootText "Menu Hierarchy")

  -- The tree-view control is populated in a similar manner as was the tree-view
  -- control in the WindowTreeDlg class in this framework.  See that class for
  -- comment if needed.

  -- Get the tree-view object, set the first item, expand it.
  tree = self~newTreeView(IDC_TREE_MENUS)

  if menubar~itemCount == -1 then do
    rootText = rootText "[window does not have a menu]"
  end
  else if menubar~itemCount == 0 then do
    rootText = rootText "[menu is not populated]"
  end

  rootNode = tree~Nodes~Add(rootText)                    -- ooDialog: tree~add(rootText, , , "EXPANDED")

  -- If the menubar has menu items, recursively add then to the tree-view
  -- control.
  if menubar~itemCount > 0 then do item over menubar~menuItems
    self~addNode(rootNode, item)
  end
  rootNode~Expand

/** addNode()
 * Recursively add tree-view items for each menu item in our menu.
 *
 * @param  root      The TreeNode the item goes under.
 *
 * @param  menuItem  The current node in the menu tree structure we are working
 *                   with.
 *
 * @see WindowTreeDlg::initDialog()
 */
::method addNode private
  expose maxTextLength count
  use strict arg root, menuItem

  text = menuItem~pos~right(2) || ':'

  if menuItem~isSeparator then text = text '-'~copies(maxTextLength)
  else text = text menuItem~text

  newRoot = root~Nodes~Add(text)                         -- ooDialog: tree~insert(root, "LAST", text, , , , count)
  count += 1

  newRoot~Nodes~Add("Text:" menuItem~text)
  newRoot~Nodes~Add("ID:" menuItem~id)
  newRoot~Nodes~Add("Submenu?" self~logicalToString(menuItem~isSubmenu))
  newRoot~Nodes~Add("Text Item?" self~logicalToString(menuItem~isTextItem))
  newRoot~Nodes~Add("Separator?" self~logicalToString(menuItem~isSeparator))
  newRoot~Nodes~Add("Checked?" self~logicalToString(menuItem~isChecked))

  if menuItem~isSubmenu then do mi over menuItem~menuItems
    self~addNode(newRoot, mi)
  end

return newRoot

::method autoRun                       -- (.NET version) unattended: what it shows, then OK
  expose count
  say "(auto)" self~form~Text":" count "menu items"
  self~ok

/** logicalToString()
 * Simple helper method to convert an ooRexx logical value to a string
 * representation.
 *
 * @param  logical  The value to convert.
 *
 * @return The string "true" if logical is strictly true, otherwise the string
 *         "false"
 */
::method logicalToString private
  use strict arg logical

  -- Work with anything sent to us.  This uses the short-cut AND operator.  Once
  -- a test fails, the rest of the tests are not evaluated.  If logical is a
  -- string object, and the data type of the string object is lOgical, and
  -- logical is true then return "true"  Othewise return "false"

  if logical~isA(.String), logical~datatype('O'), logical then return 'true'
  else return 'false'

/** findTextArea()
 * (.NET version) The element that holds a window's text, to type into: the
 * first Document or Edit among its descendants (in the classic Notepad its
 * first child, an Edit window; deeper in the Windows 11 Notepad).
 */
::routine findTextArea public
  use strict arg wnd

  A = .net~System~Windows~Automation
  AE = A~AutomationElement
  isText = A~OrCondition~new(.array~of(A~PropertyCondition~new(AE~ControlTypeProperty, A~ControlType~Document), -
                                       A~PropertyCondition~new(AE~ControlTypeProperty, A~ControlType~Edit)))
  return wnd~FindFirst(A~TreeScope~Descendants, isText)

/** windowOf()
 * (.NET version) The window an element is in: the element itself or its
 * nearest ancestor of type Window (a button's dialog).
 */
::routine windowOf public
  use strict arg element

  walker = .net~System~Windows~Automation~TreeWalker~ControlViewWalker
  e = element
  do while e \== .nil
    if e~Current~ControlType~ProgrammaticName == "ControlType.Window" then return e
    e = walker~GetParent(e)
  end
  return element

/** The Calculator
 * (.NET version) winsystm.cls's sendCommand(id) pushed the Calculator's
 * buttons by their control ids, and its answer was the title of its first
 * child window. UI Automation pushes them by their AutomationIds: in the
 * classic Calculator (Windows 7's, still on Windows Server) the control ids
 * (its own: Windows XP's, which the original used, differ); in today's
 * Calculator (an app: its window's class is ApplicationFrameWindow) names
 * like num1Button. calcKey() knows both, by the key's label.
 */
::routine isModernCalc public
  use strict arg calc
  return calc~Current~ClassName == "ApplicationFrameWindow"

/** calcKey()
 * (.NET version) Pushes a Calculator key: "0" to "9", ".", "+", "-", "*",
 * "/", "=", "C" (clear), "MC", "MR", "MS" (memory clear, recall, store),
 * "Hex", "Dec", "Grads".
 *
 * @return  True if the key was there.
 */
::routine calcKey public
  use strict arg calc, key

  classic = .directory~new; modern = .directory~new
  do n = 0 to 9
    classic[n] = 130 + n; modern[n] = "num" || n || "Button"
  end
  labels  = ". + - * / = C MC MR MS HEX DEC GRADS"
  classicIds = "84 93 94 92 91 121 81 122 123 124 313 314 323"
  modernIds = "decimalSeparatorButton plusButton minusButton multiplyButton divideButton" -
              "equalButton clearButton ClearMemoryButton MemRecall memButton hexButton decimalButton gradsButton"
  do i = 1 to labels~words
    classic[labels~word(i)] = classicIds~word(i)
    modern[labels~word(i)] = modernIds~word(i)
  end
  k = key~upper
  if \classic~hasIndex(k) then return .false
  if isModernCalc(calc) then return pushButton(calc, modern[k], "ID")
  return pushButton(calc, classic[k], "ID")

/** calcDisplay()
 * (.NET version) The number the Calculator shows: the classic's display
 * (AutomationId 150) is named after it; today's (CalculatorResults) says
 * "Display is 160".
 */
::routine calcDisplay public
  use strict arg calc

  A = .net~System~Windows~Automation
  if isModernCalc(calc) then aid = "CalculatorResults"
  else aid = "150"
  display = calc~FindFirst(A~TreeScope~Descendants, A~PropertyCondition~new(A~AutomationElement~AutomationIdProperty, aid))
  if display == .nil then return ""
  text = display~Current~Name
  if text~caselessAbbrev("Display is ") then text = text~substr(12)
  return text~strip

/** calcView()
 * (.NET version) The Calculator's view: Standard, Scientific or Programmer
 * (told from its keys: Degrees in the scientific view, Hex in the
 * programmer's).
 */
::routine calcView public
  use strict arg calc

  A = .net~System~Windows~Automation
  if isModernCalc(calc) then ids = .array~of("hexButton", "degreesButton radiansButton gradsButton")
  else ids = .array~of("313", "321")
  views = .array~of("Programmer", "Scientific")
  do i = 1 to 2
    do aid over ids[i]~makeArray(" ")
      cond = A~PropertyCondition~new(A~AutomationElement~AutomationIdProperty, aid)
      if calc~FindFirst(A~TreeScope~Descendants, cond) \== .nil then return views[i]
    end
  end
  return "Standard"

/** calcSetView()
 * (.NET version) Switches the Calculator's view: the classic's View menu
 * (winsystm.cls's processMenuCommand("&View", "&Scientific")); today's
 * navigation pane (its TogglePaneButton, then the view's item).
 *
 * @return  True if the view was switched.
 */
::routine calcSetView public
  use strict arg calc, view

  if \isModernCalc(calc) then do
    done = menuCommand(calc, "View", view)
    j = SysSleep(.5)
    return done
  end
  if \pushButton(calc, "TogglePaneButton", "ID") then return .false
  j = SysSleep(.5)
  done = pushButton(calc, view, "ID")
  j = SysSleep(.5)
  return done

/** calcCopy(), calcPaste()
 * (.NET version) The Calculator's Edit menu, Copy and Paste: the classic's
 * menu; Ctrl+C and Ctrl+V for today's, which has no menu.
 */
::routine calcCopy public
  use strict arg calc
  if \isModernCalc(calc) then return menuCommand(calc, "Edit", "Copy")
  call focusOn calc
  .net~System~Windows~Forms~SendKeys~SendWait("^c")
  return .true

::routine calcPaste public
  use strict arg calc
  if \isModernCalc(calc) then return menuCommand(calc, "Edit", "Paste")
  call focusOn calc
  .net~System~Windows~Forms~SendKeys~SendWait("^v")
  return .true

/** topLevelOf()
 * (.NET version) The top-level window an element is in: the ancestor whose
 * parent is the root element (winsystm.cls's foregroundWindow gave the
 * window; UI Automation's FocusedElement is the control with the focus).
 */
::routine topLevelOf public
  use strict arg element

  A = .net~System~Windows~Automation
  root = A~AutomationElement~RootElement
  walker = A~TreeWalker~ControlViewWalker
  e = element
  do forever
    parent = walker~GetParent(e)
    if parent == .nil then return e
    if A~Automation~Compare(parent, root) then return e
    e = parent
  end
