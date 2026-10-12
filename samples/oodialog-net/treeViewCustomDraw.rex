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

/**
 * treeViewCustomDraw.rex
 *
 * This example demonstrates many of the features of a tree-view control.
 * Including, but not limited to: label editing of items, custom draw, using
 * image lists to supply the icons for tree-view items, using a custom compare
 * function in the Rexx dialog to sort the tree-view items, displaying info
 * tips, etc..
 *
 * Note: this program uses the public routine, locate(), to get the full path
 * name to the directory this source code file is located. In places, the
 * variable holding this value has been callously abbreviated to 'sd' which
 * stands for source directory.
 *
 * (.NET version of ooDialog's controls\TreeView\treeViewCustomDraw.rex, on
 * Windows Forms through oodnet.cls; the .rc is treeViewCustomDrawrc.cls,
 * written by rc2oodnet.rex -cls; the bitmap and the input files are in
 * resources\. An item is a .NET TreeNode: its text, its images
 * (ImageIndex, SelectedImageIndex), its item data (Tag), its children
 * (Nodes); ooDialog's item handles, 0 for none, are TreeNodes, .nil for
 * none. Custom draw is the TreeView's own: DrawMode OwnerDrawText, its
 * DrawNode event for each item (onCustomDraw draws the text in the colours
 * the original sets). EXPANDING is BeforeExpand and BeforeCollapse; an
 * item with children it does not have yet (the input's children field) has
 * a placeholder child, which shows the plus sign as Windows' cChildren does.
 * Label editing is LabelEdit (DEFAULTEDIT); KEYDOWN the TreeView's KeyDown
 * (.VK's codes); a .NET TreeView shows a node's ToolTipText as its info tip
 * (TVS_INFOTIP: ShowNodeToolTips): each node's, as it is added, is what
 * onGetInfoTip answers for it. A .NET TreeView sorts all of its nodes, with
 * one comparer: sortChildrenCB, here, sorts one item's children itself,
 * with rexxSort. The tree-view's methods (add, insert, itemInfo, child,
 * next...) are routines below, on TreeNodes.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .InventoryDlg~new                                 -- ooDialog: .InventoryDlg~new(srcDir"rc\treeViewCustomDraw.rc", IDD_TREE_DLG)
    if dlg~initCode = 0 then do
        ret = dlg~execute("SHOWTOP")
    end

return 0

::requires "treeViewCustomDrawrc.cls"


/*- TreeViewConstants - Class - - - - - - - - - - - - - - - - - - - - - - - - *\

   This mixin class defines some constant values and is inherited by the two
   dialog classes in this example.

\*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
::class 'TreeViewConstants' mixinclass Object

::attribute BMP_FILE get
    sd = filespec("location", .context~package~name)       -- ooDialog: locate()
    return sd"resources\treeViewCustomDraw.bmp"   -- Icons for selected/not-selected items.

::attribute TREE_FILE get
    sd = filespec("location", .context~package~name)
    return sd"resources\treeViewCustomDraw.inp"      -- Input file with the items to build the tree.

::attribute ITEM_FILE get
    sd = filespec("location", .context~package~name)
    return sd"resources\treeViewCustomDrawI.inp"     -- Input file with dynamically added items.

::constant APPLICATION_TITLE  "Crazy Sam's Emporium - Inventory"

::constant UNSELECTED_FOLDER  0         -- Index for the icon of an unselected folder item
::constant SELECTED_FOLDER    1         -- Index for the icon of a selected folder item
::constant UNSELECTED_LEAF    2         -- Index for the icon of an unselected leaf item
::constant SELECTED_LEAF      3         -- Index for the icon of a selected leaf item


/*- InventoryDlg - Class- - - - - - - - - - - - - - - - - - - - - - - - - - - *\

   This is the main dialog class for this example.  It contains the tree-view
   control that the example is all about.

\*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
::class 'InventoryDlg' subclass TreeViewCustomDraw_IDD_TREE_DLG inherit TreeViewConstants

/** isLeafItem()  [class method]
 *
 * The isLeafItem() method provides a convenient way to test if any tree-view
 * item is a leaf item rather than a folder item.  Leaf items and folder items
 * in this example use different icon images, so we just test which icon is set
 * for the item.
 */
::method isLeafItem class
  use strict arg treeView, item
  info. = itemInfo(item)                                    -- ooDialog: treeView~itemInfo(item)
return info.!Image == self~UNSELECTED_LEAF


/** init()
 *
 * Initialization of the Rexx dialog object.  We do several things here.
 *
 * 1.) Initialize the super class.  Never invoke any method on a dialog class
 *     before the super class is initialized.
 *
 * 2.) So a sanity check to ensure the data files needed can be found.
 *
 * 3.) Connect the event handlers for the tree-view.
 *
 * 4.) Create custom colors to draw the individual items in the tree-view.
 *
 * 5.) Initialize the custom draw interface and register the tree-view control
 *     to use custom draw.  (.NET version: in initDialog, the TreeView's
 *     DrawMode.)
 */
