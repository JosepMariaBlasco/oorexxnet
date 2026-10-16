; SPDX-License-Identifier: Apache-2.0
;
; oorexxnet.nsi: the Windows installer of the ooRexx/.NET bridge, an NSIS 3
; script. A thin wrapper around install.rex, which does the real work on
; every system (the files, the samples, the list of what it installed, the
; check): this program finds ooRexx and .NET, runs install.rex, and adds what
; a Windows user expects (an entry in Settings > Apps, shortcuts in ooRexx's
; Start menu folder, an uninstaller). Modelled on ooRexx/Python's installer,
; itself modelled on ooRexx's own and ooSQLite's.
;
;   makensis -DVERSION=V -DPKGDIR=<the unzipped rexxnet folder>
;            -DLICENSEFILE=<the LICENSE> -DOUTFILE=<the .exe to write>
;            [-DBOOKSDIR=<a folder with dotnetref.pdf and dotnetcookbook.pdf>]
;            oorexxnet.nsi
;
; (bridge/windows-installer.sh does it from the binary zip.) Run it as:
;   oorexxnet-VERSION-setup.exe                         (the wizard)
;   ... /S [/CLR] [/D=C:\ooRexx folder]                 (silent: /D last)
; /CLR: CLR.CLS beside rexx.exe even when another one (BSF4ooRexx's) is found
; first (install.rex's --clr).
;
; .NET is not installed by this program: .NET 8 or later is needed, and its
; Desktop Runtime for Windows Forms. When it is missing, a page says so and
; gives the link to Microsoft's download page (nothing is opened by itself);
; with no .NET at all the installation cannot go on.

Unicode true
!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "StrFunc.nsh"
!include "Sections.nsh"
${StrRep}

!ifndef VERSION | PKGDIR | LICENSEFILE | OUTFILE
  !error "makensis -DVERSION=... -DPKGDIR=... -DLICENSEFILE=... -DOUTFILE=... oorexxnet.nsi"
!endif

!define NAME        "ooRexx/.NET"
!define LONGNAME    "ooRexx/.NET ${VERSION}"
!define REGKEY      "Software\Microsoft\Windows\CurrentVersion\Uninstall\ooRexxNet"
!define REXXREGKEY  "Software\Microsoft\Windows\CurrentVersion\Uninstall\ooRexx"
!define UNINSTALLER "uninstall-oorexxnet.exe"
!define SMFOLDER    "$SMPROGRAMS\Open Object Rexx"       ; ooRexx's own
!define SMDOCS      "${SMFOLDER}\ooRexx Documentation"
!define SMSAMPLES   "${SMFOLDER}\ooRexx Samples"
!define SAMPLES     "$INSTDIR\samples\dotnet"            ; where install.rex puts them (and the guide)
!define LOG         "$TEMP\oorexxnet-install.log"        ; kept: what happened
!define DOTNETURL   "https://dotnet.microsoft.com/download/dotnet"
!define HOMEPAGE    "https://github.com/JosepMariaBlasco/oorexxnet"

Name "${NAME}"
Caption "${LONGNAME}"
OutFile "${OUTFILE}"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show
InstallDir "$PROGRAMFILES64\ooRexx"
BrandingText "${LONGNAME}"

VIProductVersion "0.0.0.0"
VIAddVersionKey "ProductName" "${NAME}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "FileDescription" "${LONGNAME} installer"
VIAddVersionKey "LegalCopyright" "Apache License 2.0"

Var Dialog
Var DotnetRoot      ; where .NET is (or the default folder)
Var DotnetCore      ; the newest .NET's major version, or 0 (none, or older than 8)
Var DotnetDesktop   ; 1: that .NET has its Desktop Runtime
Var ClrArg          ; " --clr" or ""
Var Problem

!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TEXT "This wizard installs the ${LONGNAME} bridge into an \
  installed ooRexx (5 or later, 64-bit): Rexx programs then use .NET with \
  ::requires $\"net.cls$\", with no environment variable to set. Its samples \
  go to ooRexx's samples folder, under dotnet.$\r$\n$\r$\n.NET 8 or later is \
  needed (its Desktop Runtime for Windows Forms).$\r$\n$\r$\nClose any program \
  that uses the bridge before you continue."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${LICENSEFILE}"
!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_COMPONENTS
!define MUI_DIRECTORYPAGE_TEXT_TOP "The bridge is installed into ooRexx's folder, \
  the one with rexx.exe and rexx.dll."
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "ooRexx folder"
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE RexxFolderLeave
!insertmacro MUI_PAGE_DIRECTORY
Page custom DotnetPage
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_LINK "github.com/JosepMariaBlasco/oorexxnet"
!define MUI_FINISHPAGE_LINK_LOCATION "${HOMEPAGE}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

;-------------------------------------------------------------------------------
; Installer


; .NET where the bridge looks for it (as hostfxr and install.rex do:
; DOTNET_ROOT_X64, DOTNET_ROOT, then Program Files\dotnet): the newest major
; version of Microsoft.NETCore.App (8 or later), and whether
; Microsoft.WindowsDesktop.App has it too
Function FindDotnet
  StrCpy $DotnetCore 0
  StrCpy $DotnetDesktop 0
  StrCpy $DotnetRoot "$PROGRAMFILES64\dotnet"
  ReadEnvStr $0 "DOTNET_ROOT_X64"
  ${If} $0 != ""
    Push $0
    Call TryDotnetRoot
  ${EndIf}
  ${If} $DotnetCore == 0
    ReadEnvStr $0 "DOTNET_ROOT"
    ${If} $0 != ""
      Push $0
      Call TryDotnetRoot
    ${EndIf}
  ${EndIf}
  ${If} $DotnetCore == 0
    Push "$PROGRAMFILES64\dotnet"
    Call TryDotnetRoot
  ${EndIf}
FunctionEnd

Function TryDotnetRoot          ; stack: a folder
  Exch $0
  Push $1
  Push "$0\shared\Microsoft.NETCore.App"
  Call NewestMajor
  Pop $1
  ${If} $1 >= 8
    StrCpy $DotnetRoot $0
    StrCpy $DotnetCore $1
    Push "$0\shared\Microsoft.WindowsDesktop.App"
    Push $1
    Call HasMajor
    Pop $DotnetDesktop
  ${EndIf}
  Pop $1
  Pop $0
FunctionEnd

Function NewestMajor            ; stack: a folder of version folders -> the highest major, or 0
  Exch $0
  Push $1
  Push $2
  Push $3
  StrCpy $3 0
  FindFirst $1 $2 "$0\*.*"
  ${DoWhile} $2 != ""
    ${If} ${FileExists} "$0\$2\*.*"
      IntOp $2 $2 + 0           ; "10.0.3" -> 10 (leading digits)
      ${If} $2 > $3
        StrCpy $3 $2
      ${EndIf}
    ${EndIf}
    FindNext $1 $2
  ${Loop}
  FindClose $1
  StrCpy $0 $3
  Pop $3
  Pop $2
  Pop $1
  Exch $0
FunctionEnd

Function HasMajor               ; stack: folder, major -> 1 if a version folder of that major is there
  Exch $1                       ; major
  Exch
  Exch $0                       ; folder
  Push $2
  Push $3
  Push $4
  StrCpy $4 0
  FindFirst $2 $3 "$0\$1.*"
  ${DoWhile} $3 != ""
    ${If} ${FileExists} "$0\$3\*.*"
      StrCpy $4 1
    ${EndIf}
    FindNext $2 $3
  ${Loop}
  FindClose $2
  StrCpy $0 $4
  Pop $4
  Pop $3
  Pop $2
  Exch $0                       ; $0 back, the result on the stack, over $1's
  Exch
  Pop $1
FunctionEnd

Function RexxFolderLeave
  ${IfNot} ${FileExists} "$INSTDIR\rexx.exe"
  ${OrIfNot} ${FileExists} "$INSTDIR\rexx.dll"
    MessageBox MB_OK|MB_ICONEXCLAMATION "There is no ooRexx in $INSTDIR \
      (rexx.exe and rexx.dll).$\r$\n$\r$\nChoose the folder of ooRexx 5 \
      or later (64-bit), or install ooRexx first (sourceforge.net/projects/oorexx)."
    Abort
  ${EndIf}
FunctionEnd

; Shown only when .NET (or its Desktop Runtime) is missing: what to install,
; and a link to Microsoft's download page (opened only if clicked). With no
; .NET 8 or later the installation cannot go on: Next is disabled.
Function DotnetPage
  ${If} $DotnetCore != 0
  ${AndIf} $DotnetDesktop == 1
    Abort                       ; nothing to say: the page is skipped
  ${EndIf}
  ${If} $DotnetCore == 0
    !insertmacro MUI_HEADER_TEXT ".NET" ".NET 8 or later is needed"
  ${Else}
    !insertmacro MUI_HEADER_TEXT ".NET" "The .NET Desktop Runtime is recommended"
  ${EndIf}
  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}
  ${If} $DotnetCore == 0
    ${NSD_CreateLabel} 0 0 100% 60u "The bridge needs .NET 8 or later (64-bit), and \
      none was found in $DotnetRoot.$\r$\n$\r$\nInstall the .NET Desktop Runtime \
      (Windows, x64) of the newest .NET from Microsoft's download page, then run \
      this installer again."
  ${Else}
    ${NSD_CreateLabel} 0 0 100% 60u ".NET $DotnetCore was found in $DotnetRoot, \
      without its Desktop Runtime: the bridge will work, but not Windows Forms \
      (the samples with windows and dialogs).$\r$\n$\r$\nYou can install the \
      .NET Desktop Runtime $DotnetCore (Windows, x64) now or later, from \
      Microsoft's download page, and go on with this installation."
  ${EndIf}
  Pop $0
  ${NSD_CreateLink} 0 66u 100% 12u "${DOTNETURL}"
  Pop $0
  ${NSD_OnClick} $0 OpenDotnetPage
  ${If} $DotnetCore == 0
    GetDlgItem $0 $HWNDPARENT 1   ; Next
    EnableWindow $0 0
  ${EndIf}
  nsDialogs::Show
FunctionEnd

Function OpenDotnetPage
  ExecShell "open" "${DOTNETURL}"
FunctionEnd

Section "ooRexx/.NET" SecMain
  SectionIn RO
  ; (the work is done by the hidden section below, after the options)
SectionEnd

Section /o "CLR.CLS beside rexx.exe, even if BSF4ooRexx's is found first" SecClr
  StrCpy $ClrArg " --clr"       ; install.rex's --clr
SectionEnd

Section "-Install"
  ${If} $DotnetCore == 0
    StrCpy $Problem "No .NET 8 or later (64-bit) was found in $DotnetRoot: install the \
      .NET Desktop Runtime (x64) from ${DOTNETURL}, then run this installer again."
    Goto failed
  ${EndIf}
  ${IfNot} ${FileExists} "$INSTDIR\rexx.exe"
    StrCpy $Problem "There is no ooRexx (rexx.exe) in $INSTDIR."
    Goto failed
  ${EndIf}

  ; the package, unpacked where install.rex can take it from
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\rexxnet"
  File /r "${PKGDIR}\*.*"
  SetOutPath "$PLUGINSDIR"      ; not the folder about to be deleted

  ; install.rex's output goes to ${LOG} (a silent install shows nothing),
  ; then into the details
  FileOpen $2 "${LOG}" w
  FileWrite $2 "${LONGNAME}$\r$\nooRexx: $INSTDIR$\r$\n.NET: $DotnetCore in $DotnetRoot"
  ${If} $DotnetDesktop == 1
    FileWrite $2 " (with its Desktop Runtime)"
  ${Else}
    FileWrite $2 " (no Desktop Runtime: no Windows Forms)"
  ${EndIf}
  FileWrite $2 "$\r$\nrexx install.rex install$ClrArg$\r$\n$\r$\n"
  FileClose $2
  DetailPrint "rexx install.rex install$ClrArg"
  nsExec::Exec '"$SYSDIR\cmd.exe" /c ""$INSTDIR\rexx.exe" "$PLUGINSDIR\rexxnet\install.rex" install$ClrArg >> "${LOG}" 2>&1"'
  Pop $0
  FileOpen $2 "${LOG}" r
  ${Do}
    ClearErrors
    FileRead $2 $3
    ${If} ${Errors}
      ${Break}
    ${EndIf}
    ${StrRep} $3 $3 "$\r" ""
    ${StrRep} $3 $3 "$\n" ""
    DetailPrint $3
  ${Loop}
  FileClose $2
  ${If} $0 != 0
    StrCpy $Problem "install.rex ended with $0: see the details above, or ${LOG}."
    Goto failed
  ${EndIf}

  ; the Start menu (ooRexx's folder): the books (in ooRexx's doc folder,
  ; with ooRexx's own), or else the guide; the samples' README (Markdown:
  ; opened with Notepad, which shows it on Windows 11), the samples'
  ; folder, the uninstaller
  CreateDirectory "${SMDOCS}"
!ifdef BOOKSDIR
  SetOutPath "$INSTDIR\doc"
  File "${BOOKSDIR}\dotnetref.pdf"
  File "${BOOKSDIR}\dotnetcookbook.pdf"
  SetOutPath "$PLUGINSDIR"
  CreateShortCut "${SMDOCS}\ooRexx and .NET - Reference.lnk" "$INSTDIR\doc\dotnetref.pdf"
  CreateShortCut "${SMDOCS}\ooRexx and .NET - Cookbook.lnk" "$INSTDIR\doc\dotnetcookbook.pdf"
!else
  CreateShortCut "${SMDOCS}\ooRexx and .NET - Guide.lnk" "$WINDIR\notepad.exe" '"${SAMPLES}\guide.md"'
!endif
  CreateDirectory "${SMSAMPLES}"
  CreateShortCut "${SMSAMPLES}\ooRexx and .NET samples.lnk" "${SAMPLES}"
  CreateShortCut "${SMSAMPLES}\ooRexx and .NET samples - README.lnk" "$WINDIR\notepad.exe" '"${SAMPLES}\README.md"'
  CreateShortCut "${SMFOLDER}\Uninstall ooRexx-.NET.lnk" "$INSTDIR\${UNINSTALLER}"

  WriteUninstaller "$INSTDIR\${UNINSTALLER}"
  WriteRegStr HKLM "${REGKEY}" "DisplayName" "${NAME}"
  WriteRegStr HKLM "${REGKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${REGKEY}" "Publisher" "The ooRexx/.NET project"
  WriteRegStr HKLM "${REGKEY}" "URLInfoAbout" "${HOMEPAGE}"
  WriteRegStr HKLM "${REGKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${REGKEY}" "DisplayIcon" "$INSTDIR\rexx.exe"
  WriteRegStr HKLM "${REGKEY}" "UninstallString" '"$INSTDIR\${UNINSTALLER}"'
  WriteRegStr HKLM "${REGKEY}" "QuietUninstallString" '"$INSTDIR\${UNINSTALLER}" /S'
  WriteRegDWORD HKLM "${REGKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${REGKEY}" "NoRepair" 1
  ${GetSize} "${SAMPLES}" "/S=0K" $0 $1 $2
  IntOp $0 $0 + 2000            ; the bridge itself, beside rexx.exe (about 2 MB)
  WriteRegDWORD HKLM "${REGKEY}" "EstimatedSize" $0
  DetailPrint "${LONGNAME}: installed"
  Return

  failed:
  DetailPrint "ooRexx/.NET: $Problem"
  ${IfNot} ${Silent}
    MessageBox MB_OK|MB_ICONSTOP "The installation failed.$\r$\n$\r$\n$Problem"
  ${EndIf}
  SetErrorLevel 2
  Abort
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} "The bridge (net.cls, its libraries), \
    oodnet.cls, the samples and the books."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecClr} "CLR.CLS (BSF4ooRexx's CLR.CLS API, on \
    this bridge) is installed beside rexx.exe unless another CLR.CLS (BSF4ooRexx's) \
    would be found first: its programs keep it. Choose this to install ours anyway."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; (after the sections: it selects SecClr for /CLR)
