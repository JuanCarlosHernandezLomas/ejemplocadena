@echo off
REM # @(#) MQMBID sn=p945-L260120 su=cf26678a1a640aba7dc4f9c41871946713dc9a38 pn=cmd/install/pc/winnt/web/UnpackFeature.cmd
REM ########################################################################
REM #                                                                      #
REM # Program name: UnpackFeature.cmd                                      #
REM #                                                                      #
REM # Description: Windows batch file to invoke powershell unzip script    #
REM #              unzip.ps1 to unzip feature zip files                    #
REM #                                                                      #
REM # <copyright                                                           #
REM # notice="lm-source-program"                                           #
REM # pids="5724-H72,"                                                     #
REM # years="2016,2023"                                                    #
REM # crc="2387954517" >                                                   #
REM # Licensed Materials - Property of IBM                                 #
REM #                                                                      #
REM #                                                                      #
REM # (C) Copyright IBM Corp. 2016, 2023 All Rights Reserved.              #
REM #                                                                      #
REM # US Government Users Restricted Rights - Use, duplication or          #
REM # disclosure restricted by GSA ADP Schedule Contract with              #
REM # IBM Corp.                                                            #
REM # </copyright>                                                         #
REM #                                                                      #
REM ######################################################################## 
REM #                                                                      #
REM # Usage:                                                               #
REM #                                                                      #
REM # UnpackFeature <relative destination path*> <feature zip name>        #
REM # 1) relative path is relative to INSTALLDIR\zips                      #
REM # 2) zips must be in the INSTALLDIR\zips directory                     #
REM #                                                                      #
REM # e.g. UnpackFeature "..\web" web.zip                                  #
REM #                                                                      #
REM ######################################################################## 
 
setlocal

set zipsdir=%~dp0

REM PARM 1 = relative path to the install location
set destdir=%1
set destdir=%destdir:"=%

REM PARM 2 = filename of the zip to extract there
set zipname=%2
set zipname=%zipname:"=%

REM normalise zipsdir - get rid of the trailing \ a ~dp0 gives you
cd /D %zipsdir%..\zips
set zipsdir=%CD%
echo zipsdir=%zipsdir%

REM normalise destdir and leave that as the current directory
cd /D %zipsdir%\%destdir%
set destdir=%CD%
echo destdir=%destdir%

REM check the zip file exists - don't run the powershell if not
if not exist "%zipsdir%\%zipname%" (
   echo zip file "%zipsdir%\%zipname%" not found
   echo exiting
   goto :EOF
)

REM in the case of WEB only, remove any files and folders 
REM potentially left in INSTALLDIR\web 
set web_dir_list=bin clients dev etc lib mq templates
if "%zipname%"=="mq_wlp.zip" (
   for %%A in (%web_dir_list%) do (
      echo looking for file to delete is "%destdir%\%%A"
      if exist "%destdir%\%%A" (
         for /D  %%X in ("%destdir%\%%A\*.*") do rd /s /q "%%X"
         del /q /f "%destdir%\%%A\*.*" 
      )
   )
)

echo Unpacking feature from file "%zipsdir%\%zipname%"
echo this will take about a minute...

echo ---check powershell is on path---
where powershell.exe
if "%ERRORLEVEL%"=="0" (
  echo powershell.exe found on PATH
) else (
  REM if powewrshell.exe could not be located, issue error and exit non-zero
  echo ERROR: could not locate powershell.exe on the PATH
  endlocal
  exit /B 1001
)

echo ---check powershell version ---
powershell -command "Get-Host"

echo ---call powershell unzip---
powershell -executionpolicy bypass -File "%zipsdir%\UnpackFeature.ps1" "%zipsdir%" "%destdir%"  %zipname%

if "%zipname%"=="mq_wlp.zip" (
  if not exist "%destdir%\README.TXT" (
    REM if the file README.TXT is not present after unzipping  
    REM this indicates the unzip of the package failed, so return non-zero.
    endlocal
    exit /B 1002
  )
)

if "%zipname%"=="mq_jre64.zip" (
  if not exist "%destdir%\jre\bin\java.exe" (
    REM if the file java.exe is not present after unzipping  
    REM this indicates the unzip of the package failed, so return non-zero.
    endlocal
    exit /B 1003
  )
)

endlocal
exit /B 0
