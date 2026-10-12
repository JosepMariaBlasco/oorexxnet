/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2013-2014 Rexx Language Association. All rights reserved.    */
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
 * An example of a custom implmentation of an incremental search in a ListBox.
 *
 * The list box has its own function that does an incremental search of the
 * items in the list box.  When a character is typed, the list box:
 *
 * "Moves the selection to the first item that begins with the character the
 * user typed.  Multiple characters typed within a short interval are treated as
 * a group, and the first item that begins with that series of characters is
 * selected."
 *
 * One common problem is that the "short interval" is too short.
 *
 * This example makes that short interval longer.  It also adds some custom
 * features.  The user can reset the search by typing the Del key.  The user
 * can also back up the search by one character by using the BackSpace key.
 *
 * (.NET version of ooDialog's controls\ListBox\incrementalSearch.rex, on
 * Windows Forms through oodnet.cls. The typed characters come in the
 * ListBox's KeyPress event, which we mark Handled so that the ListBox does not
 * search by itself (ooDialog: connectCharEvent, onChar returning .false), the
 * Del key in KeyDown; .NET's ListBox counts its items from 0: FindString,
 * SelectedIndex (-1: none selected), TopIndex (makeFirstVisible). The search
 * expires with a Windows Forms Timer (ooDialog: an .Alarm). The list is the
 * directory C:\Windows\System32, its directories in brackets, as the list
 * box's own LB_DIR (ooDialog: addDirectory) shows them.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .SimpleDialog~new
    if dlg~initCode = 0 then do
        if dlg~execute("SHOWTOP") == dlg~IDOK then do
            say 'User searched for and found:' dlg~searchAndFound
        end
        else do
            say 'User canceled'
        end
    end

return 0
-- End of entry point.

::requires "oodnet.cls"

::class 'SimpleDialog' subclass NetDialog

::constant expiration  7  -- Time between keystrokes before the search string is
                          -- reset.  If the user does not type any keys within
                          -- this amount of time, in seconds, the search string
                          -- is set back to blank.

::attribute searchAndFound get
    expose selectedText
    return selectedText

::method init
    expose selectedText searchStr curIndex timer
    forward class (super) continue

    -- (.NET version) the font, Courier New 10, ooDialog's application default here
    self~create(30, 30, 186, 124, "Directory Listing with Search", "CENTER", , "Courier New", 10)

    selectedText = ''
    searchStr    = ''
    curIndex     = 0                    -- (.NET counts from 0)
    timer        = .nil

::method defineDialog

    self~createListBox(IDC_LB_FILES, 10, 10, 166, 90, 'VSCROLL HSCROLL PARTIAL SORT NOTIFY')
    self~createStaticText(IDC_ST_SEARCHSTR, 10, 102, 64, 11, , '')
    self~createPushButton(IDCANCEL, 74, 105, 50, 14, ,"Cancel")
    self~createPushButton(IDOK, 126, 105, 50, 14, 'DEFAULT', "Ok")

::method initDialog
    expose lb stSearchStr timer

    lb = self~newListBox(IDC_LB_FILES)
    call addDirectory lb, "C:\Windows\System32"         -- ooDialog: lb~addDirectory("C:\Windows\System32\*", ...)
    lb~KeyPress += .net~handler(self, "ONKEYPRESS")      -- ooDialog: lb~connectCharEvent
    lb~KeyDown += .net~handler(self, "ONKEYDOWN")

    stSearchStr = self~newStatic(IDC_ST_SEARCHSTR)
    self~setHorizontalExtent(lb)

    timer = .net~System~Windows~Forms~Timer~new         -- (one shot: stopped when it ticks)
    timer~Interval = self~expiration * 1000
    timer~Tick += .net~handler(self, "EXPIRED")

/* (.NET version) a character typed: ooDialog's onChar.  Handled: the list
   box does not search by itself. */
::method onKeyPress unguarded
    use arg lBox, e
    e~Handled = .true
    self~typed(e~KeyChar, lBox)

::method onKeyDown unguarded            -- the Del key resets the search
    use arg lBox, e
    if e~KeyCode~string == "Delete", \e~Control then do
        self~resetSearch
        e~Handled = .true
    end

::method typed unguarded
    expose searchStr curIndex
    use arg char, lBox

    if char == "08"x then do            -- BackSpace
        len = searchStr~length
        if len > 0 then searchStr = searchStr~substr(1, searchStr~length - 1)
        curIndex = 0
    end
    else do
        if char < " " then return       -- (other control characters)
        searchStr ||= char
    end

    self~incrementalSearch(lBox)

::method incrementalSearch private unguarded
    expose searchStr curIndex
    use strict arg lBox

    self~setStatusBar
    self~resetTimer

    newIndex = lBox~FindString(searchStr, curIndex - 1)  -- (from curIndex on; ooDialog: lBox~find(searchStr, curIndex))

    if newIndex <> curIndex then do
        if newIndex == -1 then do
            -- No selection: the hint that there is no item with the
            -- current search string.  We leave the current index unchanged.
            lBox~SelectedIndex = -1     -- ooDialog: lBox~selectIndex(0)
        end
        else do
            len = searchStr~length
            prefix    = lBox~Items[curIndex]~left(len)
            newPrefix = lBox~Items[newIndex]~left(len)

            -- Only move if the new item is a better match then the
            -- current item.  In other words if the prefixes match,
            -- don't do anything
            if \prefix~caselessEquals(newPrefix) then do
                lBox~SelectedIndex = newIndex
                lBox~TopIndex = newIndex    -- ooDialog: lBox~makeFirstVisible(newIndex)
                curIndex = newIndex
            end
        end
    end

-- When this method is invoked, the user has not typed a key for whatever
-- the timer period is, we abandon the search string.
::method expired unguarded
    expose searchStr curIndex timer
    timer~Stop
    searchStr = ''
    curIndex  = 0
    self~setStatusBar

-- Set the timer to the expiration time, (.NET version) from now.
::method resetTimer private unguarded
    expose timer
    timer~Stop
    timer~Start

-- Reset the incremental search
::method resetSearch private unguarded
    expose searchStr curIndex timer
    timer~Stop
    searchStr = ''
    curIndex  = 0
    self~setStatusBar

-- Show the search string under the list box.
::method setStatusBar private unguarded
    expose stSearchStr searchStr
    stSearchStr~Text = searchStr                    -- ooDialog: stSearchStr~setText(searchStr)

-- If the internal width of the list box is less than the width of an item,
-- not all of the item will be shown.  Here we measure the width of each string
-- and set the internal width of the list box to the width of the widest
-- string, plus 4 for a margin.
::method setHorizontalExtent private
    use strict arg lb

    max = 0
    TR = .net~System~Windows~Forms~TextRenderer
    do item over lb~Items~makeArray
        w = TR~MeasureText(item, lb~Font)~Width   -- ooDialog: lb~getTextSizePx(lb~getText(i))
        if w > max then max = w
    end
    lb~HorizontalScrollbar = .true
    lb~HorizontalExtent = max + 4                   -- ooDialog: lb~setWidthPx(max + 4)

::method ok unguarded
    expose lb selectedText timer

    timer~Stop
    selectedText = lb~SelectedItem
    if selectedText == .nil then selectedText = ''
    return self~ok:super

::method autoRun                       -- (.NET version) unattended: "kerx", BackSpace, "nel", Del, "ntdll", then Ok
    expose lb stSearchStr
    do c over "k e r x"~makeArray(" ")
        self~typed(c, lb)
    end
    say "(auto)" lb~Items~Count "items; 'kerx':" lb~SelectedIndex "selected"
    self~typed("08"x, lb)
    do c over "n e l"~makeArray(" ")
        self~typed(c, lb)
    end
    say "(auto) '"stSearchStr~Text"':" lb~SelectedItem
    self~resetSearch
    do c over "n t d l l"~makeArray(" ")
        self~typed(c, lb)
    end
    say "(auto) '"stSearchStr~Text"':" lb~SelectedItem
    self~ok

/* (.NET version) ooDialog's lb~addDirectory: the entries of a directory, its
   directories in brackets (as LB_DIR shows them); the list box sorts them */
::routine addDirectory
    use arg lb, dir
    names = .array~new
    do d over .net~System~IO~Directory~GetDirectories(dir)
        names~append("[" || filespec("name", d) || "]")
    end
    do f over .net~System~IO~Directory~GetFiles(dir)
        names~append(filespec("name", f))
    end
    lb~BeginUpdate
    lb~Items~AddRange(names)
    lb~EndUpdate
