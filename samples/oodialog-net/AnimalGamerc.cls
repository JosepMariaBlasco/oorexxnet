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
/* AnimalGame.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with AnimalGame.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "AnimalGame_IDD_ANIMALS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(1, 0, 393, 314, "What animals are these?", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createEdit(IDC_EDIT_RHINO, 10, 113, 92, 13, "", "IDC_EDIT_RHINO")
  self~createEdit(IDC_EDIT_TIGER, 104, 113, 92, 13, "", "IDC_EDIT_TIGER")
  self~createEdit(IDC_EDIT_ELEPHANT, 198, 113, 92, 13, "", "IDC_EDIT_ELEPHANT")
  self~createEdit(IDC_EDIT_MOOSE, 292, 113, 92, 13, "", "IDC_EDIT_MOOSE")
  self~createEdit(IDC_EDIT_GOAT, 10, 236, 92, 13, "", "IDC_EDIT_GOAT")
  self~createEdit(IDC_EDIT_DOG, 104, 236, 92, 13, "", "IDC_EDIT_DOG")
  self~createEdit(IDC_EDIT_SEAL, 198, 236, 92, 13, "", "IDC_EDIT_SEAL")
  self~createEdit(IDC_EDIT_HORSE, 292, 236, 92, 13, "", "IDC_EDIT_HORSE")
  self~createPushButton(IDC_PB_RHINO, 10, 10, 92, 100, "", "Rhino")
  self~createPushButton(IDC_PB_TIGER, 104, 10, 92, 100, "", "Tiger")
  self~createPushButton(IDC_PB_ELEPHANT, 198, 10, 92, 100, "", "Elephant")
  self~createPushButton(IDC_PB_MOOSE, 292, 10, 92, 100, "", "Moose")
  self~createPushButton(IDC_PB_GOAT, 10, 134, 92, 100, "", "Goat")
  self~createPushButton(IDC_PB_DOG, 104, 134, 92, 100, "", "Dog")
  self~createPushButton(IDC_PB_SEAL, 198, 134, 92, 100, "", "Seal")
  self~createPushButton(IDC_PB_HORSE, 292, 134, 92, 100, "", "Horse")
  self~createPushButton(IDHELP, 10, 290, 50, 14, "", "Help Me")
  self~createGroupBox(IDC_STATIC, 75, 262, 239, 42, "", "Write in the name of each animal below its picture")
  self~createStatic(IDC_STATIC, 92, 280, 217, 20, "", "Tips:  Click on an animal's picture to get a hint.  Click Ok when finished, or to see which answers are correct / incorrect.")
  self~createPushButton(IDOK, 333, 271, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 333, 290, 50, 14, "", "Cancel")