::method init
    expose bkClr oddLevelClr evenLevelClr selectedClr leafClr

    self~init:super
    if self~initCode <> 0 then return self~initCode

    if self~checkForRequiredFiles == .false then do
      self~initCode = 17
      return self~initCode
    end

    -- Connect dialog control events to methods in the Rexx dialog.
    self~connectEvent(IDC_TREE, "BeforeExpand", "onExpanding")    -- ooDialog: connectTreeViewEvent(IDC_TREE, "EXPANDING", "onExpanding", .true)
    self~connectEvent(IDC_TREE, "BeforeCollapse", "onExpanding")
    self~connectEvent(IDC_TREE, "KeyDown", "onKeyDown")           -- ooDialog: connectTreeViewEvent(IDC_TREE, "KEYDOWN", "onKeyDown")
    -- (.NET version) DEFAULTEDIT and GETINFOTIP: see initDialog

    self~connectButtonEvent(IDC_PB_NEW,     "CLICKED", "onNewItem")
    self~connectButtonEvent(IDC_PB_DELETE,  "CLICKED", "onDeleteItem")
    self~connectButtonEvent(IDC_PB_SORT,    "CLICKED", "onSortChildren")
    self~connectButtonEvent(IDC_PB_EXP_ALL, "CLICKED", "onExpandAll")
    self~connectButtonEvent(IDC_PB_COL_ALL, "CLICKED", "onCollapseAll")
    self~connectButtonEvent(IDC_PB_INFO,    "CLICKED", "onItemInfo")

    -- Create the custom colors use to draw the tree-view items
    C = .net~System~Drawing~Color                           -- ooDialog: self~RGB(r, g, b)
    bkClr        = C~FromArgb(250, 250, 250)
    oddLevelClr  = C~FromArgb( 82,  61,   0)
    evenLevelClr = C~FromArgb(  0,  20,  82)
    selectedClr  = C~FromArgb( 82,   0,  20)
    leafClr      = C~FromArgb(  0,  82,  20)

return 0


/** initDialog()
 *
 * Just as the init() method is for initializing the Rexx dialog object, the
 * initDialog() method is used to initialize the underlying Windows dialog.
 * Some things, like inserting the items into a tree-view, can only be done
 * after the Windows dialog exists.  Those types of things are done here.
 */
