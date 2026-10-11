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
/* employe5.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with employe5.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Employe5_100" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 241, 141, "Employees", "", , "System", 8)

::method defineDialog                  -- the .rc's controls
  self~createEdit(21, 42, 11, 167, 12, "", "NAME")
  self~createUpDown(11, 219, 8, 10, 17, "AUTOBUDDY")
  self~createComboBox(22, 32, 30, 167, 56, "LIST", "CITY")
  self~createListBox(23, 73, 52, 156, 65, "SORT", "PROFESSION")
  self~createRadioButton(31, 12, 71, 26, 12, "", "&Male", "MALE")
  self~createRadioButton(32, 12, 84, 34, 12, "", "&Female", "FEMALE")
  self~createCheckBox(41, 12, 99, 37, 12, "", "M&arried", "MARRIED")
  self~createPushButton(12, 212, 28, 23, 21, "", "&Add")
  self~createPushButton(10, 8, 123, 50, 14, "", "&Print")
  self~createPushButton(IDOK, 63, 123, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 118, 123, 50, 14, "", "Cancel")
  self~createPushButton(13, 174, 123, 56, 14, "", "&List Employees")
  self~createStatic(-1, 10, 12, 27, 8, "", "Person:")
  self~createStatic(-1, 10, 32, 16, 8, "", "City:")
  self~createStatic(-1, 10, 53, 39, 8, "", "Profession:")
  self~createStatic(-1, 9, 68, 47, 45, "FRAME", "")

::class "Employe5_101" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 278, 144, "List of Employees", "", , "System", 8)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 226, 127, 50, 14, "DEFAULT", "OK")
  self~createListBox(101, 3, 16, 272, 103, "", "LIST")
  self~createStatic(-1, 5, 7, 26, 8, "", "Name")
  self~createStatic(-1, 101, 7, 60, 8, "", "Profession")
  self~createStatic(-1, 201, 7, 60, 8, "", "City")
