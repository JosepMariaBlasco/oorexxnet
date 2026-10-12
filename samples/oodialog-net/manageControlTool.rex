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
 * This example demonstrates several advanced techniques in using ToolTips.
 *
 * Typically a single tool is created for a dialog control.  This works fine
 * for creating tools for, say, buttons.  Even if you have 20 buttons, it is
 * pretty reasonable to create 20 tools in a ToolTip.
 *
 * But, what if you want to display a tip for each item in a tree-view?  What if
 * the tree-view has hundreds, or even thousands, of items.  Creating several
 * thousand tools is no longer reasonable.  One technique is to create one tool
 * and dynamically make it appear to be multiple tools.
 *
 * That technique is demonstrated in this example.  We use a tree-view control
 * to show the technique.  The basic principle is to track where the mouse is,
 * and dynamically update the tool each time it moves from one item to another.
 *
 * Note that in this specific case, there is an easier way to produce the same
 * results as this example does.  The customPositionToolTip.rex example shows
 * how to use the easier method.  However, this example is very useful in
 * showing how the manageAtypicalToo() works.  The principles here can be used
 * in other situations.
 *
 * (.NET version of ooDialog's controls\ToolTip\manageControlTool.rex, on
 * Windows Forms through oodnet.cls; the .rc is manageControlToolrc.cls,
 * written by rc2oodnet.rex -cls. ooDialog's manageAtypicalTool watches the
 * tree-view's mouse messages and relays them to the ToolTip, calling the
 * dialog's onRelay first, and sends it the ToolTip's NEEDTEXT and SHOW. In
 * .NET the tree-view's own events are ours already: its MouseMove is the
 * relay, and the ToolTip's part, waiting while the mouse rests and then
 * showing the tip, is a Timer of the ToolTip's InitialDelay, whose tick
 * asks onNeedText for the text and onShow for the place (ToolTip.Show). An
 * item's data, the text of its tip, is the node's Tag. customPositionToolTip
 * here does the same with the tree-view's NodeMouseHover.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

  dlg = .TreeViewDialog~new                               -- ooDialog: .TreeViewDialog~new(sd'manageControlTool.rc', IDD_TREEVIEW)
  dlg~execute("SHOWTOP")


::requires "manageControlToolrc.cls"

::class 'TreeViewDialog' subclass ManageControlTool_IDD_TREEVIEW

::method initDialog
  expose currentItem currentLocation currentText tt tv delay

  -- These variables are used to help track which tool needs to be shown.
  currentItem = .nil
  currentText = ''
  currentLocation = 'NOWHERE'

  tv = self~newTreeView(IDC_TREE)

  -- Set up our ToolTip (.NET version: one ToolTip, shown by onShow; no tool
  -- of its own, so it never shows by itself)
  tt = .net~System~Windows~Forms~ToolTip~new                -- ooDialog: self~createToolTip(IDC_TT), a tool for the tree's client area

  -- Set up our tree-view and populate it.
  tv~ItemHeight = 20                                        -- ooDialog: tv~setItemHeight(20)
  self~populateTree(tv)

  -- Now start the monitoring process.  (.NET version: the tree-view's mouse
  -- events, and the ToolTip's wait.)
  delay = .net~System~Windows~Forms~Timer~new
  delay~Interval = tt~InitialDelay
  delay~Tick += .net~handler(self, "ONDELAY")
  tv~MouseMove += .net~handler(self, "ONRELAY")             -- ooDialog: tt~manageAtypicalTool(tv, .array~of('RELAY', 'NEEDTEXT', 'SHOW'))
  tv~MouseLeave += .net~handler(self, "ONRELAY")


/** onRelay()
 *
 * This is the event handler for the mouse message relaying event.  It is
 * invoked by our monitoring process for every mouse message.  (.NET version:
 * every MouseMove of the tree-view, and its MouseLeave: then nowhere.)
 *
 * This method is crucial to how this example works.  For every mouse message,
 * we calculate if the mouse is still over the label of the same item it was
 * over previously.  If it is not, we hide the ToolTip window by invoking the
 * pop().
 *
 * After we return form this method, the ToolTip waits for the mouse to rest
 * (.NET version: the delay Timer, started again).  When the mouse has hovered
 * long enough in one spot, the tip is displayed.  Since we have set the
 * current text to the string for the tree-view item when the mouse first
 * moved over the item, the correct "tool" text is displayed.
 *
 * The text to display is actually passed on to the ToolTip from our onNeedTex()
 * method.
 */
::method onRelay unguarded
    expose currentItem currentText currentLocation tt delay
    use arg treeView, e

    -- Determine which, if any, item the mouse is over.
    if .net~isInstance(e, "System.Windows.Forms.MouseEventArgs") then do
        d = treeView~HitTest(e~Location)                    -- ooDialog: treeView~hitTestInfo(pos)
        item = d~Node
        location = d~Location~string
    end
    else do                                                 -- (MouseLeave)
        item = .nil
        location = 'NOWHERE'
    end

    -- Save the old item and location and sent the current item and location to
    -- where the mouse is at this moment.
    oldItem = currentItem
    oldLocation = currentLocation
    currentItem = item
    currentLocation = location

    -- If mouse is over a new item or location, hide the ToolTip.  Set our
    -- current text to the text for the item we are now over.  If we are not
    -- over the label of an item, set the current text to the empty string.
    if \sameNode(oldItem, currentItem) | oldLocation \== currentLocation then do
        if currentItem \== .nil, currentLocation~pos('Label') <> 0 then do
            currentText = currentItem~Tag                   -- ooDialog: treeView~getItemData(currentItem)
        end
        else do
            currentText = ''
        end
        tt~Hide(treeView)                                   -- ooDialog: toolTip~pop
        delay~Stop
        delay~Start                                         -- (.NET version) the ToolTip's wait
    end

    return 0


/** onDelay()
 *
 * (.NET version) The mouse has rested: what the ToolTip does then, asking
 * for the text (NEEDTEXT) and letting us place the tip (SHOW).
 */
::method onDelay unguarded
    expose tt tv delay
    delay~Stop
    info = .directory~new
    self~onNeedText(tt, tv, info)
    if info~text == '' then return
    if \self~onShow(tt, tv, info~text) then do               -- (where a ToolTip puts it: below the mouse)
        p = tv~PointToClient(.net~System~Windows~Forms~Cursor~Position)
        tt~Show(info~text, tv, p~X, p~Y + 20, tt~AutoPopDelay)
    end


/** onNeedText()
 *
 * This is the event handler for the ToolTip's NEEDTEXT event notification.
 *
 * The real work was already done in the onRelay() method.  All we need to do is
 * set the TEXT index in the info .Directory object to what the onRelay() method
 * set the current text to.
 */
::method onNeedText unguarded
    expose currentItem currentText
    use arg toolTip, treeView, info

    info~text = currentText

    -- Return false so that the ToolTip does not store the text.  We want it to
    -- always ask us for the text because the mouse could be over any item.
    return .false



/** onShow()
 *
 * This is our event handler for the ToolTip's SHOW event notification.
 *
 * Normally the ToolTip places its window below the tree-view item.  This often
 * over-laps and obscures the other items.  What we want is to place the ToolTip
 * window to the right and centered with the item.  This way nothing is
 * obscured.
 *
 * The custom positioning of the ToolTip window is straight-forward.  We get the
 * bounding rectangle of the tree-view item's label and show the tip there
 * (.NET version: ToolTip.Show, in the tree-view's client coordinates).
 *
 * Note that we must return .true then so that the ToolTip is informed not to
 * position the window in its default position.
 */
::method onShow unguarded
    expose currentItem
    use arg toolTip, treeView, text

    if currentItem \== .nil then do
        r = currentItem~Bounds                              -- ooDialog: treeView~getItemRect(currentItem, r)

        toolTip~Show(text, treeView, r~Right + 5, r~Top, toolTip~AutoPopDelay)
        return .true
    end

    return .false


/** populateTree()
 *
 * This is a private method used to populate the tree-view control with our
 * items.
 *
 * Note that each item has an item data object assigned to it.  In this case the
 * object is a string.  The string is the text to display for the tool tip for
 * that item.  (.NET version: the node's Tag.)
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

::method autoRun                       -- (.NET version) unattended: the mouse onto Mike's label, the wait, the tip; OK
    expose tv tt currentText
    WF = .net~System~Windows~Forms
    node = tv~Nodes[0]~Nodes[0]        -- Mike
    r = node~Bounds
    self~onRelay(tv, WF~MouseEventArgs~new("None", 0, r~X + 3, r~Y + r~Height % 2, 0))
    say "(auto) over" node~Text": current text" currentText
    self~onDelay
    say "(auto) shown right of" r~Right": active" tt~Active
    self~onRelay(tv, .net~System~EventArgs~Empty)
    say "(auto) left the tree: current text '"currentText"'"
    self~ok

/* (.NET version) whether two nodes (or .nil) are the same */
::routine sameNode
    use arg a, b
    if a == .nil | b == .nil then return a == .nil & b == .nil
    return a~Equals(b)

/* (.NET version) ooDialog's tv~add: a node at a level (1: a root; else a
   child of the last node added one level up), its options (BOLD, EXPANDED:
   expanded once the tree is full, by expandAdded) and its data, the tip */
::routine add
    use arg tv, level, text, opts = "", data = ""
    if level = 1, tv~Nodes~Count = 0 then do
        .local~treeLastNodes = .array~new
        .local~treeToExpand = .array~new
    end
    last = .treeLastNodes
    if level = 1 then node = tv~Nodes~Add(text)
    else node = last[level - 1]~Nodes~Add(text)
    node~Tag = data                     -- ooDialog: the item's data
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
