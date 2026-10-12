/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2021 Rexx Language Association. All rights reserved.    */
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
/* oophil1.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with oophil1.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Oophil1_101" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(86, 68, 211, 125, "Philosophers' Forks Setup", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createEdit(101, 87, 11, 36, 12, "NUMBER", "DATA101")
  self~createUpDown(107, 111, 11, 12, 12, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createEdit(102, 87, 37, 36, 12, "NUMBER", "DATA102")
  self~createUpDown(108, 111, 37, 12, 12, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createEdit(103, 87, 62, 36, 12, "NUMBER", "DATA103")
  self~createUpDown(109, 111, 62, 12, 12, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(-1, 134, 7, 68, 50, "FRAME", "")
  self~createRadioButton(104, 137, 11, 60, 12, "", "&Left hand first", "LEFTHANDFIRST")
  self~createRadioButton(105, 137, 26, 62, 12, "", "&Right hand first", "RIGHTHANDFIRST")
  self~createRadioButton(106, 137, 41, 59, 12, "", "&Any hand first", "ANYHANDFIRST")
  self~createStatic(-1, 7, 13, 76, 8, "", "&Sleeping time (100 ms)")
  self~createStatic(-1, 7, 39, 71, 8, "", "&Eating time (100 ms)")
  self~createStatic(-1, 7, 64, 71, 8, "", "&Number of repeats")
  self~createStatic(-1, 3, 85, 141, 34, "FRAME", "")
  self~createPushButton(110, 5, 87, 138, 30, "OWNERDRAW", "Button")
  self~createPushButton(1, 153, 64, 50, 14, "DEFAULT", "OK")
  self~createPushButton(2, 153, 84, 50, 14, "", "Cancel")
  self~createPushButton(9, 153, 104, 50, 14, "", "&Help")
