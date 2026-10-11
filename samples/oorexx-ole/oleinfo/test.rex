/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2002-2022 Rony G. Flatscher. All rights reserved.            */
/* Copyright (c) 2023      Rexx Language Association. All rights reserved.    */
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

/* .NET version, for the ooRexx/.NET bridge: .OLEObject~new(progID) ->
   .net~createObject(progID); o~getKnownMethods, o~getKnownEvents ->
   .net~getKnownMethods(o), .net~getKnownEvents(o) (the same stems);
   o~getConstant -> .net~getConstant(o) (a StringTable); o~progid, o~clsid ->
   the stem's !PROGID, !CLSID; ::requires "net.cls". Other changes are
   marked "(.NET version)".                                                   */

-- Note: OLE objects do not always publish everything they offer!

line="-"~copies(79)     -- used as output delimiter

ProgID = "WScript.Network"
say "ProgID:" ProgId
network= .net~createObject(ProgID)
   -- full documentation (with constants), show in browser
call createOleInfo network, ProgID "(OLE-Object)", .false, .true
   -- reference sheet style documentation, show in browser
call createOleInfo network, ProgID "(OLE-Object)", .true,  .true

fn = "WScript_Constants.rex"
say "creating a Rexx program with the published OLE constants named:" fn
call getOleConstants ProgID fn
say "... to access all the constants from your program, require it like:"
say "          ::requires" fn
say "... to get the value for any of those OLE constants code like:"
say "          value=.ole.const~nameOfOleConstant "
------------------------------------------------------------------------------

say line
ProgID = "WScript.Shell"
say "ProgID:" ProgId
shell  = .net~createObject(ProgID)
   -- full documentation (with constants), show in browser
call createOleInfo shell, ProgID "(OLE-Object)", .false, .true
   -- reference sheet style documentation, show in browser
call createOleInfo shell, ProgID "(OLE-Object)", .true,  .true

   -- create a ShortCut object (do not save it) and document its OLE interfaces
shortCut=shell~createShortcut(shell~specialFolders("Desktop")"\Link By ooRexx Via OLE.lnk")
say "shortCut:" shortCut
   -- full documentation (with constants), show in browser
call createOleInfo shortCut, "Shortcut (OLE-Object)", .false, .true
   -- reference sheet style documentation, show in browser
call createOleInfo shortCut, "Shortcut (OLE-Object)", .true,  .true
------------------------------------------------------------------------------

say line
say "(.NET version) The Internet Explorer part is left out: IE is gone from Windows 11."

::requires "net.cls"
