/*----------------------------------------------------------------------------*/
/* Copyright (c) 2006-2024 Rexx Language Association. All rights reserved.    */
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

/*
   purpose: Demonstrate how one can interact with MS Access databases through the
            database engine alone, without the Access application: the 64-bit
            counterpart of MSAccessDemo_32bit_only.rex (Jet, 32-bit only)
   needs:   the Microsoft Access Database Engine (ACE), 64-bit: it comes with a
            64-bit Office that has Access, or alone, as the "Microsoft Access
            Database Engine 2016 Redistributable" (x64)

   notes:   (.NET version, written for the bridge.) What MSAccessDemo_32bit_only.rex
            does with Jet, done with ACE, which has a 64-bit version:
              Microsoft.Jet.OLEDB.4.0 (ADO provider)  ->  Microsoft.ACE.OLEDB.16.0 (or 12.0)
              Access.Application~NewCurrentDatabase   ->  ADOX.Catalog~Create (no Access needed)
              JRO.JetEngine~CompactDatabase           ->  DAO.DBEngine.120~CompactDatabase
              ooRexxDemo.mdb                          ->  ooRexxDemo.accdb, in the temporary folder
            The rest is as there: ADO's Connection and Recordset (a keyset cursor,
            optimistic locks, RecordCount), SQL statements, a backup on compacting.
            .OLEObject~new -> .net~createObject; ::requires "net.cls" at the end.
            With the argument "auto" the database files are deleted at the end.

   links:   <https://learn.microsoft.com/en-us/office/client-developer/access/desktop-database-reference/microsoft-ole-db-provider-for-microsoft-jet>
            <https://www.microsoft.com/en-us/download/details.aspx?id=54920>
*/
auto = arg(1)~strip~caselessEquals("auto")

temp = value("TEMP", , "ENVIRONMENT")
dbFileName = temp"\ooRexxDemo.accdb"                  -- define database file name
provider = findProvider()                             -- ACE's ADO provider, 16.0 or 12.0
if provider == .nil then exit 1
call createDataBaseFile dbFileName, provider          -- create database file, if necessary

conn=.net~createObject("ADODB.Connection")  -- create an ADO connection to the database
conn~provider=provider                     -- tell the connection what driver to use
conn~open(dbFileName)            -- open a connection to the database

call dropTable       conn        -- make sure table is dropped
call createTable     conn        -- create a table in the database
call fillTable       conn        -- enter records to the table
call showTable       conn        -- show presently stored records
call deleteAndShow   conn        -- delete a record, show results
call updateAndShow   conn        -- update a few records, show results

conn~close                       -- close connection to the database
.net~releaseObject(conn)         -- (.NET version) the file is free for compacting now

call compressAndRepair dbFileName
say ".rexxInfo~architecture:" pp(.rexxInfo~architecture) "(bitness)"

if auto then do                  -- (.NET version) unattended: no files left behind
   call SysFileDelete dbFileName
   call SysFileTree dbFileName"-bkp-*", "old.", "FO"
   do i = 1 to old.0; call SysFileDelete old.i; end
end
exit 0

/* ------------------------------------------------------------------------- */
::routine findProvider           -- (.NET version) ACE's provider, if it is installed
   do provider over .array~of("Microsoft.ACE.OLEDB.16.0", "Microsoft.ACE.OLEDB.12.0")
      if canCreate(provider) then do
         say "using the provider" pp(provider)
         return provider
      end
   end
   say
   say "The Microsoft Access Database Engine (ACE, 64-bit) does not seem to be installed:"
   say "neither Microsoft.ACE.OLEDB.16.0 nor Microsoft.ACE.OLEDB.12.0 could create a database."
   say "Install a 64-bit Office with Access, or the Microsoft Access Database Engine 2016"
   say "Redistributable (x64): <https://www.microsoft.com/en-us/download/details.aspx?id=54920>"
   return .nil

::routine canCreate              -- can this provider create a database (a probe, deleted)?
   use arg provider
   probe = value("TEMP", , "ENVIRONMENT")"\ooRexxProbe.accdb"
   call SysFileDelete probe
   signal on syntax
   cat = .net~createObject("ADOX.Catalog")
   cat~create("Provider="provider";Data Source="probe)
   cat~activeConnection~close
   .net~releaseObject(cat)
   call SysFileDelete probe
   return .true
syntax:
   call SysFileDelete probe
   return .false

/* ------------------------------------------------------------------------- */
::routine createDataBaseFile
  use strict arg dbFileName, provider

  if \SysFileExists(dbFileName) then do   -- database file does not exist
     cat = .net~createObject("ADOX.Catalog")   -- ADOX creates it: no Access application needed
     cat~create("Provider="provider";Data Source="dbFileName)
     cat~activeConnection~close
     say "created database file" pp(dbFileName)
  end
  else
     say "database file" pp(dbFileName) "exists already"

  say center(" end of createDataBaseFile ", 70, "-")
  say

/* ------------------------------------------------------------------------- */
::routine dropTable
   use arg conn                  -- fetch connection to database

   signal on any                 -- intercept any exception
   conn~execute("drop table myTable")     -- execute SQL statement
   say "dropped 'myTable'"
   say center(" end of dropTable ", 70, "-")
   say
   return
any:
   say "could not drop 'myTable' (does it exist?)"
   say center(" end of dropTable ", 70, "-")
   say
   return

