@ECHO OFF
rem ---------------------------------------------------------------------------
rem File Name : genmqpkg.cmd
rem Descriptive File Name : Generate an MQ runtime package
rem ---------------------------------------------------------------------------
rem   <copyright
rem   notice="lm-source-program"
rem   pids="5724-H72"
rem   years="2015,2021"
rem   crc="0" >
rem   Licensed Materials - Property of IBM
rem
rem   5724-H72,
rem
rem   (C) Copyright IBM Corp. 2015, 2021 All Rights Reserved.
rem
rem   US Government Users Restricted Rights - Use, duplication or
rem   disclosure restricted by GSA ADP Schedule Contract with
rem   IBM Corp.
rem   </copyright>
rem ---------------------------------------------------------------------------
rem @(#) MQMBID sn=p945-L260120 su=cf26678a1a640aba7dc4f9c41871946713dc9a38 pn=install/pc/genmqpkg.cmd
rem ---------------------------------------------------------------------------
rem File Description :
rem This script is used to create a smaller runtime package by creating either
rem a second copy of the runtime containing only required objects or by
rem removing objects that are not required from the current runtime package.
rem It does this based on a number of Yes/No answers about the required
rem runtime environment.
rem
rem Usage:
rem  genmqpkg.cmd [-b] [target_dir]
rem  -b:         Run the program in a batch mode, making selections based
rem              on environment variables. Names of the environment variables
rem              are shown after running this program interactively.
rem  target_dir: Where to put the new package. If creating a second copy then
rem              this directory must be empty or not exist. If not provided,
rem              the name is read from stdin.

setlocal enableextensions enabledelayedexpansion

pushd %~dp0.. > NUL
set mqdir=%CD%
popd > NUL

echo.
echo Generate MQ Runtime Package
echo ---------------------------
echo This program will help determine a minimal set of runtime files that are
echo required for a queue manager installation or to be be distributed with a
echo client application. The program will ask a series of questions and then
echo prompt for a filesystem location for the runtime files.
echo.
echo Note that IBM can only provide support assistance for an unmodified set
echo of runtime files.
echo.
echo.

rem Parse the command line arguments.
set useBatch=N
set cmdtgtdir=
set verbose=N
set delfile=N
set removeGenmqpkg=N
set removeFiles=N
set skip_components=
set skip_tags=

:nextarg
set arg=%~1
if {%arg%}=={}           goto :getenv
if not {%cmdtgtdir%}=={} goto :printusage
if {%arg%}=={-?}         goto :printusage
if {%arg%}=={/?}         goto :printusage
if {%arg%}=={-h}         goto :printusage
if {%arg%}=={/h}         goto :printusage
if {%arg%}=={-b} (
  set useBatch=Y
) else if {%arg%}=={/b} (
  set useBatch=Y
) else if {%arg%}=={-v} (
  set verbose=Y
) else if {%arg%}=={/v} (
  set verbose=Y
) else if {%arg:~0,1%}=={-} (
  goto :printusage
) else if {%arg:~0,1%}=={/} (
  goto :printusage
) else (
  set cmdtgtdir=%arg%
)
shift
goto :nextarg

:printusage
echo Usage: genmqpkg.cmd [-b] [target_dir]
echo -b: Run non-interactively, using environment variables to configure
echo target_dir: Directory to contain the regenerated package
goto :endcopy

rem ===================================================================
rem Determine whether a component is to be included, either from the
rem environment, or interactively.
:askquestion
if %useBatch% EQU N goto :askinteractive
set %1=0
if "!genmqpkg_%1!" EQU "1" set %1=1
goto :setskip

:askinteractive
set %1=1
set c=
set /P "c=%2 "
if /I "%c%" EQU "Y" goto :EOF
if /I "%c%" EQU "N" (
  set %1=0
  goto :setskip
)
goto :askinteractive

:setskip
if !%1! EQU 1 goto :EOF
set delfile=Y
if not {%3}=={} set "skip_tags=%skip_tags% %3"
goto :EOF
rem ===================================================================

:getenv
rem read environment variables. Default is to not include a component, that is then
rem overridden by setting the envvar to "1".
call :askquestion inc32 "Does the runtime require 32-bit application support [Y/N]? " 32
call :askquestion incole "Does the runtime require OLE support [Y/N]? " ole
call :askquestion inccpp "Does the runtime require C++ libraries [Y/N]? " cpp
call :askquestion incdnet "Does the runtime require .NET assemblies [Y/N]? " dotnet
call :askquestion inccbl "Does the runtime require COBOL libraries [Y/N]? " cobol
set delfileX=%delfile%
call :askquestion inctls "Does the runtime require SSL/TLS support [Y/N]? "
call :askquestion incams "Does the runtime require AMS support [Y/N]? "
rem We can only delete GSKit if no need for SSL/TLS and no need for AMS
if "%inctls%%incams%"=="00" (
  set incgsk=0
  set "skip_tags=%skip_tags% gskit"
) else (
  set incgsk=1
  set delfile=%delfileX%
)
call :askquestion incmts "Does the runtime require CICS support [Y/N]? " cics
call :askquestion inccics "Does the runtime require MTS support [Y/N]? " mts
call :askquestion incadm "Does the runtime require any administration tools [Y/N]? " adm
call :askquestion incras "Does the runtime require RAS tools [Y/N]? " ras
call :askquestion incsamp "Does the runtime require sample applications [Y/N]? " samp
call :askquestion incxms "Does the runtime require XMS [Y/N]? " xms
call :askquestion incsdk "Does the runtime require the SDK to compile applications [Y/N]? " sdk
rem Check if any MQ Advanced components are needed
if "%incams%"=="0" set "skip_tags=%skip_tags% advanced"

rem See if anything can be deleted
if not %delfile% EQU Y (
  echo.
  echo Sorry, no files can be removed from the MQ runtime package.
  goto :endcopy
)

rem If interactive, you can keep trying to give the name of the target
rem directory. If non-interactive, program exits if target already exists
rem and is not empty unless it's the source directory, in which case
rem unwanted files are deleted.
if "%cmdtgtdir%" EQU "" (
  goto :getinteractivetargetdir
) else (
  goto :getbatchtargetdir
)

:getinteractivetargetdir
echo Please provide a target directory for the runtime package to be created
set /P tgtdir=

if "%tgtdir%" EQU "" goto :getinteractivetargetdir
if not exist "%tgtdir%" goto :dirok
if /I "%tgtdir%" EQU "%mqdir%" (
  set removeFiles=Y
  goto :dirok
)
for /F %%i in ('dir /b "%tgtdir%\*.*"') do (
  echo Target directory '%tgtdir%' already exists and is not empty, please specify a new target or
  echo %mqdir% to update this package.
  echo.
  if %useBatch% EQU Y (
    goto :endcopy
  ) else (
    goto :getinteractivetargetdir
  )
)
goto :dirok

:getbatchtargetdir
set tgtdir=%cmdtgtdir%
if not exist "%tgtdir%" goto :dirok
if /I "%tgtdir%" EQU "%mqdir%" (
  set removeFiles=Y
  goto :dirok
)
for /F %%i in ('dir /b "%tgtdir%\*.*"') do (
  echo Target directory '%tgtdir%' already exists and is not empty, please specify a new target or
  echo %mqdir% to update this package.
  echo.
  goto :endcopy
)
goto :dirok

:dirok
echo.
echo The MQ runtime package will be created in
echo.
echo %tgtdir%
echo.

rem Interactive mode gives a final chance to bail out.
if %useBatch% EQU Y (
  goto :copyfiles
)

:confirm
  set /P "c=Are you sure you want to continue [Y/N]? "
  if /I "%c%" EQU "Y" goto :showenv
  if /I "%c%" EQU "N" (
    echo.
    echo Creation of MQ runtime package cancelled by user.
    goto :endcopy
  )
goto confirm

:showenv
rem Tell users how they can repeat the interactive choices in future.
if %useBatch% EQU N (
  echo.
  echo To repeat this set of choices, you can set these environment
  echo variables and rerun this program with the -b option. The target
  echo directory is given as the last option on the command line.
  echo.
  for /f "usebackq" %%i in (`set inc ^| findstr "=[01]"`) do echo SET genmqpkg_%%i
  echo.
  goto :copyfiles
)

:copyfiles
if not exist "%mqdir%\MANIFEST" (
  echo The package MANIFEST does not exist; no files can be removed from the MQ runtime package.
  goto :endcopy
)

goto :processFiles

rem ===================================================================
rem Process a file from the manifest
:processFile
set file=%1
set name=%~nx1
set dirname=!file:%name%=!
set component=%2
set checksum=%3
set tags=%~4
set tags=%tags: =%

rem Ignore incomplete or blank lines
if "%tags%"=={} goto :EOF

rem Ignore comments
if "%file:~0,1%" EQU "#" goto :EOF

rem Check if this file is from a component we want to skip
if "%skip_components%" EQU "" goto :checkTags
set matched=N
call :match "%component%" "%skip_components%"
if %matched% EQU N goto :checkTags
if %removeFiles% EQU Y (
  call :debug Removing file "%mqdir%\%file%" due to matching component %component%
  if exist "%mqdir%\%file%" del /q "%mqdir%\%file%"
) else (
  call :debug Skipping file "%mqdir%\%file%" due to matching component %component%
)
goto :EOF

:checkTags
if "%skip_tags%" EQU "" goto :checkMore
set matched=N
set remaining=%tags%
:checkNextTag
for /F "delims=: tokens=1*" %%I in ("%remaining%") do (
  call :match %%I "%skip_tags%"
  set remaining=%%J
)
if not "%remaining%"=="" goto :checkNextTag
if %matched% EQU N goto :checkMore
if %removeFiles% EQU Y (
  call :debug Removing file "%mqdir%\%file%" due to matching tag %tags%
  if exist "%mqdir%\%file%" del /q "%mqdir%\%file%"
) else (
  call :debug Skipping file "%mqdir%\%file%" due to matching tag %tags%
)
goto :EOF

:checkMore
if not "%file%" EQU "bin\genmqpkg.cmd" goto :keepFile
if %removeFiles% EQU Y (
  call :debug Deferring removal of file "%mqdir%\%file%" until later
  set removeGenmqpkg=Y
) else (
  call :debug Skipping file "%mqdir%\%file%"
)
goto :EOF

:keepFile
if %removeFiles% EQU Y (
  call :debug Leaving file "%mqdir%\%file%"
) else (
  call :debug Copying file "%mqdir%\%file%" to "%tgtdir%\%file%"
  rem We've determined this file should be copied
  rem Create the target directory if it doesn't already exist
  if not exist "%tgtdir%\%dirname%" mkdir "%tgtdir%\%dirname%"

  rem Copy the file to the target directory
  set copyOutput=
  for /f "usebackq delims=" %%I in (`copy "%mqdir%\%file%" "%tgtdir%\%dirname%" /y`) do set copyOutput="%copyOutput %%I"
  if not errorlevel 0 echo %copyOutput%
)
goto :EOF
rem ===================================================================


rem ===================================================================
rem Check if the specified text is found in the specified list
:match
set text=%~1
set list=%~2
set removed=!list:%text%=!
if not x"%removed%"==x"%list%" set matched=Y
goto :EOF
rem ===================================================================


rem ===================================================================
rem Echo all parameters passed to the function when in verbose mode
:debug
if %verbose% EQU Y echo %*
goto :EOF
rem ===================================================================


:processFiles
rem Look at all the files in the package to determine which ones we should copy
for /F "tokens=1,2,3,4 delims=," %%I in (%mqdir%\MANIFEST) do call :processFile %%I %%J %%K "%%L"

rem Tidy up any orphaned directories
if %removeFiles% EQU Y (
  for /F "delims=" %%I in ('dir /s /b /ad %mqdir% ^| sort /r') do rmdir "%%I" 2>NUL
)

:gencomp
echo.
echo Generation complete !
if %removeFiles% EQU Y (
  echo MQ runtime package created in '%tgtdir%'
) else (
  echo MQ runtime package copied to '%tgtdir%'
)

:endcopy
echo.

rem Remove genmqpkg now if necessary
if %removeGenmqpkg% EQU Y (
  (goto) 2>NUL & if exist "%mqdir%\bin\genmqpkg.cmd" del /q "%mqdir%\bin\genmqpkg.cmd"
)
