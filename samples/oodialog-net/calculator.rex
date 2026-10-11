/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2021 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                         */
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
/* Name: calculator.rex                                                     */
/* Type: Object REXX Script                                                 */
/*                                                                          */
/* (.NET version of ooDialog's calculator.rex, on Windows Forms through     */
/* oodnet.cls. The dialog of rc\calculator.rc is built in defineDialog,     */
/* with its coordinates; RxMath's RxCalc* functions are .NET's System.Math  */
/* (in degrees, as RxMath's default). The digit buttons still go to         */
/* UNKNOWN, as in the original.)                                            */
/****************************************************************************/

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

/* create the dialog */
calcDlg = .Calculator~new

/* Set the defaults for arithmetic operations (optional) */
NUMERIC DIGITS 16           /* precision of the results shown */
NUMERIC FORM   SCIENTIFIC   /* controls exponential notation */
NUMERIC FUZZ   0            /* number of digits ignored for numeric comparison */

/* Display the dialog */
if calcDlg~initCode = 0 then do
  rc = calcDlg~execute("SHOWTOP")
end

exit   /* leave program */

::requires "oodnet.cls"

/* The Calculator dialog class */
::class 'Calculator' subclass NetDialog

::method init
  forward class (super) continue /* call parent constructor */
  /* (.NET version) the .rc's DIALOG, STYLE and FONT */
  self~create(13, 20, 222, 212, "Calculator", "MINIMIZEBOX", , "MS Shell Dlg", 10)

::method defineDialog                  /* (.NET version) the .rc's controls */
  self~createEdit(TLine, 13, 13, 188, 14, "READONLY")
  digits = .array~of(.array~of(1, 20, 39), .array~of(2, 46, 39), .array~of(3, 72, 39), -
                     .array~of(4, 20, 65), .array~of(5, 46, 65), .array~of(6, 72, 65), -
                     .array~of(7, 20, 91), .array~of(8, 46, 91), .array~of(9, 72, 91), -
                     .array~of(0, 20, 117))
  do d over digits                     /* each digit button sends BNOn: UNKNOWN takes them */
    self~createPushButton("BNO"d[1], d[2], d[3], 14, 14, , d[1], "BNO"d[1])
  end
  self~createPushButton(BSign,      46, 117, 14, 14, , "+/-",    BSIGN)
  self~createPushButton(BPoint,     72, 117, 14, 14, , ".",      BPOINT)
  self~createPushButton(BDivide,   111,  39, 14, 14, , "/",      BDIVIDE)
  self~createPushButton(BTimes,    111,  65, 14, 14, , "*",      BTIMES)
  self~createPushButton(BMinus,    111,  91, 14, 14, , "-",      BMINUS)
  self~createPushButton(BPlus,     111, 117, 14, 14, , "+",      BPLUS)
  self~createPushButton(BSqrt,     137,  39, 27, 14, , "Sqrt",   BSQRT)
  self~createPushButton(BLog,      137,  65, 27, 14, , "Log",    BLOG)
  self~createPushButton(BLog10,    137,  91, 27, 14, , "Log10",  BLOG10)
  self~createPushButton(BPi,       137, 117, 27, 14, , "Pi",     BPI)
  self~createPushButton(BBackspace,177,  39, 24, 14, , "<-",     BBACKSPACE)
  self~createPushButton(BClear,    177,  65, 24, 14, , "Clear",  BCLEAR)
  self~createPushButton(BCalc,     177,  91, 24, 14, "DEFAULT", "=", BCALC)
  self~createPushButton(IDOK,      177, 117, 24, 14, , "Exit")
  self~createPushButton(BSinus,     20, 150, 27, 14, , "Sin",    BSINUS)
  self~createPushButton(BCosinus,   60, 150, 27, 14, , "Cos",    BCOSINUS)
  self~createPushButton(BTangens,  100, 150, 27, 14, , "Tan",    BTANGENS)
  self~createPushButton(BArcSin,    20, 176, 27, 14, , "ArcSin", BARCSIN)
  self~createPushButton(BArcCos,    60, 176, 27, 14, , "ArcCos", BARCCOS)
  self~createPushButton(BArcTan,   100, 176, 27, 14, , "ArcTan", BARCTAN)
  self~createStatic(-1, 152, 152, 50, 41, , "ooRexx ooDialog Demo Calculator")
  self~createStatic(-1,  13,  33, 81, 106, "GRAYFRAME")
  self~createStatic(-1,   6,   7, 210, 197, "BLACKFRAME")

::method initDialog
  expose tl
  tl = self~newEdit(TLine) /* get the edit control (a .NET TextBox) */
  tl~Text = '0'            /* the original's initial value of its TLine attribute */

::method getLine
  /* Return the current text-line content, */
  /* or 0 if infinity has been reached.    */
  expose tl
  if tl~Text~Left(5) = 'ERROR' then
    return 0
  return tl~Text

::method setLine
  /* Set the argument as new text-line. If this is ERROR raise an */
  /* errorDialog with additional information.                    */
  expose tl
  use arg line, merror
  if line~left(5) = 'ERROR' then
    call errorDialog "The calculation returned an error:" merror
  tl~Text = line

