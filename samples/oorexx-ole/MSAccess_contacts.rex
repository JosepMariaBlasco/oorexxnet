/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2022 Rexx Language Association. All rights reserved.    */
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
/**********************************************************************/
/*                                                                    */
/* MSAccess_contacts.rex: OLE Automation with ooRexx                  */
/*                                                                    */
/* Creating a database in Microsoft Access.                           */
/*                                                                    */
/**********************************************************************/

-- Initialize string to database path.
-- get TEMP directory of current user
tempDir = value("TEMP",,"ENVIRONMENT")    -- get value of environment variable "TEMP"
strDB = tempDir"\newDatabaseByooRexx.mdb" -- define fully qualified database name
say "Fully qualifed database file name:" strDB

-- Remove any previously created copy of this sample database
if stream(strDB,'c','query exists') \= '' then
    do
        say 'Database exists (from earlier run), deleting it ...'
        rv = SysFileDelete(strDB)
        if rv \= 0 then
            do
                say 'Delete of previous database failed, exiting now'
                exit -1    -- return code not 0 so to indicate problem
            end
    end

-- Create new instance of Microsoft Access.
/*
 .NET version (ooRexx/.NET, https://github.com/JosepMariaBlasco/oorexxnet):
 - .net~createObject in place of .OLEObject~new;
 - .net~getConstant(dbs, "dbText") for appAccess~getConstant("db_Text"): the
   constant from DAO's own type library;
 - with the argument "auto" nothing waits for the user (for unattended runs);
 - .net~releaseObject where the program ends with the application, and
   ::requires "net.cls" at the end.
*/
auto = arg(1)~strip~caselessEquals("auto")         -- (.NET version) unattended: no waiting
appAccess = .net~createObject("Access.Application")

-- Open database in Microsoft Access window.
appAccess~NewCurrentDatabase(strDB)

-- Get Database object variable.
dbs = appAccess~CurrentDb

-- Create new table.
tdf = dbs~CreateTableDef("Contacts")

-- Create field in new table.
/* Please note how to access the constant.
   Microsoft documentation and the MS OLEViewer output
   these constants as dbText, dbBinary, etc. - the type library
   however prints them as DB_TEXT, DB_BINARY, etc.. Unless
   documentation is found why the names should be translated,
   the OLE code will *NOT* convert the names. */
/* (.NET version) .net~getConstant looks in the type library of the object
   it is given: DAO's constants (DataTypeEnum: dbText) come with a DAO
   object, the database, not with the Access application */
fld = tdf~CreateField("CompanyName", .net~getConstant(dbs, "dbText"), 40)

-- Append Field and TableDef objects.
tdf~Fields~Append(fld)
dbs~TableDefs~Append(tdf)

appAccess~quit
.net~releaseObject(appAccess)      -- (.NET version) now, not when .NET's GC gets to it

-- keep window open if invoked via Explorer to allow reading the output
say "Press enter to continue ..."
if \auto then parse pull .

::requires "net.cls"
