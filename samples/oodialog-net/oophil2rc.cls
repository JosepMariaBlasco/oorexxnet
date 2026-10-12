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
/* ooDialog\Samples\rc\oophil2.rc      Philosophers' Forks Animation  */
/*--------------------------------------------------------------------*/
/* oophil2.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with oophil2.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Oophil2_100" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 282, 236, "Philosophers' Forks Animation", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(101, 108, 4, 65, 65, "OWNERDRAW", "Button")
  self~createPushButton(102, 216, 33, 65, 65, "OWNERDRAW", "Button")
  self~createPushButton(103, 193, 145, 65, 65, "OWNERDRAW", "Button")
  self~createPushButton(104, 26, 145, 65, 65, "OWNERDRAW", "Button")
  self~createPushButton(105, 1, 33, 65, 65, "OWNERDRAW", "Button")
  self~createPushButton(106, 186, 31, 15, 38, "OWNERDRAW", "Button")
  self~createPushButton(107, 262, 145, 15, 38, "OWNERDRAW", "Button")
  self~createPushButton(108, 134, 192, 15, 38, "OWNERDRAW", "Button")
  self~createPushButton(109, 6, 145, 15, 38, "OWNERDRAW", "Button")
  self~createPushButton(110, 79, 31, 15, 38, "OWNERDRAW", "Button")
  self~createPushButton(111, 130, 71, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(112, 238, 99, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(113, 215, 211, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(114, 48, 211, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(115, 23, 99, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(120, 91, 94, 102, 70, "OWNERDRAW", "Button")
  self~createPushButton(121, 108, 71, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(122, 153, 71, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(131, 216, 99, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(132, 261, 99, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(141, 193, 211, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(142, 238, 211, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(151, 26, 211, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(152, 71, 211, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(161, 1, 99, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(162, 46, 99, 20, 19, "OWNERDRAW", "Button")
  self~createPushButton(1, 126, 170, 31, 14, "", "&Stop")
