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
/* ooDialog\Samples\rc\sample.rc       ooDialog Samples Main          */
/*--------------------------------------------------------------------*/
/* sample.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with sample.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Sample_100" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(4, 32, 465, 281, "Open Object Rexx ooDialog Samples", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(2, 8, 254, 50, 14, "", "E&xit")
  self~createPushButton(9, 68, 254, 50, 14, "", "About")
  self~createPushButton(101, 155, 15, 85, 50, "OWNERDRAW", "video")
  self~createPushButton(102, 259, 15, 85, 50, "OWNERDRAW", "pet")
  self~createPushButton(103, 155, 83, 85, 50, "OWNERDRAW", "philosoph")
  self~createPushButton(104, 259, 83, 85, 50, "OWNERDRAW", "inst")
  self~createPushButton(105, 155, 151, 85, 50, "OWNERDRAW", "walker")
  self~createPushButton(106, 259, 151, 85, 50, "OWNERDRAW", "bandit")
  self~createPushButton(107, 155, 217, 85, 50, "OWNERDRAW", "user")
  self~createPushButton(108, 259, 217, 85, 50, "OWNERDRAW", "category")
  self~createPushButton(109, 363, 15, 85, 50, "OWNERDRAW", "tree")
  self~createPushButton(110, 363, 83, 85, 50, "OWNERDRAW", "list")
  self~createPushButton(111, 363, 151, 85, 50, "OWNERDRAW", "bar")
  self~createPushButton(112, 363, 217, 85, 50, "OWNERDRAW", "prop")