::method justZero
  /* Return true if the current text-line is only one 0.   */
  /* Most functions will then ignore the current text-line */
  line = self~getLine
  if line~Length = 1 & line = 0 then
    return 1
  return 0

::method getCheckedLine
  /* Return the result of the current calculation or the line  */
  /* if it is only a number. DataType will not return NUM      */
  /* if any operators are present.                             */
  line = self~getLine
  if DataType(line) = 'NUM' then
    return line
  else do
    interpret 'calcResult =' line
    return calcResult
  end

::method math private
  /* (.NET version) RxMath's functions through System.Math, in degrees */
  use arg name, x
  M = .net~System~Math
  r = M~PI / 180
  select case name
    when "SQRT"   then v = M~Sqrt(x)
    when "LOG"    then v = M~Log(x)
    when "LOG10"  then v = M~Log10(x)
    when "SIN"    then v = M~Sin(x * r)
    when "COS"    then v = M~Cos(x * r)
    when "TAN"    then v = M~Tan(x * r)
    when "ARCSIN" then v = M~Asin(x) / r
    when "ARCCOS" then v = M~Acos(x) / r
    when "ARCTAN" then v = M~Atan(x) / r
  end
  if \datatype(v, "N") then do        /* NaN, Infinity: as RxMath's ERROR */
    self~setLine("ERROR", name || "(" || x || ") is not a number:" v)
    return
  end
  numeric digits 14                    /* a double's precision: 0.5, not 0.49999999999999994 */
  self~setLine(v / 1)

/* --------------------- message handler -----------------------------------*/

::method UNKNOWN
  /* The UNKNOWN-method is called, whenever the defined message for a       */
  /* button cannot be found. This is a good way to roll all the methods for */
  /* the 10 digits into one. The last character of the argument is the      */
  /* number that was pressed.                                               */
  use arg message
  number = message~SubStr(4)
  if self~justZero then
    self~setLine(number)
  else self~setLine(self~getLine||number)

::method BSIGN
  /* Toggles the sign of the leading number on the text line. */
  if self~justZero then
    self~setLine('-')
  else do
    select
      when left(self~getLine,1)='-' then
        self~setLine('+'||substr(self~getLine,2))
      when left(self~getLine,1)='+' then
        self~setLine('-'||substr(self~getLine,2))
      otherwise
        self~setLine('-'||self~getLine)
    end
  end

::method BPOINT
  /* Append a point.. */
  self~setLine(self~getLine||'.')

::method BDIVIDE
  /* Appends a 'divide' symbol to the checked line. */
  self~setLine(self~GetCheckedLine||'/')

::method BTIMES
  /* Append a 'multiply' symbol to the checked line. */
  self~setLine(self~GetCheckedLine||'*')

::method BMINUS
  /* Appends a 'minus' symbol to the checked line. */
  self~setLine(self~GetCheckedLine||'-')

::method BPLUS
  /* Appends a 'plus' symbol to the checked line. */
  self~setLine(self~GetCheckedLine||'+')

::method BSQRT
  self~math("SQRT", self~GetCheckedLine)

::method BLOG
  self~math("LOG", self~GetCheckedLine)

::method BLOG10
  self~math("LOG10", self~GetCheckedLine)

::method BPI
  /* Displays the number Pi */
  numeric digits 14
  pi = .net~System~Math~PI / 1
  if self~justZero then
    self~setLine(pi)
  else self~setLine(self~getLine||pi)

::method BBACKSPACE
  /* Delete the last character of the line */
  line = self~getLine
  line = line~Left(line~Length - 1)
  if line = '' then     /* if the line is empty set it to 0 */
      self~setLine(0)
  else self~setLine(line)

::method BCLEAR
  /* Set the line to 0 */
  self~setLine(0)

::method BCALC
  /* Interpret the current line = calculate the result */
  interpret 'calcResult =' self~getLine
  self~setLine(calcResult)

::method BSINUS
  self~math("SIN", self~GetCheckedLine)

::method BCOSINUS
  self~math("COS", self~GetCheckedLine)

::method BTANGENS
  self~math("TAN", self~GetCheckedLine)

::method BARCSIN
  self~math("ARCSIN", self~GetCheckedLine)

::method BARCCOS
  self~math("ARCCOS", self~GetCheckedLine)

::method BARCTAN
  self~math("ARCTAN", self~GetCheckedLine)

::method Ok
  /* The original's comment: the ok method is connected to the button with  */
  /* the id IDOK; if validate() returns true, the superclass's ok ends the  */
  /* dialog. This over-ride sets the display to 0 before ending.            */
  if \ self~validate then return 0
  self~setLine(0)
  return self~ok:super

::method autoRun                       /* (.NET version) unattended: 12 * 3 + Sqrt, then Exit */
  do b over .array~of("BNO1", "BNO2", BTimes, "BNO3", BCalc, BSqrt)
    self~newPushButton(b)~PerformClick
  end
  say "sqrt(12 * 3) =" self~getLine
  self~newPushButton(BSinus)~PerformClick
  say "sin(6) =" self~getLine
  self~newPushButton(IDOK)~PerformClick
