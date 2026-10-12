/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2012-2014 Rexx Language Association. All rights reserved.    */
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
 * ToolTip control example.
 *
 * This example demonstrates use info tips with a tree-view and do custom
 * positiong of the tool tip.
 *
 * Normally the ToolTip window is placed below the item.  This often over-laps
 * and obscures the other items.  What we want is to place the ToolTip window to
 * the right and centered with the item.  This way nothing is obscured.
 *
 * (.NET version of ooDialog's controls\ToolTip\customPositionToolTip.rex, on
 * Windows Forms through oodnet.cls: customPositionToolTip.rc's dialog is
 * CustomPositionToolTip_IDD_TREEVIEW, from customPositionToolTiprc.cls. A
 * .NET TreeView's own tool tips (ShowNodeToolTips) go where the TreeView
 * puts them; to place one, a ToolTip of our own is shown where we want it
 * (ToolTip.Show(text, control, x, y)) when the mouse rests on a node (the
 * TreeView's NodeMouseHover event, which says which node: ooDialog's
 * GETINFOTIP, then the ToolTip's SHOW, intercepted with manageAtypicalTool).
 * Each node's tip text is its ToolTipText (the original's item data). The
 * nodes are added by level with the routine add below (ooDialog's tv~add,
 * whose leading omitted arguments give the level).)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

  dlg = .TreeViewDialog~new            -- ooDialog: .TreeViewDialog~new(sd'customPositionToolTip.rc', IDD_TREEVIEW)
  dlg~execute("SHOWTOP")

::requires "customPositionToolTiprc.cls"

::class 'TreeViewDialog' subclass CustomPositionToolTip_IDD_TREEVIEW

::method initDialog
  expose tv tip

  tv = self~newTreeView(IDC_TREE)
  tv~ItemHeight = 20                   -- ooDialog: tv~setItemHeight(20)

  self~populateTree(tv)

  -- (.NET version) Our own ToolTip, shown by onHover where we want it, and
  -- hidden when the mouse leaves the node.
  tip = .net~System~Windows~Forms~ToolTip~new
  tv~NodeMouseHover += .net~handler(self, "ONHOVER")
  tv~MouseMove += .net~handler(self, "ONMOVE")
  tv~MouseLeave += .net~handler(self, "ONLEAVE")

/** onHover()
 *
 * (.NET version) The mouse rests on a node: we show its tip, to the right of
 * the node's label and centered with it (ooDialog: onGetInfoTip gives the
 * text, onShow places the window).  The node's Bounds are already in the
 * tree-view's client coordinates.
 */
::method onHover unguarded
    expose tip currentNode
    use arg treeView, e

    node = e~Node
    if currentNode \== .nil, node~Equals(currentNode) then return
    currentNode = node
    r = node~Bounds
    h = .net~System~Windows~Forms~TextRenderer~MeasureText(node~ToolTipText, treeView~Font)~Height + 6
    tip~Show(node~ToolTipText, treeView, r~Right + 5, r~Top + (r~Height - h) % 2)

/** onMove(), onLeave()
 *
 * (.NET version) The tip goes away when the mouse is no longer on its node.
 */
::method onMove unguarded
    expose tip currentNode
    use arg treeView, e
    if currentNode == .nil then return
    node = treeView~GetNodeAt(e~Location)
    if node == .nil | \currentNode~Equals(node) then self~onLeave(treeView, e)

::method onLeave unguarded
    expose tip currentNode
    use arg treeView, e
    if currentNode \== .nil then tip~Hide(treeView)
    currentNode = .nil

::method init
    expose currentNode
    forward class (super) continue
    currentNode = .nil

/** populateTree()
 *
 * This is a private method used to populate the tree-view control with our
 * items.
 *
 * Note that each item has its tip text assigned to it (.NET version: its
 * ToolTipText; ooDialog: its item data).
 */
::method populateTree private
    use strict arg tv

    call add tv, 1, "Peter", "BOLD EXPANDED", 'Data unique to Peter.'
    call add tv, 2, "Mike", "EXPANDED", 'Mike talks a lot.'
    data = 'George was famous once.'.endOfLine'He is unknown to my'.endOfLine'niece.'
    call add tv, 3, "George", , data
    call add tv, 3, "Monique", , 'Monique has never been to France.'
    call add tv, 4, "John", , 'John owns 4 dogs.'
    call add tv, 3, "Chris", , 'Chris will never be president.'
    call add tv, 2, "Maud", , 'Maud likes to bake.'
    call add tv, 2, "Ringo", , 'Ringo has a LOT of money.'
    call add tv, 1, "Paul", "BOLD EXPANDED", "Two roads lead to Paul's house."
    call add tv, 2, "Dave", , 'No one lives with Dave.'
    call add tv, 2, "Sam", , 'Sam loves pizza.'
    call add tv, 2, "Jeff", , 'Jeff rides his bike to work.'
    call add tv, 1, "Mary", "BOLD EXPANDED", 'Mary owes $49.50 to her dentist.'
    call add tv, 2, "Helen", , 'A closer look at Helen is warranted.'
    call add tv, 2, "Michelle", , 'The Toyota Camray belongs to Michelle.'
    call add tv, 2, "Diana", , 'Go go Chargers.'
    call expandAdded

::method autoRun                       -- (.NET version) unattended: the tip of a node, where it goes, then OK
    expose tv tip
    node = tv~Nodes[0]~Nodes[0]        -- Mike
    say "(auto)" tv~GetNodeCount(.true) "nodes; Mike's tip:" node~ToolTipText "- Peter bold:" tv~Nodes[0]~NodeFont~Bold
    self~onHover(tv, .net~System~Windows~Forms~TreeNodeMouseHoverEventArgs~new(node))
    say "(auto) shown right of" node~Bounds~Right": active" tip~Active
    self~onLeave(tv, .nil)
    self~ok

/* (.NET version) ooDialog's tv~add: a node at a level (1: a root; else a
   child of the last node added one level up), its options (BOLD, EXPANDED:
   expanded once the tree is full, by expandAdded) and its tip */
::routine add
    use arg tv, level, text, opts = "", tipText = ""
    if level = 1, tv~Nodes~Count = 0 then do
        .local~treeLastNodes = .array~new
        .local~treeToExpand = .array~new
    end
    last = .treeLastNodes
    if level = 1 then node = tv~Nodes~Add(text)
    else node = last[level - 1]~Nodes~Add(text)
    node~ToolTipText = tipText
    if opts~caselessWordPos("BOLD") > 0 then do
        node~NodeFont = .net~System~Drawing~Font~new(tv~Font, .net~System~Drawing~FontStyle~Bold)
        node~Text = text                -- (again: the label is measured anew, in bold, not clipped)
    end
    last[level] = node
    if opts~caselessWordPos("EXPANDED") > 0 then .treeToExpand~append(node)

::routine expandAdded                  -- (.NET version) the nodes added EXPANDED, now that they have children
    do node over .treeToExpand
        node~Expand
    end
