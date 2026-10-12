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
 *  This example shows how to add tool tips to a combo box.
 *
 *  When the items in a combo box are longer than the width of the combo box,
 *  they can be difficult for the user to read.  Tool tips are a good solution
 *  to this, but combo boxes do not have built in support for tool tips like
 *  list-views or tree-views.
 *
 *  Adding the support to a combo box is doable, but it takes a little work.
 *  This example shows how it is done.  The example also shows how to custom
 *  position the tool tips.  To see the difference in where the tool tip
 *  positions the tips by default and where this program positions them, the
 *  dialog has 2 radio buttons that allow switching between the default
 *  positioning and the custom positioning.
 *
 *  One approach to adding tool tips to a combo box would be to just have the
 *  tool tips display for the items in the drop down list.  This example goes
 *  beyond that to also show tool tips for the selection field and the drop down
 *  button.
 *
 *  When the drop down is closed, adding tool tips to the selection field and
 *  the button is relatively easy.  But, when the drop down is open, it is hard
 *  because the list box has the mouse captured.  This prevents tool tips from
 *  activating when the mouse goes over the selection field or the button.  What
 *  we do here is create tracking tool tips for the selection field and the
 *  button to use when the drop down is open.  Tracking tool tips need to be
 *  shown and hidden manually, which is what is done in this program.
 *
 * (.NET version of ooDialog's controls\ToolTip\comboBoxToolTip.rex, on Windows
 * Forms through oodnet.cls; the .rc is comboBoxToolTiprc.cls, written by
 * rc2oodnet.rex -cls. A .NET ComboBox does not give its drop-down list box
 * (ooDialog: getComboBoxInfo), but an owner-drawn one (DrawMode
 * OwnerDrawFixed) is asked to draw each item, the one under the mouse as
 * selected: that is how we know which item the mouse is over, and where
 * (ooDialog: the list box's mouse messages relayed, its hitTestInfo). While
 * the list is down it has the mouse, as in Win32, and the combo box gets no
 * mouse moves: a Timer looks at where the mouse is (onRelay), for the
 * selection field and the button, and for leaving the list. When the list is
 * up, the combo box's MouseMove does. The tips are two .NET ToolTips, shown
 * by the program (ToolTip.Show) after the ToolTip's InitialDelay, or at once
 * for the tracking ones, where onShow and its kin say, or below the mouse
 * when the ToolTip positions them. The cue (setCue) is drawn by us too, in
 * the selection field while nothing is selected.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

  dlg = .CitiesOfTheWorldDlg~new                          -- ooDialog: .CitiesOfTheWorldDlg~new(sd'comboBoxToolTip.rc', IDD_MAJOR_CITIES)
  dlg~execute("SHOWTOP")

  return 0

::requires "comboBoxToolTiprc.cls"

::class 'CitiesOfTheWorldDlg' subclass ComboBoxToolTip_IDD_MAJOR_CITIES

/** init()
 *
 * Normally for RcDialog dialogs there is no need for an init() method.  Here,
 * we use the init() method to set up our state varialbes and to connect a
 * combo box event.
 *
 * There is no real need to do it here, it could just as well been done in the
 * initDialog() method.
 */
::method init
  expose currentItem currentText currentOnClient ttEditActive ttButtonActive doCustomPositioning

  forward class (super) continue

  -- These variables are used to help track which tool needs to be shown.
  -- (.NET version) currentItem: 'NONE', 'EDIT' (the selection field),
  -- 'BUTTON', or an item's index (from 0)
  currentItem     = 'NONE'
  currentText     = ''
  currentOnClient = .false
  ttEditActive    = .false
  ttButtonActive  = .false

  doCustomPositioning = .true

  self~connectEvent(IDC_COMBOBOX, 'DropDownClosed', onCloseUP)   -- ooDialog: connectComboBoxEvent(IDC_COMBOBOX, 'CLOSEUP', onCloseUP)

  self~connectButtonEvent(IDC_RB_DEFAULT, 'CLICKED', doDefault)
  self~connectButtonEvent(IDC_RB_CUSTOM, 'CLICKED', doCustom)


/** initDialog()
 *
 *  This is a busy initDialog().  We need to set up and configure the combo box
 *  and create and configure the tool tips.
 */
::method initDialog
  expose comboBox itemHeight tt ttTrack delay poll hot hotBounds cue

  WF = .net~System~Windows~Forms
  comboBox = self~newComboBox(IDC_COMBOBOX)

  -- The tool tips are slightly higher than the default height of the combo box
  -- items.  So, when we position the tool tip over an item, it does not quite
  -- fit.  Making the item height slightly bigger makes things look a lot
  -- better.  (.NET version: an owner-drawn combo box has the height we give
  -- its items.)
  itemHeight = comboBox~ItemHeight
  itemHeight += 2
  comboBox~DrawMode = "OwnerDrawFixed"
  comboBox~ItemHeight = itemHeight                          -- ooDialog: comboBox~setItemHeight(itemHeight)
  comboBox~DrawItem += .net~handler(self, "ONDRAWITEM")

  entries = self~getComboItems
  do e over entries
    comboBox~Items~Add(e)
  end

  cue = "Select a city"                                     -- ooDialog: comboBox~setCue("Select a city"): drawn by onDrawItem
  comboBox~MaxDropDownItems = 10                            -- ooDialog: comboBox~setMinVisible(10)
  comboBox~DropDownHeight = 10 * itemHeight + 2

  self~newRadioButton(IDC_RB_CUSTOM)~Checked = .true

  -- (.NET version) Two ToolTips: tt for the items, and for the selection
  -- field and the button when the list is up; ttTrack for those two while
  -- the list is down (ooDialog: IDC_TT_EDIT_TRACK and IDC_TT_BUTTON_TRACK,
  -- tracking tool tips). A tip waits for the mouse to rest (delay); while
  -- the list is down a Timer (poll) watches the mouse.
  tt = WF~ToolTip~new
  ttTrack = WF~ToolTip~new
  delay = WF~Timer~new
  delay~Interval = tt~InitialDelay
  delay~Tick += .net~handler(self, "ONDELAY")
  poll = WF~Timer~new
  poll~Interval = 50
  poll~Tick += .net~handler(self, "ONRELAY")
  hot = -1                                                  -- the item drawn as selected while the list is down, and where
  hotBounds = .nil

  comboBox~MouseMove += .net~handler(self, "ONRELAY")       -- ooDialog: ttComboBox~manageAtypicalTool(comboBox, ...)
  comboBox~MouseLeave += .net~handler(self, "ONRELAY")
  comboBox~DropDown += .net~handler(self, "ONDROPDOWN")     -- ooDialog: ttList~manageAtypicalTool(cbListBox, .array~of('RELAY', 'NEEDTEXT', 'SHOW'))


/** onDrawItem()
 *
 * (.NET version) The combo box asks for an item to be drawn: its text, in
 * the colours of its state; the cue when nothing is selected. An item drawn
 * as selected while the list is down is the one the mouse is over (or the
 * keyboard's).
 */
::method onDrawItem unguarded
  expose comboBox hot hotBounds cue
  use arg cb, e

  WF = .net~System~Windows~Forms
  flags = "VerticalCenter, SingleLine, NoPrefix"            -- (a TextFormatFlags, by its names)
  e~DrawBackground
  if e~Index < 0 then do                                    -- the selection field, nothing selected: the cue
    WF~TextRenderer~DrawText(e~Graphics, cue, e~Font, e~Bounds, .net~System~Drawing~SystemColors~GrayText, flags)
    return
  end
  WF~TextRenderer~DrawText(e~Graphics, cb~Items[e~Index], e~Font, e~Bounds, e~ForeColor, flags)
  e~DrawFocusRectangle
  state = e~State~ordinal                                   -- (DrawItemState: Selected 1, ComboBoxEdit 4096)
  if cb~DroppedDown, state // 2 = 1, (state % 4096) // 2 = 0 then do   -- (an item of the list, not the selection field)
    hot = e~Index
    hotBounds = e~Bounds
    self~onRelay(cb, .nil)
  end


/** onDropDown()
 *
 * (.NET version) The list comes down: it has the mouse now; the Timer
 * watches where it is.
 */
::method onDropDown unguarded
  expose poll hot
  use arg cb, e
  hot = -1
  poll~Start


/** onRelay()
 *
 * The onRelay() event handler is invoked for every mouse message.  (.NET
 * version: the combo box's MouseMove and MouseLeave while the list is up;
 * the Timer's ticks and the items drawn as selected while it is down.)
 *
 * This event handler here is the key to how this whole program works.
 *
 * All the rest of the code in the program is simply busy work, keeping track of
 * what state we are in.  In this method we determine where the mouse is and
 * then determine how we have to configure all the tool tips we are using.
 *
 * We need to track what item the mouse is over, and whether the mouse is over
 * the client area of the combo box.  Every time the location changes from over
 * the clien to not over the client, and every time the item the mouse is over
 * changes, the tool tips need to be updated.
 *
 * To handle the selection field and the button, we treat them a pseudo list
 * box item.  If we are, newly, over the selection field or button while the
 * list is down, we show the tracking tool tip at once.  Other code in this
 * program is responsible for hiding the tracking tool tips at the proper
 * time.
 */
::method onRelay unguarded
    expose currentItem currentText currentOnClient ttTrack ttEditActive ttButtonActive comboBox -
           tt delay hot hotBounds
    use arg sender, e

    -- Determine which, if any, item the mouse is over.
    p = comboBox~PointToClient(.net~System~Windows~Forms~Cursor~Position)
    where = 'NONE'
    buttonWidth = .net~System~Windows~Forms~SystemInformation~VerticalScrollBarWidth
    if p~Y >= 0, p~Y < comboBox~Height, p~X >= 0, p~X < comboBox~Width then do
        if p~X >= comboBox~Width - buttonWidth then where = 'BUTTON'
        else where = 'EDIT'
    end
    else if comboBox~DroppedDown, hot >= 0, p~X >= 0, p~X < comboBox~Width, -
            p~Y >= comboBox~Height, p~Y < comboBox~Height + comboBox~DropDownHeight then where = hot

    -- Save the old item and location and sent the current item and location to
    -- where the mouse is at this moment.
    oldItem         = currentItem
    oldOnClient     = currentOnClient
    currentItem     = where
    currentOnClient = where \== 'NONE'

    -- If mouse is over a new item or location, hide the ToolTip.  Set our
    -- current text to the text for the item we are now over.  If we are not
    -- on the client area, set the current text to the empty string.
    if oldItem \== currentItem | oldOnClient \== currentOnClient then do
        turnTTEditActiveOff   = .true
        turnTTButtonActiveOff = .true
        currentText = ''
        if currentOnClient, comboBox~DroppedDown then do
            if where == 'BUTTON' then do
                ttButtonActive        = .true               -- ooDialog: ttButtonTrack~trackActivate(self, comboBox, .true)
                turnTTButtonActiveOff = .false
                self~onButtonTrackShow(comboBox, ttTrack, 'Press the button to close the drop down')
            end
            else if where == 'EDIT' then do
                ttEditActive = .true                        -- ooDialog: ttEditTrack~trackActivate(self, cbEdit, .true)
                turnTTEditActiveOff = .false
                info = .directory~new
                self~onEditTrackNeedText(comboBox, ttTrack, info)
                if info~text \== '' then self~onEditTrackShow(comboBox, ttTrack, info~text)
            end
            else do
                currentText = comboBox~Items[where]         -- ooDialog: listBox~getText(d~itemIndex)
            end
        end

        -- Each time we have a change, we close the current tool tip.  The tool
        -- tips are now configured for the *new* item the mouse is over.  Which
        -- may be not over an item at all, of course.  (.NET version: then the
        -- wait starts again.)
        tt~Hide(comboBox)                                   -- ooDialog: toolTip~pop
        delay~Stop
        if currentOnClient, \(comboBox~DroppedDown & \currentItem~dataType("W")) then delay~Start

        if turnTTEditActiveOff, ttEditActive then do
            ttTrack~Hide(comboBox)                          -- ooDialog: ttEditTrack~trackActivate(self, cbEdit, .false)
            ttEditActive = .false
        end

        if turnTTButtonActiveOff, ttButtonActive then do
            ttTrack~Hide(comboBox)
            ttButtonActive = .false
        end
    end

    return 0


/** onDelay()
 *
 * (.NET version) The mouse has rested: what a ToolTip does then. Over an
 * item, onNeedText and onShow; over the selection field or the button, the
 * list being up, onCBNeedText and onCBShow; where the program does not
 * place the tip, below the mouse.
 */
::method onDelay unguarded
    expose tt delay currentItem comboBox
    delay~Stop
    info = .directory~new
    if currentItem~dataType("W") then do
        self~onNeedText(tt, comboBox, info)
        shown = self~onShow(tt, comboBox, info~text)
    end
    else if currentItem == 'EDIT' | currentItem == 'BUTTON' then do
        info~toolID = (currentItem == 'EDIT')~?(IDC_TI_EDITRECT, IDC_TI_BUTTONRECT)
        self~onCBNeedText(tt, comboBox, info)
        shown = self~onCBShow(tt, comboBox, info~toolID, info~text)
    end
    else return
    if info~text == '' | shown then return
    p = comboBox~PointToClient(.net~System~Windows~Forms~Cursor~Position)
    tt~Show(info~text, comboBox, p~X, p~Y + 20, tt~AutoPopDelay)


/** onNeedText()
 *
 * The event handler for the NEEDTEXT event, when the list box tool is
 * requesting the text it should display.
 *
 * We set the text to the text of the current item the mouse is over.
 */
::method onNeedText unguarded
    expose currentItem currentText
    use arg toolTip, listBox, info

    info~text = currentText

    -- Return false so that the ToolTip does not store the text.  We want it to
    -- always ask us for the text because the mouse could be over any item.
    return .false


/** onShow()
 *
 * The event handler for the SHOW event, when the list box tool is about to
 * show the tip.  This gives us the chance to do a custom positioning of the
 * tip.
 *
 * If we are not doing custom positioning we just return false.  False tells the
 * tool tip that it should position the tip itself.
 *
 * If we are doing the positioning, we show the tip where we want it and
 * return true.  The position we want is the top left corner of the list box
 * item.  But, the tool tip tips are slightly taller than a list box item, so
 * we shift the position up 3 pixels, which gives us a position that does not
 * obscure either the item above or the item below.  (.NET version: the item's
 * place is where it was drawn, in the list below the combo box.)
 */
::method onShow unguarded
    expose currentItem comboBox hotBounds doCustomPositioning
    use arg toolTip, listBox, text

    if \ doCustomPositioning then return .false

    if currentItem~dataType("W"), hotBounds \== .nil then do
        top = comboBox~Height + 1 + hotBounds~Y             -- ooDialog: (currentItem - topIndex) * itemHeight, client2screen
        top -= 3

        toolTip~Show(text, comboBox, hotBounds~X, top, toolTip~AutoPopDelay)
        return .true
    end

    return .false


/** onCBNeetText()
 *
 * The event handler for the NEEDTEXT event, when the combo box tool tip is
 * requesting the text for the tip.  We use the tool ID to detemine which tool
 * we are invoked for.  If it is the selection field, we return the selected
 * item text.  If it is the button, we return the button tip.
 *
 * We can only be invoked when the drop down is closed.
 */
::method onCBNeedText unguarded
    use arg toolTip, comboBox, info

    if info~toolID == IDC_TI_EDITRECT then do
        info~text = comboBox~Text                           -- ooDialog: comboBox~selected
    end
    else if info~toolID == IDC_TI_BUTTONRECT then do
        info~text = 'Press the button to open the drop down'
    end
    else do
        -- Can not happen
        info~text = ''
        return .true
    end

    return .false


/** onCBShow()
 *
 * The event handler for the SHOW event, when the combo box tool tip is about
 * to show the tip.  This gives us a chance to do custom positiong.  If we are
 * not doing custom positioning, we simple return false, telling the tool tip
 * to position the tip itself.
 *
 * If it is the selection field, we position the tip at the top left corner
 * of the selection field.  If it is the button, we position the tip
 * immediately to right of the button.
 *
 * We can only be invoked when the drop down is closed.
 */
::method onCBShow unguarded
    expose doCustomPositioning
    use arg toolTip, comboBox, toolID, text

    if \ doCustomPositioning then return .false

    if toolID == IDC_TI_EDITRECT then do
        toolTip~Show(text, comboBox, 0, 0, toolTip~AutoPopDelay)
        return .true
    end
    else if toolID == IDC_TI_BUTTONRECT then do
        toolTip~Show(text, comboBox, comboBox~Width, 0, toolTip~AutoPopDelay)
        return .true
    end

    return .false


/** onEditTrackNeedText()
 *
 * This is the event handler for the NEEDTEXT event.  It is invoked when the
 * edit tracking tool tip needs the text to display for the selection field.
 *
 * We simply send it the text of the currently selected item.
 */
::method onEditTrackNeedText unguarded
    use arg comboBox, toolTip, info

    info~text = comboBox~Text
    return .false


/** onEditTrackShow
 *
 * This is the event handler for the SHOW event, when the edit tracking tool
 * tip is about to show the tip.  If we are not doing custom positioning of
 * the tip, the tip goes below the mouse, where a tool tip puts it.
 *
 * If we are positioing the tip, we place it directly over the selection field.
 */
::method onEditTrackShow unguarded
    expose doCustomPositioning
    use arg comboBox, toolTip, text

    if \ doCustomPositioning then return showBelowMouse(toolTip, comboBox, text)

    toolTip~Show(text, comboBox, 0, 0)
    return .true



/** onButtonTrackShow
 *
 * This is the event handler for the SHOW event, when the button tracking
 * tool tip is about to show the tip.
 *
 * If we are positioing the tip, we place it directly to the right of the
 * button.
 */
::method onButtonTrackShow unguarded
    expose doCustomPositioning
    use arg comboBox, toolTip, text

    if \ doCustomPositioning then return showBelowMouse(toolTip, comboBox, text)

    toolTip~Show(text, comboBox, comboBox~Width, 0)
    return .true


/** onCloseUp()
 *
 * Event handler for the CLOSEUP event.  This method is invoked when the drop
 * down list is closed.
 *
 * We have 2 tracking tool tips in this program.  They must be manually shown
 * and hidden.  If one or the other is visble and the drop down is closed, it
 * will remain on the screen.  So, here we hide the tool tip if it is currently
 * visible.  (.NET version: and the Timer stops watching the mouse.)
 */
::method onCloseup unguarded
    expose ttTrack ttEditActive ttButtonActive comboBox poll tt delay currentItem hot
    use arg cb, e

    poll~Stop
    delay~Stop
    tt~Hide(comboBox)
    hot = -1
    currentItem = 'NONE'

    if ttEditActive then do
        ttTrack~Hide(comboBox)
        ttEditActive = .false
    end

    if ttButtonActive then do
        ttTrack~Hide(comboBox)
        ttButtonActive = .false
    end

    return 0


/** doDefault()
 *
 * The event handler for the 'Tool Tip positions the tool tips' radio button
 * click event.  We just need to flip our flag.
 */
::method doDefault unguarded
    expose doCustomPositioning
    doCustomPositioning = .false
    return 0


/** doCustom()
 *
 * The event handler for the 'Application positions the tool tips' radio button
 * click event.  We just need to flip our flag.
 */
::method doCustom unguarded
    expose doCustomPositioning
    doCustomPositioning = .true
    return 0


/** getComboItems()
 *
 * Simple convenience method, returns an array of the items we will add to the
 * combo box.
 */
::method getComboItems private

  entries = .array~of("New York, United States of America, North America",     -
                      "Johannesburg, South Africa, Africa",                    -
                      "Cape Town, South Africa, Africa",                       -
                      "Saint Petersburg, Russia, Europe",                      -
                      "Mexico City, Mexico, North America",                    -
                      "Los Angles, United States of America, North America",   -
                      "Casablanca, Morocco, Africa",                           -
                      "Pyongyang, North Korea, Asia",                          -
                      "New Taipei, Republic of China (Taiwan), Asia",          -
                      "Addis Ababa, Ethiopia, Africa",                         -
                      "Moscow, Russia, Europe",                                -
                      "Yokohama, Japan, Asia",                                 -
                      "Chongqing, China, Asia",                                -
                      "Berlin, Germany, Europe",                               -
                      "Rio de Janeiro, Brazil, South America",                 -
                      "Guangzhou, China, Asia",                                -
                      "São Paulo, Brazil, South America",                      -
                      "Karachi, Pakistan, Asia",                               -
                      "Istanbul, Turkey, Europe / Asia",                       -
                     )

  return entries

::method autoRun                       -- (.NET version) unattended: an item picked, the tips of the selection field and an item; Done
    expose comboBox currentItem currentText hot hotBounds tt
    comboBox~SelectedIndex = 16
    say "(auto)" comboBox~Items~Count "cities; picked:" comboBox~Text "- item height" comboBox~ItemHeight
    info = .directory~new
    info~toolID = IDC_TI_EDITRECT
    self~onCBNeedText(tt, comboBox, info)
    say "(auto) selection field's tip:" info~text
    currentItem = 3; currentText = comboBox~Items[3]
    hotBounds = .net~System~Drawing~Rectangle~new(0, 3 * comboBox~ItemHeight, comboBox~Width, comboBox~ItemHeight)
    say "(auto) item 4's tip:" currentText "- placed by us:" self~onShow(tt, comboBox, currentText)
    self~doDefault
    say "(auto) the ToolTip places them now:" (\self~onShow(tt, comboBox, currentText))
    self~onCloseUp(comboBox, .nil)
    self~cancel

/* (.NET version) where a tool tip puts its tip: below the mouse */
::routine showBelowMouse
  use arg toolTip, ctl, text
  p = ctl~PointToClient(.net~System~Windows~Forms~Cursor~Position)
  toolTip~Show(text, ctl, p~X, p~Y + 20)
  return .false