/* ------------------------------------------------------------------------- */
::routine createTable
   use arg conn                  -- fetch connection to database

   sql="create table myTable (id integer, name text (30) )"
   say "executing" pp(sql) "..."
   conn~execute(sql)             -- execute the statement
   say center(" end of createTable ", 70, "-")
   say

/* ------------------------------------------------------------------------- */
::routine fillTable
   use arg conn                  -- fetch connection to database

   s=.set~of("Chip Davis",           "Christian Michel",             "David Ashley", -
             "Erich Steinb&ouml;ck", "Florian Gro&szlig;e-Coosmann", "Frank Clark",  -
             "Gil Barmwater",        "Jan Engehausen",               "Lavrentios Servissoglou", -
             "Jean-Louis Faucher",   "Kurt M&auml;rker",             "Lee Peedin",         -
             "Manfred Schweizer",    "Mark Hessling",                "Mark Miesfeld",      -
             "Mike F. Cowlishaw",    "Pam Taylor",                   "P.O. Jonsson",       -
             "Reiner Micke",         "Ren&eacute; Jansen",           "Rick McGuire",       -
             "Rony G. Flatscher",    "Stefan D&ouml;rsam",           "Uwe Berger",         -
             "Walter Pachl"                                                                -
            )

   .local~tmp.nrRecs=s~items              -- save number of records in local environment
   .local~tmp.length=length(.tmp.nrRecs)  -- save length

   say "inserting" pp(.tmp.nrRecs) "record(s) into the table..."
   say

   i=0
   do name over s                -- iterate over collected items (arbitrary order)
       i=i+1                     -- calc unique id value
       sql="insert into myTable (id, name) values ("i~right(.tmp.length)", '"name"' )"
       say "  " i~right(.tmp.length)":" pp(sql)  -- show sql statement
       conn~execute(sql)            -- execute the statement
   end
   say center(" end of fillTable ", 70, "-")
   say

/* ------------------------------------------------------------------------- */
::routine showTable
   use arg conn                  -- fetch connection to database

   rs=.net~createObject("ADODB.Recordset")   -- create an ADO recordset object

   rs~CursorType =  1            -- adOpenKeyset
   rs~LockType   =  3            -- adLockOptimistic
   sql="select * from myTable order by id"
   rs~open(sql, conn)            -- open the table
   totRecs=rs~recordCount        -- get recordCount
   say "nr. of records:" pp(totRecs)":"
   say

   do i=1 to totRecs while rs~eof=.false  -- loop over record set
      say "  " i~right(.tmp.length)":"                             -
                 "id="pp(rs~fields["id"]~value~right(.tmp.length)) -
                 "name="pp(rs~fields["name"]~value)
      rs~moveNext                -- go to next record
   end
   rs~close                      -- close the record set
   say center(" end of showTable ", 70, "-")
   say

/* ------------------------------------------------------------------------- */
::routine deleteAndShow          -- delete a random row
   use arg conn                  -- fetch connection to database

   say "deleting a record from the table:"
   say
   sql="delete from myTable where id="random(1,.tmp.nrRecs)
   say "   executing" pp(sql) "..."
   count=.net~ref(0)             -- (.NET version) records affected, by reference
   conn~execute(sql, count)
   say "  " pp(count~value) "record deleted."
   say

   .local~tmp.nrRecs=.tmp.nrRecs-1        -- subtract 1 from total number of records
   .local~tmp.length=length(.tmp.nrRecs)  -- save length
   call showTable   conn         -- show presently stored records

/* ------------------------------------------------------------------------- */
::routine updateAndShow
   use arg conn                  -- fetch connection to database

   say "updating a few records from the table:"
   say
   sql="update myTable set id=id*3 where id >" random(1,.tmp.nrRecs)
   say "   executing" pp(sql) "..."
   count=.net~ref(0)
   conn~execute(sql, count)
   say "  " pp(count~value) "record(s) affected."
   say
   call showTable   conn            -- show presently stored records

/* ------------------------------------------------------------------------- */
::routine compressAndRepair      -- Access databases tend to grow considerably
  parse arg dbFileName

  compressedName=dbFileName"-cmp"random(1,999)
  say "before compress & repair, database file size:" pp(stream(dbFileName, "c", "query size"))

  -- (.NET version) Jet's JRO.JetEngine has no ACE counterpart: DAO 12's DBEngine
  -- (which comes with ACE) compacts, as Access's own DBEngine does
  dbEngine=.net~createObject("DAO.DBEngine.120")
  dbEngine~compactDatabase(dbFileName, compressedName)     -- carry out compact & repair
  .net~releaseObject(dbEngine)
  say "after  compress & repair, database file size:" pp(stream(compressedName, "c", "query size"))

      -- create a unique backup file name containing date and time of backup
  newBkpFileName=dbFileName"-bkp-"date("S")"-"time()~changestr(":","")

  say "renaming work files..."
      -- rename original database file name to backup file name
  cmdText="ren" '"'dbFileName'"' filespec("Name", newBkpFileName)
  say "DOS command:" pp(cmdText)
  address cmd cmdText               -- use ADDRESS CMD explicitly

      -- now rename new compressed file to original databse file name
  cmdText="ren" '"'compressedName'"' filespec("Name", dbFileName)
  say "DOS command:" pp(cmdText)
  address cmd cmdText
  say center(" end of compressAndRepair ", 70, "-")
  say

::routine pp
   return "[" || arg(1) || "]"

::requires "net.cls"
