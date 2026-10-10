/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2022 Rexx Language Association. All rights reserved.         */
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
/*********************************************************************

 MSWord_useStyles.rex: using OLE (object linking and embedding) with ooRexx

 Links:  <https://docs.microsoft.com/en-us/office/vba/api/overview/word>
         <https://docs.microsoft.com/en-us/office/vba/word/concepts/miscellaneous/concepts-word-vba-reference>
         <https://docs.microsoft.com/en-us/office/vba/api/overview/word/object-model>

 Using OLE create a Microsoft Word document, add text using various
 styles and wait for the user to press the enter (return) key before
 changing the font attributes of the styles named "Title" and "Heading 1".

*********************************************************************/
/*
 .NET version (ooRexx/.NET, https://github.com/JosepMariaBlasco/oorexxnet):
 - .net~createObject in place of .OLEObject~new;
 - the built-in styles by their constants (.net~getConstant: wdStyleTitle...)
   and compared by their local names, so it works whatever Word's language;
 - with the argument "auto" nothing waits for the user (for unattended runs);
 - .net~releaseObject where the program ends with the application, and
   ::requires "net.cls" at the end.
*/

auto = arg(1)~strip~caselessEquals("auto")         -- (.NET version) unattended: no waiting
-- Start Word with empty document
Word = .net~createObject("Word.Application")
Word~Visible = \auto                      -- make Word visible
Document = Word~Documents~Add             -- add document
Selection = Word~Selection                -- selection object
say "# 1: Create: title style..."
   -- (.NET version) the built-in styles by their constants: their names
   -- are the local ones ("Título" in a Spanish Word)
wdStyle. = .stem~new
do s over "TITLE HEADING1 HEADING2 NORMAL"~makeArray(" ")   -- (tails in uppercase, as wdStyle.Title uses)
  wdStyle.s = .net~getConstant(Word, "wdStyle"s)
end
Selection~Style = wdStyle.Title           -- Create selection with style: Title
Selection~TypeText("TITLE")               -- give selection a text
Selection~TypeParagraph                   -- add paragraph (go to next line)
say "# 2: Create: heading 1 style..."
Selection~Style = wdStyle.Heading1       -- Create selection with style: Heading 1
Selection~TypeText("HEADING 1")           -- give selection a text
Selection~TypeParagraph                   -- add paragraph (go to next line)
say "# 3: Create: heading 2 style..."
Selection~Style = wdStyle.Heading2       -- Create selection with style: Heading 2
Selection~TypeText("HEADING 2")           -- give selection a text
Selection~TypeParagraph                   -- add paragraph (go to next line)
   -- Note: Usually the style "Normal" follows heading styles
Selection~TypeText("Reset to normal ...") -- "Normal" follows "Heading 2"
Selection~TypeParagraph                   -- add paragraph (go to next line)
say "# 4: Create: normal text style..."
Selection~Style = wdStyle.Normal         -- Create selection with style: normal
Selection~TypeText("I am Normal Text.")   -- give selection a text

say "Press any key to change style!"
if \auto then parse pull               -- wait for key press
titleName = Document~Styles(wdStyle.Title)~NameLocal     -- (.NET version) the local names
heading1Name = Document~Styles(wdStyle.Heading1)~NameLocal

-- Go through each sentence
SentenceCount = Document~Sentences~Count        -- get sentence count
Font = Selection~Font                           -- get font object
do SentenceNumber = 1 to SentenceCount          -- go through each sentence

   Document~Sentences(SentenceNumber)~Select   -- select sentence
   StyleName = Selection~Style~NameLocal       -- get style name of sentence
   Select case StyleName                       -- make changes depending on style name
      when titleName then do
          Font~Name="Arial"
          Font~Size="38"
          Font~Bold = .TRUE
      end
      when heading1Name then do
          Font~Name="Times New Roman"
          Font~Size="22"
          Font~Italic = .TRUE
      end
      otherwise NOP
   end
end
if auto then do                                 -- (.NET version) close without saving
   Document~Close(0)                            -- wdDoNotSaveChanges
   Word~Quit
end

::requires "net.cls"