::method initDialog
    expose tv bkClr

    tv = self~newTreeView("IDC_TREE")

    tv~LabelEdit = .true                                    -- ooDialog: connectTreeViewEvent(IDC_TREE, "DEFAULTEDIT"), TVS_EDITLABELS
    tv~ShowNodeToolTips = .true                             -- (TVS_INFOTIP: each node's ToolTipText, from onGetInfoTip)
    tv~HideSelection = .false                               -- (TVS_SHOWSELALWAYS)
    tv~BackColor = bkClr
    tv~DrawMode = "OwnerDrawText"                           -- ooDialog: self~customDraw, self~customDrawControl(IDC_TREE, 'TreeView')
    tv~DrawNode += .net~handler(self, "ONCUSTOMDRAW")
    tv~AfterSelect += .net~handler(self, "ONSELECTED")

    -- Set the image list for the tree-vies
    image = .net~System~Drawing~Bitmap~new(self~BMP_FILE)   -- ooDialog: .Image~getImage(self~BMP_FILE)
    imageList = .net~System~Windows~Forms~ImageList~new     -- ooDialog: .ImageList~create(.Size~new(16, 12), 'COLOR8', 5, 2)
    imageList~ColorDepth = "Depth8Bit"
    imageList~ImageSize = .net~System~Drawing~Size~new(16, 12)
    imageList~Images~AddStrip(image)                        -- ooDialog: imageList~add(image)
    tv~ImageList = imageList                                -- ooDialog: tv~setImageList(imageList, 'NORMAL')
    h = imageList~Handle                                    -- (the image list's copies made: the bitmap can go)
    image~Dispose                                           -- ooDialog: image~release

    -- Read the file containing the tree input data and build the tree.
    do while lines(self~TREE_FILE)
        args = self~makeArgs(linein(self~TREE_FILE))
        self~add(tv, args)                                  -- ooDialog: tv~sendWith('add', args)
    end
    call expandAdded

    -- Select the item with the text of Computers.
    hItem = find(tv, 'Computers')
    if hItem \== .nil then tv~SelectedNode = hItem          -- ooDialog: if hItem \== 0 then tv~select(hItem)

return 0


/*- - - - - - - - - - Event handler(s) - - - - - - - - - - - - - - - - - - - -*/

/** onCustomDraw()
 *
 * This is the event handler for the custom draw event.  Certain of the dialog
 * controls in Windows support custom draw.  Those controls send custom draw
 * event notifications through out the paint cycle when the control is drawing
 * or redrawing itself.  (.NET version: the TreeView's DrawNode, for each
 * item's text; we draw it.)
 *
 * We take advantage of custom draw here to paint each individual tree-view item
 * a custom color depending on exactly which item is about to be drawn.
 *
 * Our scheme is relatively simple.  Every other level of the tree is painted an
 * alternating color.  If an item is selected, it is painted a reddish color to
 * match the reddish selected icon.  If not selected and a leaf node, we paint
 * it a greenish color to match the non-folder, non-selected greenish icon.
 */
::method onCustomDraw unguarded
  expose tv bkClr oddLevelClr evenLevelClr selectedClr leafClr
  use arg treeView, tvcds

  if tvcds~Bounds~IsEmpty then return .false               -- (an item not shown)

  selected = tv~SelectedNode
  isLeaf   = .InventoryDlg~isLeafItem(tv, tvcds~Node)

  if selected \== .nil, selected~Equals(tvcds~Node) then do
    clrText   = selectedClr
    clrTextBk = bkClr
  end
  else if isLeaf then do
    clrText   = leafClr
    clrTextBk = bkClr
  end
  else if tvcds~Node~Level // 2 == 1 then do
    clrText   = oddLevelClr
    clrTextBk = bkClr
  end
  else do
    clrText   = evenLevelClr
    clrTextBk = bkClr
  end

  -- (.NET version) what Windows does with clrText and clrTextBk
  g = tvcds~Graphics
  brush = .net~System~Drawing~SolidBrush~new(clrTextBk)
  g~FillRectangle(brush, tvcds~Bounds)
  brush~Dispose
  font = tvcds~Node~NodeFont
  if font == .nil then font = tv~Font
  .net~System~Windows~Forms~TextRenderer~DrawText(g, tvcds~Node~Text, font, tvcds~Bounds, clrText, "VerticalCenter, SingleLine, NoPrefix")
  if tvcds~State~ordinal // 32 >= 16 then -                -- (TreeNodeStates.Focused)
    .net~System~Windows~Forms~ControlPaint~DrawFocusRectangle(g, tvcds~Bounds, clrText, clrTextBk)
  return .true


/** onSelected()
 *
 * (.NET version) A new selection: the items drawn again, the old selected
 * one too (Windows' custom draw asks for both).
 */
::method onSelected unguarded
  expose tv
  tv~Invalidate


/** onExpanding()
 *
 * This is the event handler for the EXPANDING event.  The method is invoked
 * when a tree-view item is about to be expanded or collapsed.  The method is
 * invoked before the item is expanded or collapsed.
 *
 * This method demonstrates dynamically adding items to the tree.  The node,
 * 'Special Offers' is initially added to the tree during initDialog with no
 * children.  (.NET version: with a placeholder child.)
 *
 * When the user expands the node, the child items for the node are dynamically
 * added here.  The items are loaded from a file in the same manner as the
 * original items are loaded from a file to build the tree.
 *
 * When the user collapses the node, all its children items are removed.  This
 * is done through the collapseAndReset method, which collapse the item and also
 * tells the tree-view control to deallocate the children.
 */
::method onExpanding unguarded
    expose tv
    use arg tree, e

    item = e~Node                                           -- (.NET version) ooDialog's (tree, item, what, extra)
    what = item~IsExpanded~?("COLLAPSED", "EXPANDED")       -- (before the change: expanded now, it is collapsing)

    itemInfo. = itemInfo(item)
    if itemInfo.!TEXT = "Special Offers" then do
        if what == "EXPANDED", child(item) == .nil then do
            call removePlaceholder item
            do while lines(self~ITEM_FILE)
                args = self~makeArgs(item, , linein(self~ITEM_FILE))
                newItem = self~insert(tv, args)             -- ooDialog: tv~sendWith('insert', args)
            end
        end
        else if what == "COLLAPSED", child(item) \== .nil then do
            call collapseAndReset item
        end
    end

return .true


/** onKeyDown()
 *
 * This is the event handler for the key down event.  It is invoked each time
 * the user presses a key when the tree-view has the focus.
 *
 * We examime the key pressed to see if it is the insert or delete key.
 *
 * On the insert key we simulate pushing the 'New Item' push button by invoking
 * the event handler for that button.  This allows the user to add a new tree-
 * view item.
 *
 * On the delete key, we delete the selected item.
 */
::method onKeyDown unguarded
  expose tv
  use arg treeId, e

  key = e~KeyValue                                          -- (.NET version) the virtual key

  if key == .VK~DELETE then
      call delete tv, tv~SelectedNode                       -- ooDialog: tv~delete(tv~Selected)
  else if key == .VK~INSERT then
      self~onNewItem

return 0


/** onNewItem()
 *
 * This is the event handler for the 'New Item' push button.  It is invoked when
 * the user clicks that button.
 *
 * We put up a dialog that allows the user to fill out the details for a new
 * tree-view item and insert it into the tree-view.
 */
::method onNewItem unguarded
    expose tv

    dlg = .NewTreeItemDlg~new(tv)                           -- ooDialog: .NewTreeItemDlg~new(sd"rc\treeViewCustomDraw.rc",  IDD_ADD_TREE_ITEM, tv)
    dlg~execute

return 0


/** onDeleteItem()
 *
 * This is the event handler for the 'Delete Item' push button.  This method is
 * invoked when the user clicks that button.
 *
 * We expand the selected item and all its children recursively.
 */
::method onDeleteItem unguarded
    expose tv

    selected = tv~SelectedNode
    if selected == .nil then do
        title = self~APPLICATION_TITLE~subword(1, 3) '- Warning'
        msg   = "There is no tree-view item selected.  If you" || .endOfLine           ||-
                "continue, all items will be deleted."         || .endOfLine~copies(2) ||-
                "Do you want to continue and delete all items?"

        ret = MessageDialog(msg, self~hwnd, title, 'YESNO', 'WARNING', 'DEFBUTTON2')
        if ret == self~IDNO then return 0
    end

    call delete tv, selected
return 0


/** onGetInfoTip()
 *
 * This is the event handler for the INFOTIP event.  It is invoked when the
 * tree-view wants the text to display in the info tip.  (.NET version: as
 * each item is added; its answer is the node's ToolTipText.)
 *
 * If we return the empty string, then no info tip is displayed.  Otherwise, the
 * text returned is displayed.  Here, we only return text when the itemData is
 * the string: '...'  In that case we return some text.  In all other cases we
 * return the empty string and no info tip is displayed.
 */
::method onGetInfoTip unguarded
    expose tv
    use arg id, hItem, text, maxLen, itemData

    if itemData == '...' then return 'There are too many books to list'
    else return ''


/** onSortChildre()
 *
 * This is the event handler for the 'Reverse Sort' push button.  This method is
 * invoked when the user pushes that button.
 *
 * To sort in any other order requires using the sortChildrenCB() method.  With
 * this method, the programmer names a 'call back' method in the Rexx dialog.
 * This method is then invoked by the tree-view for each item it needs to
 * determine the order of.
 *
 * This is what we do here, we use the sortChildrenCB method and provide on own
 * comparsion method, rexxSort().
 *
 * We sort the children of the selected item.  If no item is selected we sort
 * the children of the root item.  Note that only the direct children of the
 * parent item are sorted.
 */
::method onSortChildren unguarded
    expose tv

    selectedItem = tv~SelectedNode
    if selectedItem == .nil then selectedItem = root(tv)

    ret = self~sortChildrenCB(tv, selectedItem, rexxSort)   -- ooDialog: tv~sortChildrenCB(selectedItem, rexxSort)


/** rexxSort()
 *
 * This is our comparison callback function.  We are passed the user item data
 * for the first tree-view item and the user item data for the second tree-view
 * item.  The method needs to return a positive number if the first item is
 * greater than the second, a negative number if the first item is less than the
 * second, and 0 if the two items are equivalent.
 *
 * In this program, for every tree-view item inserted, we set the item data for
 * that item to be the text of the item.  Then, in our comparison function here,
 * we just do a reverse comparison of that text.  This orders the items in
 * descending order rather than ascending order.  The userParam argument is
 * ignored here.
 */
::method rexxSort unguarded
    use arg itemData1, itemData2, userParam

    -- Reverse sort:
    return itemData2~compareTo(itemData1)


/** onExpandAll()
 *
 * This is the event handler for the 'Expand All' push button.  This method is
 * invoked when the user clicks that button.
 *
 * We expand the selected item and all its children recursively.
 */
::method onExpandAll unguarded
    expose tv

    if tv~SelectedNode == .nil then do
        title = self~APPLICATION_TITLE~subword(1, 3) '- Error'
        msg   = "There is no tree-view item selected.  Before" || .endOfLine ||-
                "you can expand all items you must first"      || .endOfLine ||-
                "select an item"
        ret = MessageDialog(msg, self~hwnd, title, 'OK', 'WARNING')
        return 0
    end

    if self~isFullyExpanded(tv~SelectedNode) then do
        title = self~APPLICATION_TITLE~subword(1, 3) '- Information'
        msg   = "The selected tree-view item is already fully" || .endOfLine ||-
                "expanded.  Expanding will take place, but it" || .endOfLine ||-
                "have no visile effect."
        ret = MessageDialog(msg, self~hwnd, title, 'OK', 'WARNING')
    end

    self~expandAll(tv~SelectedNode)
return 0


/** onCollapseAll()
 *
 * This is the event handler for the 'Collapse All' push button.  This method is
 * invoked when the user clicks that button.
 *
 * We collapse the selected item and all its children recursively.
 */
::method onCollapseAll unguarded
    expose tv

    if tv~SelectedNode == .nil then do
        title = self~APPLICATION_TITLE~subword(1, 3) '- Error'
        msg   = "There is no tree-view item selected.  Before"  || .endOfLine ||-
                "you can collapse all items you must first"     || .endOfLine ||-
                "select an item"
        ret = MessageDialog(msg, self~hwnd, title, 'OK', 'WARNING')
        return 0
    end

    itemInfo. = itemInfo(tv~SelectedNode)
    if itemInfo.!State~wordPos('EXPANDED') == 0 then do
        title = self~APPLICATION_TITLE~subword(1, 3) '- Information'
        msg   = "The selected tree-view item is already collapsed.  You"  || .endOfLine || -
                "may not see anything, but all children of the selected"  || .endOfLine || -
                "item will be collapsed."
        ret = MessageDialog(msg, self~hwnd, title, 'OK', 'INFORMATION')
    end

    self~collapseAll(tv~SelectedNode)
return 0


/** onItemInfo
 *
 * This is the event handler for the 'Item Info' push button.  It iw invoked
 * when the button is clicked.
 *
 * We get the selected tree-view item and display information about it.
 */
::method onItemInfo unguarded
    expose tv

    selected  = tv~SelectedNode
    if selected == .nil then do
        title = self~APPLICATION_TITLE~subword(1, 3) '- Error'
        msg   = "There is no tree-view item selected.  Before"  || .endOfLine ||-
                "you can display information on an item you"    || .endOfLine ||-
                "must first select an item"
        ret = MessageDialog(msg, self~hwnd, title, 'OK', 'WARNING')
        return 0
    end

    itemInfo. = itemInfo(selected)

    tab1      = '09'x
    tab2      = tab1~copies(2)

    hasChildren = self~logicalToString(itemInfo.!Children)

    title = self~APPLICATION_TITLE~changeStr('-', '') '- Item Information'
    msg   = 'The Selected Item is:'    || tab1 || '"'itemInfo.!Text'"'     || .endOfLine~copies(2) || -
            '  Contains children:'     || tab2 || hasChildren              || .endOfLine || -
            '  Unselected icon index:' || tab1 || itemInfo.!Image          || .endOfLine || -
            '  Selected icon index:'   || tab2 || itemInfo.!SelectedImage  || .endOfLine || -
            '  Item state:'            || tab2 || itemInfo.!State          || .endOfLine || -
            '  Is leaf node:'          || tab2 || self~logicalToString(.InventoryDlg~isLeafItem(tv, selected))

    ret = MessageDialog(msg, self~hwnd, title 'OK', 'INFORMATION')
return 0


/** help()
 *
 * The help command event handler is connected automatically by the ooDialog
 * framework to the command with ID of 9.  The default help event handler
 * provided by ooDialog does nothing.
 *
 * In this example, the Help push button is given the resource ID of 9, and
 * therefore the help event handler is invoked when the user clicks on the Help
 * button.  Rather than do noting when the button is clicked, we over-ride the
 * help method here.  We still do not do much, just inform the user that there
 * is no help.
 */
::method help unguarded
    title = self~APPLICATION_TITLE
    msg   = "There is no help available for this example program."
    ret =  MessageDialog(msg, self~hwnd, title, "OK", "INFORMATION")
return 0


/*- - - - - - - - - - Helper Methods - - - - - - - - - - - - - - - - - - - - -*/

/** expandAll()
 *
 * This helper method recursively expands all children nodes of the specified
 * tree-view item.
 */
::method expandAll private unguarded
    expose tv
    use strict arg item

    if item == .nil then return 0

    item~Expand                                             -- ooDialog: tv~expand(item)
    nextItem = child(item)
    do while nextItem \== .nil
        self~expandAll(nextItem)
        nextItem = nextItem~NextNode                        -- ooDialog: tv~next(nextItem)
    end
return 0


/** collapseAll()
 *
 * This helper method recursively collapse the specified tree-view item and all
 * its children.
 */
::method collapseAll private unguarded
    expose tv
    use strict arg item

    if item == .nil then return 0

    nextItem = child(item)
    do while nextItem \== .nil
        self~collapseAll(nextItem)
        nextItem = nextItem~NextNode
    end
    item~Collapse(.true)                                    -- ooDialog: tv~collapse(item) (the children are done)
return 0


/** isFullyExpanded()
 *
 * This helper method checks if the specified item is fully expanded by
 * recursively descending though the children of the item and checking that each
 * item is expanded.
 *
 * Returns .true if the item is fully expanded, otherwise .false.
 */
::method isFullyExpanded private unguarded
    expose tv
    use strict arg item

    if item == .nil then return .true
    if .InventoryDlg~isLeafItem(tv, item) then return .true

    itemInfo. = itemInfo(item)
    if itemInfo.!State~wordPos('EXPANDED') == 0 then return .false

    nextItem = child(item)
    do while nextItem \== .nil
        if \ self~isFullyExpanded(nextItem) then return .false
        nextItem = nextItem~NextNode
    end
return .true


/** checkForRequiredFiles()
 *
 * This helper method is used to check that the bitmap and input files are
 * available.  It returns .true if they are found and .false if they are not
 * found.
 */
::method checkForRequiredFiles private

    haveError = .false
    file = ''

    if stream(self~BMP_FILE, "C", "QUERY EXISTS") = "" then do
      haveError = .true
      file = self~BMP_FILE
    end
    else if stream(self~TREE_FILE, "C", "QUERY EXISTS") = "" then do
      haveError = .true
      file = self~TREE_FILE
    end
    else if stream(self~ITEM_FILE, "C", "QUERY EXISTS") = "" then do
        haveError = .true
        file = self~ITEM_FILE
    end

    if haveError then do
        title = self~APPLICATION_TITLE~subword(1, 3) '- File Error'
        msg   = "The required data file" file                     || .endOfLine || -
                "does not exist.  Without that file, this progam" || .endOfLine || -
                "will not run."                                   || .endOfLine~copies(2) || -
                "The program will abort."
        ret = MessageDialog(msg, 0, title, 'OK', 'ERROR')
    end

return \haveError


/** makeArgs()
 *
 * This helper method turns a line of comma separted values into an argument
 * array with empty values turned into empty indexes in the array.
 */
::method makeArgs private unguarded

    if arg() == 1 then line = arg(1)
    else line = arg(3)

    args = line~makeArray(',')

    if arg() == 1 then do
        newArgs = .array~new(args~items)
        do i = 1 to args~items
            if args[i]~strip \== "" then newArgs[i] = args[i]~strip('B', '"')
        end
    end
    else do
        newArgs = .array~new(args~items + 2)
        newArgs[1] = arg(1)
        newArgs[2] = 'LAST'
        j = 2
        do i = 1 to args~items
            j += 1
            if args[i]~strip \== "" then newArgs[j] = args[i]~strip('B', '"')
        end
    end

return newArgs


/** logicalToString()
 *
 * This helper method converts and returns a value to true or false if value is
 * a logical, otherwise it returns the empty string.
 */
::method logicalToString private
    use strict arg logical

    if logical == .true then return 'True'
    else if logical == .false then return 'False'
    else return ''


/** print()
 *
 * This helper function is useful in debugging.  It prints the label of the
 * specified tree-view item to the screen.
 */
::method print private unguarded
    expose tv
    use strict arg item, indent

    itemInfo. = itemInfo(item);
    say indent || itemInfo.!Text
return 0


/* - - - - - - - - - - (.NET version) ooDialog's TreeView add, insert and
   sortChildrenCB: a TreeNode, its info tip from onGetInfoTip */

/* add(tv, args): ooDialog's tv~add(): the text in the position of its level
   (1: a root; else a child of the last item added one level up), then the
   image, the selected image, the options (BOLD, EXPANDED: expanded once the
   tree is full), the children (1: it has some, to be added later), the item
   data */
::method add private unguarded
    use strict arg tv, args
    level = 1
    do while \args~hasIndex(level), level < args~size; level += 1; end
    if level = 1 then do
        .local~treeLastNodes = .array~new
        if \.local~hasIndex("TREETOEXPAND") then .local~treeToExpand = .array~new
        parent = .nil
    end
    else parent = .treeLastNodes[level - 1]
    node = self~newNode(tv, parent, args, level)
    .treeLastNodes[level] = node
    return node

/* insert(tv, args): ooDialog's tv~insert(parent, after, text, image,
   selectedImage, options, children, itemData) */
::method insert private unguarded
    use strict arg tv, args
    rest = .array~new
    do i = 3 to args~size; if args~hasIndex(i) then rest[i - 2] = args[i]; end
    return self~newNode(tv, args[1], rest, 1)

::method newNode private unguarded
    use strict arg tv, parent, args, at
    text = args[at]
    if parent == .nil then node = tv~Nodes~Add(text)
    else node = parent~Nodes~Add(text)
    node~Name = text                                        -- (find's key)
    if args~hasIndex(at + 1) then node~ImageIndex = args[at + 1]
    if args~hasIndex(at + 2) then node~SelectedImageIndex = args[at + 2]
    opts = ""; if args~hasIndex(at + 3) then opts = args[at + 3]
    if args~hasIndex(at + 4), args[at + 4] = 1 then call addPlaceholder node
    if args~hasIndex(at + 5) then node~Tag = args[at + 5]
    if opts~caselessWordPos("BOLD") > 0 then node~NodeFont = .net~System~Drawing~Font~new(tv~Font, .net~System~Drawing~FontStyle~Bold)
    if opts~caselessWordPos("EXPANDED") > 0 then .treeToExpand~append(node)
    node~ToolTipText = self~onGetInfoTip(IDC_TREE, node, text, 260, node~Tag)   -- (TVS_INFOTIP: GETINFOTIP's answer)
    return node

/* sortChildrenCB(tv, item, method): the item's children in the order the
   method gives, comparing their item data (ooDialog's sortChildrenCB) */
::method sortChildrenCB private unguarded
    use strict arg tv, item, methodName
    nodes = item~Nodes
    kids = nodes~makeArray
    if kids~items < 2 then return 0
    kids~sortWith(.ItemDataComparator~new(self, methodName))
    tv~BeginUpdate
    nodes~Clear
    do k over kids; nodes~Add(k); end
    tv~EndUpdate
    return 0

::method autoRun                       -- (.NET version) unattended: the buttons, Special Offers expanded and collapsed, a new item; Close
    expose tv
    say "(auto)" tv~GetNodeCount(.true) "items; selected:" tv~SelectedNode~Text", its info tip '"tv~SelectedNode~ToolTipText"'"
    dots = find(tv, '...')
    say "(auto) the info tip of '...':" dots~ToolTipText
    self~onItemInfo
    self~onSortChildren
    say "(auto) Computers' children, reverse sorted:" childTexts(tv~SelectedNode)
    self~onExpandAll
    self~onCollapseAll
    special = find(tv, 'Special Offers')
    say "(auto) Special Offers before:" special~Nodes~Count "child (the placeholder)"
    special~Expand
    say "(auto) expanded:" childTexts(special)
    special~Collapse
    say "(auto) collapsed:" special~Nodes~Count "child"
    tv~SelectedNode = find(tv, 'Digital Watch')
    self~onNewItem
    say "(auto) after Digital Watch:" find(tv, 'Digital Watch')~NextNode~Text
    self~onDeleteItem
    say "(auto) deleted the selected item:" (find(tv, 'Digital Watch') == .nil)
    self~cancel


/*- NewTreeItemDlg - Class- - - - - - - - - - - - - - - - - - - - - - - - - - *\

   This dialog class allows the user to add a new item to the tree-view

\*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
::class 'NewTreeItemDlg' subclass TreeViewCustomDraw_IDD_ADD_TREE_ITEM inherit TreeViewConstants

/** init()
 *
 * The initialization of the Rexx dialog object.  We just use this to grab a
 * reference to the tree-view control in the parent dialog.
 */
::method init
  expose treeControl
  use arg treeControl

  -- Initialize the super class.
  self~init:super


/** initDialog()
 *
 * The initialization of the Windows dialog.  We use this to set the state of
 * the various controls in the dialog.
 */
::method initDialog
    expose treeControl editControl childRB folderChk selected

    -- Save a reference to the current selected item
    selected = treeControl~SelectedNode

    editControl = self~newEdit(IDC_EDIT_NAME)
    childRB     = self~newRadioButton(IDC_RB_CHILD)
    siblingRB   = self~newRadioButton(IDC_RB_SIBLING)
    folderChk   = self~newCheckBox(IDC_CHK_FOLDER)

    -- If the selected is the root of the tree, a new item has to be inserted as
    -- a child.  So disable the radio buttons that allow the user to choose to
    -- insert as a child or sibling.  And, pre-check the add as a folder check
    -- box.
    if sameNode(selected, root(treeControl)) then do
        childRB~Checked = .true; childRB~Enabled = .false   -- ooDialog: childRB~~check~disable
        siblingRB~Enabled = .false
        folderChk~Checked = .true
    end
    else if .InventoryDlg~isLeafItem(treeControl, selected) then do
        siblingRB~Checked = .true; siblingRB~Enabled = .false
        childRB~Enabled = .false
    end
    else do
        siblingRB~Checked = .true
    end

    -- Set a visual cue for the edit control.  This will only show when the edit
    -- control has no text in it, and does not have the focus.
    editControl~PlaceholderText = "Enter name of new item"  -- ooDialog: editControl~setCue(...)

return 0


/** ok()
 *
 * The is the event handler for the Ok button.  It is invoked when the user
 * clicks that button.
 *
 * Here we over-ride the superclass ok method so that we can check that the user
 * entered the correct data for the new item and then insert it into the tree-
 * view.  If the user did not enter the data correctly, we giver her a chance to
 * correct it.  We give her a chance to cancel and if she does, we end the
 * dialog cancel instead of ok.
 *
 * Note that we end the dialog by either calling the superclass ok or cancel
 * method.  We prevent the dialog from closing by *not* invoking one of those
 * methods and simply returning.
 */
::method ok
    expose treeControl editControl childRB folderChk selected

    -- Make sure the user has given the item a name.
    text = editControl~Text~strip
    if text == "" then do
        msg   = "You must enter the name of the new item"
        title = self~APPLICATION_TITLE~changestr('-', '') '- Add Item'
        ret = MessageDialog(msg, self~hwnd, title, 'WARNING', 'OKCANCEL')
        if ret == self~IDCANCEL then return self~cancel:super
        editControl~Focus                                   -- ooDialog: editControl~assignFocus
        return 0
    end

    -- See if the user wants to add this as a folder item, or a regular item.
    -- This will determine the image IDs we use when we insert the item
    addAsFolder = folderChk~Checked

    -- Now insert the item either as a child or a sibling depending on what the
    -- user requested. Note that we set the item data on each insert to the text
    -- of the inserted item.  (.NET version: a sibling goes after the selected
    -- item, at the end in ooDialog's LAST... here as the original: under the
    -- parent, at the end)
    if addAsFolder then images = .array~of(self~UNSELECTED_FOLDER, self~SELECTED_FOLDER)
    else images = .array~of(self~UNSELECTED_LEAF, self~SELECTED_LEAF)
    if childRB~Checked then do
        newItem = addNode(treeControl, selected, text, images, text)   -- ooDialog: treeControl~insert(selected, , text, ..., text)
        newItem~Parent~Expand                               -- ooDialog: treeControl~expand(treeControl~parent(newItem))
    end
    else do
        newItem = addNode(treeControl, selected~Parent, text, images, text)   -- ooDialog: treeControl~insert(treeControl~Parent(selected), ...)
    end

    -- Finally, quit by invoking the super class ok() method.
return self~ok:super

::method autoRun                       -- (.NET version) unattended: a new item, a sibling of the one selected
    self~newEdit(IDC_EDIT_NAME)~Text = "Smart Watch"
    say "(auto) new item: sibling" self~newRadioButton(IDC_RB_SIBLING)~Checked", folder" self~newCheckBox(IDC_CHK_FOLDER)~Checked
    self~ok


/* - - - - - - - - - - (.NET version) ooDialog's TreeView methods, on TreeNodes */

::class ItemDataComparator             -- sortWith's comparator: the dialog's method on the item data
::method init
  expose dialog methodName
  use strict arg dialog, methodName
::method compare
  expose dialog methodName
  use strict arg a, b
  return dialog~send(methodName, a~Tag, b~Tag, .nil)

::class VK                             -- ooDialog's .VK: virtual key codes
::constant INSERT 45
::constant DELETE 46

/* itemInfo(node): ooDialog's tv~itemInfo, a stem: !Text, !Image,
   !SelectedImage, !State (EXPANDED, SELECTED, BOLD...), !Children */
::routine itemInfo
  use strict arg node
  info.!Text = node~Text
  info.!Image = node~ImageIndex
  info.!SelectedImage = node~SelectedImageIndex
  state = ""
  if node~IsExpanded then state = state "EXPANDED"
  if node~IsSelected then state = state "SELECTED"
  if node~NodeFont \== .nil then if node~NodeFont~Bold then state = state "BOLD"
  info.!State = state~strip
  info.!Children = node~Nodes~Count > 0
  return info.

::routine child                        -- the first child, or .nil (a placeholder is none)
  use strict arg node
  c = node~FirstNode
  if c \== .nil, c~Tag == "(placeholder)" then return .nil
  return c

::routine root                         -- ooDialog's tv~root: the first item
  use strict arg tv
  if tv~Nodes~Count = 0 then return .nil
  return tv~Nodes[0]

::routine find                         -- ooDialog's tv~find(text): the item, or .nil
  use strict arg tv, text
  found = tv~Nodes~Find(text, .true)
  if found~items = 0 then return .nil
  return found[1]                      -- (a .NET array is a Rexx Array: from 1)

::routine delete                       -- ooDialog's tv~delete(item); none: all of them
  use strict arg tv, node
  if node == .nil then tv~Nodes~Clear
  else node~Remove

::routine addNode                      -- a new node under parent (.nil: a root) with its images and item data
  use strict arg tv, parent, text, images, data
  if parent == .nil then node = tv~Nodes~Add(text)
  else node = parent~Nodes~Add(text)
  node~Name = text
  node~ImageIndex = images[1]
  node~SelectedImageIndex = images[2]
  node~Tag = data
  return node

::routine addPlaceholder               -- children to come: a plus sign (Windows' cChildren)
  use strict arg node
  p = node~Nodes~Add("")
  p~Tag = "(placeholder)"

::routine removePlaceholder
  use strict arg node
  c = node~FirstNode
  if c \== .nil, c~Tag == "(placeholder)" then c~Remove

::routine collapseAndReset             -- ooDialog's collapseAndReset: collapsed, its children gone (still a plus sign)
  use strict arg node
  node~Nodes~Clear
  call addPlaceholder node

::routine expandAdded                  -- the items added EXPANDED, now that they have children
  if \.local~hasIndex("TREETOEXPAND") then return
  do node over .treeToExpand
    node~Expand
  end

::routine sameNode                     -- whether two nodes (or .nil) are the same
  use arg a, b
  if a == .nil | b == .nil then return a == .nil & b == .nil
  return a~Equals(b)

::routine childTexts                   -- (unattended) the texts of a node's children
  use strict arg node
  t = ""
  do i = 0 to node~Nodes~Count - 1
    t = t"," node~Nodes[i]~Text
  end
  return t~substr(3)