Function .onInit
  SetShellVarContext all
  ; ooRexx's installer (32-bit) writes its key in the 32-bit view: look
  ; there first, then in the 64-bit one
  ReadRegStr $0 HKLM "${REXXREGKEY}" "UnInstallLocation"
  ${If} $0 == ""
    SetRegView 64
    ReadRegStr $0 HKLM "${REXXREGKEY}" "UnInstallLocation"
    SetRegView lastused
  ${EndIf}
  ${If} $0 != ""
    StrCpy $INSTDIR $0
  ${EndIf}
  ; /D= (silent installs) overrides it: NSIS sets $INSTDIR after .onInit
  StrCpy $ClrArg ""
  ${GetParameters} $1
  ClearErrors
  ${GetOptions} $1 "/CLR" $2
  ${IfNot} ${Errors}
    !insertmacro SelectSection ${SecClr}
  ${EndIf}
  Call FindDotnet
FunctionEnd

;-------------------------------------------------------------------------------
; Uninstaller: install.rex's own uninstaller removes what it installed (its
; list); then what this installer added

Function un.onInit
  SetShellVarContext all
FunctionEnd

Section "Uninstall"
  ${If} ${FileExists} "$INSTDIR\oorexxnet-uninstall.rex"
    nsExec::ExecToLog '"$INSTDIR\rexx.exe" "$INSTDIR\oorexxnet-uninstall.rex"'
    Pop $0
    ${If} $0 != 0
      DetailPrint "oorexxnet-uninstall.rex ended with $0"
    ${EndIf}
  ${EndIf}
  Delete "${SMDOCS}\ooRexx and .NET - Guide.lnk"
  Delete "${SMDOCS}\ooRexx and .NET - Reference.lnk"
  Delete "${SMDOCS}\ooRexx and .NET - Cookbook.lnk"
  Delete "$INSTDIR\doc\dotnetref.pdf"
  Delete "$INSTDIR\doc\dotnetcookbook.pdf"
  RMDir "$INSTDIR\doc"          ; only if empty (a portable ooRexx may have had none)
  Delete "${SMSAMPLES}\ooRexx and .NET samples.lnk"
  Delete "${SMSAMPLES}\ooRexx and .NET samples - README.lnk"
  Delete "${SMFOLDER}\Uninstall ooRexx-.NET.lnk"
  RMDir "${SMDOCS}"             ; only if empty (a portable ooRexx has no menu)
  RMDir "${SMSAMPLES}"
  RMDir "${SMFOLDER}"
  DeleteRegKey HKLM "${REGKEY}"
  Delete "$INSTDIR\${UNINSTALLER}"
SectionEnd
