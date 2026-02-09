@echo off
REM ---------------------------------------------------------------------------
REM File Name : amqidsec.bat
REM Descriptive File Name : Windows file/Directory security updater
REM ---------------------------------------------------------------------------
REM   <copyright
REM   notice="lm-source-program"
REM   pids="5724-H72"
REM   years="2019,2025"
REM   crc="4107220323" >
REM   Licensed Materials - Property of IBM
REM
REM   5724-H72
REM
REM   (C) Copyright IBM Corp. 2019,2025 All Rights Reserved.
REM
REM   US Government Users Restricted Rights - Use, duplication or
REM   disclosure restricted by GSA ADP Schedule Contract with
REM   IBM Corp.
REM   </copyright>
REM ---------------------------------------------------------------------------
REM @(#) MQMBID sn=p945-L260120 su=cf26678a1a640aba7dc4f9c41871946713dc9a38 pn=cmd/install/pc/winnt/amqidsec/amqidsec.bat
REM ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion
echo start time: %TIME%

REM *******************************************************
REM Throughout this script return values of 0 indicate
REM success.  A parsing error comes back as a 255 and a
REM "can't find this file" appears to come back as 999.
REM 1 is left free for warning if it turns out to be needed.
REM
REM Other failures during the script now come back as a
REM four digit number with each subroutine having a unique
REM two digit prefix and the remaining digits being
REM assigned sequentially, 01 for the first error in the
REM subroutine etc.
REM
REM This is intended to help in the situation where we get
REM failing install log (which reports this code) but no
REM amqidsec log.
REM
REM RETVALs are assigned with the complete literal rather
REM than %ERROR_PREFIX%01 etc, to aid searchability.
REM *******************************************************
set RETVAL=0
set RETVAL_ON_ERROR=2
REM error prefix=10

REM *******************************************************
REM what user am I running as?
REM *******************************************************
echo -----------------------------------------------------------------------
echo running as userid:
whoami

REM *******************************************************
REM get WINDIR
REM *******************************************************
echo -----------------------------------------------------------------------
echo looking up WINDIR

if "%WINDIR%"=="" (
  echo ***ERROR: Unable to lookup environment variable WINDIR
  set RETVAL=1001
  goto :exit_script
)

REM *******************************************************
REM Add system32 to path (just in case) otherwise we will
REM fail if user does not have it set
REM *******************************************************
set PATH=%WINDIR%\System32;%PATH%

REM *******************************************************
REM Must have admin rights to run this script
REM required for changing the security settings
REM *******************************************************
echo -----------------------------------------------------------------------
echo Checking for admin access

"%WINDIR%\System32\net" session >nul 2>&1
set NET_SESSION_ERRORLEVEL=%ERRORLEVEL%
if "%NET_SESSION_ERRORLEVEL%"=="0" (
  echo Confirmed user has admin rights
) else (
  echo ***WARNING: Must be run with Administrator rights, rc was %NET_SESSION_ERRORLEVEL%
)

REM *******************************************************
REM Check argument(s)
REM *******************************************************
echo -----------------------------------------------------------------------
echo parse user arguments

set INSTALLATION=
set FIXPACK_LEVEL=NA
echo arg1=%1
echo arg2=%2
echo arg3=%3

if "%1"=="" (
  echo "***ERROR: usage one of:"
  echo "***ERROR: amqidsec.bat installationname"
  echo "***ERROR: amqidsec.bat -fixpack v.r.m.f"
  echo "***ERROR: amqidsec.bat -maint installationname"
  set RETVAL=1002
  goto :exit_script
)

if "%1"=="-fixpack" (
  if "%2"=="" (
    echo "***ERROR: usage:  amqidsec.bat -fixpack v.r.m.f"
    set RETVAL=1003
    goto :exit_script
  )
  set INSTALLATION=NA
  set FIXPACK_LEVEL=%2
  echo Secure fix pack level "!FIXPACK_LEVEL!"
)

if "%1"=="-maint" (
  if "%2"=="" (
    echo "***ERROR: usage: amqidsec -maint installationname"
    set RETVAL=1004
    goto :exit_script
  )
  set INSTALLATION=%2
  echo Secure Installation "!INSTALLATION!" Maint directories
)

if "%INSTALLATION%"=="" (
  set INSTALLATION=%1
  echo Secure Installation "!INSTALLATION!"
)

REM *******************************************************
REM Well known SIDS - to allow for use on NLS machines
REM *******************************************************
echo -----------------------------------------------------------------------
echo Well known SIDS

REM Everyone
set EVERYONE=*S-1-1-0
echo Everyone=%EVERYONE%

REM BUILTIN\USERS
set USERS=*S-1-5-32-545
echo BUILTIN\Users=%USERS%

REM CREATOR_OWNER
set OWNER=*S-1-3-0
echo CREATOR OWNER=%OWNER%

REM BUILTIN\ADMINISTRATORS
set ADMINS=*S-1-5-32-544
echo BUILTIN\Administrators=%ADMINS%

REM NT AUTHORITY\SYSTEM
set SYSTEM=*S-1-5-18
echo NT AUTHORITY\SYSTEM=%SYSTEM%

REM *******************************************************
REM uncomment to skip registry lookups and hard code
REM the value of PGM_DIR
REM *******************************************************
REM set PGM_DIR=C:\Program Files\IBM\MQ
REM echo PGM_DIR="%PGM_DIR%"
REM goto :skip_registry_lookup


REM *******************************************************
REM if this is an amqidsec -fixpack (secure fixpack) call
REM fix pack securing function then exit
REM *******************************************************
if "%1"=="-fixpack" (
  call :secure_fix_pack %FIXPACK_LEVEL%
  goto :exit_script
)

REM *******************************************************
REM Get FilePath (program directory location) from registry
REM *******************************************************
echo -----------------------------------------------------------------------
echo.
echo -- Get registry setting for value FilePath
set REG_LINE=
echo Seeking reg value "HKLM\SOFTWARE\IBM\WebSphere MQ\Installation\%INSTALLATION%\Filepath"
for /F "usebackq delims=" %%A in (`%WINDIR%\System32\reg query "HKLM\SOFTWARE\IBM\WebSphere MQ\Installation"\%INSTALLATION% /v Filepath /reg:64`) do set REG_LINE=%%A
if "%REG_LINE%"=="" (
  echo ***ERROR: Unable to get Filepath line from registry, exiting
  set RETVAL=1005
  goto :exit_script
) else (
  echo REG_LINE="%REG_LINE%"
)

echo.
echo -- Parse line containing FilePath
set PGM_DIR=
for /f "tokens=2* delims= " %%A in ("%REG_LINE%") do set f3=%%B
set PGM_DIR=%f3%
if "%PGM_DIR%"=="" (
  echo ***ERROR: Unable to parse Filepath, exiting
  set RETVAL=1006
  goto :exit_script
) else (
  echo Filepath is "%PGM_DIR%"
)

echo.
echo -- Check parsed location actually exists
if exist "%PGM_DIR%" (
  echo Filepath "%PGM_DIR%" exists
) else (
  echo ***ERROR: Filepath directory "%PGM_DIR%" does not exist, exiting
  set RETVAL=1007
  goto :exit_script
)

REM *******************************************************
REM Get WorkPath (data directory location) from registry
REM *******************************************************
echo.
echo -- Get registry setting for value WorkPath
set REG_LINE=
echo Seeking reg value "HKLM\SOFTWARE\IBM\WebSphere MQ\WorkPath"
for /F "usebackq delims=" %%A in (`%WINDIR%\System32\reg query "HKLM\SOFTWARE\IBM\WebSphere MQ" /v WorkPath /reg:64`) do set REG_LINE=%%A
if "%REG_LINE%"=="" (
  echo ***ERROR: Unable to get WorkPath line from registry, exiting
  set RETVAL=1008
  goto :exit_script
) else (
  echo REG_LINE="%REG_LINE%"
)

echo.
echo -- Parse line containing WorkPath
set DATA_DIR=
for /f "tokens=2* delims= " %%A in ("%REG_LINE%") do set f3=%%B
set DATA_DIR=%f3%
if "%DATA_DIR%"=="" (
  echo ***ERROR: Unable to parse WorkPath, exiting
  set RETVAL=1009
  goto :exit_script
) else (
  echo WorkPath is "%DATA_DIR%"
)

echo.
echo -- Check parsed location actually exists
if exist "%DATA_DIR%" (
  echo WorkPath "%DATA_DIR%" exists
) else (
  echo ***ERROR: WorkPath directory "%DATA_DIR%" does not exist, exiting
  set RETVAL=1010
  goto :exit_script
)

:skip_registry_lookup

REM *******************************************************
REM if this is an amqidsec -maint (secure Maint directories)
REM call Maint directory securing function then exit
REM *******************************************************
if "%1"=="-maint" (
  call :secure_maint_directories %INSTALLATION%
  goto :exit_script
)


REM *******************************************************
REM Get VRMF from registry and check for KILL SWITCH
REM *******************************************************
echo -----------------------------------------------------------------------
echo.
echo -- Get registry setting for value VRMF
set REG_LINE=
for /F "usebackq delims=" %%A in (`%WINDIR%\System32\reg query "HKLM\SOFTWARE\IBM\WebSphere MQ\Installation\%INSTALLATION%" /v VRMF /reg:64`) do set REG_LINE=%%A
if "%REG_LINE%"=="" (
  echo ***ERROR: VRMF for Installation '%INSTALLATION%' not found in registry, exiting
  set RETVAL=1011
  goto :exit_script
) else (
  echo VRMF REG_LINE="%REG_LINE%"
)

echo.
echo -- Parse line containing VRMF
set REG_VRMF=
for /f "tokens=2* delims= " %%A in ("%REG_LINE%") do set f3=%%B
set REG_VRMF=%f3%
if "%REG_VRMF%"=="" (
  echo ***ERROR: Unable to parse VRMF, exiting
  set RETVAL=1012
  goto :exit_script
) else (
  echo VRMF is "%REG_VRMF%"
)

echo -- Check for Kill switch in registry
echo Kill switch name is SKIP_AMQIDSEC_%REG_VRMF%
%WINDIR%\System32\reg query "HKLM\SOFTWARE\IBM\WebSphere MQ" /v SKIP_AMQIDSEC_%REG_VRMF% /reg:64
if "%ERRORLEVEL%"=="0" (
  echo KILL SWITCH FOUND - Exiting script with return code zero [PASS]
  set RETVAL=0
  goto :exit_script
) else (
  echo KILL SWITCH ABSENT - script will be executed
)

REM *******************************************************
REM dump security settings to file before changing anything
REM *******************************************************
call :save_security_settings
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error saving permissions for the program directory
  goto :exit_script
)

REM *******************************************************
REM Check for unexpected directories under program directory
REM *******************************************************
call :check_allowed_directories_only
if not "%RETVAL%"=="0" (
  echo ***ERROR: Unexpected directories found in program directory
  goto :exit_script
)

REM *******************************************************
REM Set directory security
REM *******************************************************
call :do_AMQP_MQXR amqp
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\amqp" directory
  goto :exit_script
)

call :do_standard_security bin
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\bin" directory
  goto :exit_script
)

call :do_standard_security bin64
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\bin64" directory
  goto :exit_script
)

call :do_standard_security conv
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\conv" directory
  goto :exit_script
)

call :do_standard_security doc
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\doc" directory
  goto :exit_script
)

if exist "%PGM_DIR%\gskit8" (
  call :do_standard_security gskit8
  if not "%RETVAL%"=="0" (
    echo ***ERROR: Error setting permissions on the "%PGM_DIR%\gskit8" directory
    goto :exit_script
  )
)

if exist "%PGM_DIR%\gskit9" (
  call :do_standard_security gskit9
  if not "%RETVAL%"=="0" (
    echo ***ERROR: Error setting permissions on the "%PGM_DIR%\gskit9" directory
    goto :exit_script
  )
)

call :do_standard_security java
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\java" directory
  goto :exit_script
)

call :do_standard_security Licenses
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\Licenses" directory
  goto :exit_script
)

call :do_standard_security MQExplorer
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\MQExplorer" directory
  goto :exit_script
)

REM handling collocated mqft directory
call :do_standard_security mqft\ant
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\mqft\ant" directory
  goto :exit_script
)
call :do_standard_security mqft\lib
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\mqft\lib" directory
  goto :exit_script
)
call :do_standard_security mqft\samples
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\mqft\samples" directory
  goto :exit_script
)
call :do_standard_security mqft\sql
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\mqft\sql" directory
  goto :exit_script
)
call :do_standard_security mqft\web
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\mqft\web" directory
  goto :exit_script
)
REM end of mqft subdirectories

call :do_AMQP_MQXR mqxr
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\mqxr" directory
  goto :exit_script
)

call :do_standard_security Readmes
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\Readmes" directory
  goto :exit_script
)

call :do_standard_security samp
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\samp" directory
  goto :exit_script
)

call :do_standard_security swidtag
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\swidtag" directory
  goto :exit_script
)

call :do_standard_security tools
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\tools" directory
  goto :exit_script
)

call :do_standard_security uninst
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\uninst" directory
  goto :exit_script
)

REM handle collocated web directory
call :do_web_security web\bin
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\bin" directory
  goto :exit_script
)
call :do_web_security web\clients
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\clients" directory
  goto :exit_script
)
call :do_web_security web\dev
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\dev" directory
  goto :exit_script
)
call :do_web_security web\etc
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\etc" directory
  goto :exit_script
)
call :do_web_security web\lib
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\lib" directory
  goto :exit_script
)
call :do_web_security web\mq
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\mq" directory
  goto :exit_script
)
call :do_web_security web\templates
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\templates" directory
  goto :exit_script
)
REM end of web subdirectories

call :do_standard_security zips
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\zips" directory
  goto :exit_script
)

call :do_restricted_directory_READONLY uninst
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\uninst" directory
  goto :exit_script
)

call :do_restricted_directory_READONLY zips
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\zips" directory
  goto :exit_script
)

call :do_pgmdir_security
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\" directory
  goto :exit_script
)

REM *******************************************************
REM Process individual files required for collocation
REM *******************************************************
call :set_PROGdir_settings_on_file web\CHANGES.TXT
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\CHANGES.TXT" file
  goto :exit_script
)

call :set_PROGdir_settings_on_file web\Copyright.txt
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\Copyright.txt" file
  goto :exit_script
)

call :set_PROGdir_settings_on_file web\README.TXT
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\README.TXT" file
  goto :exit_script
)

call :set_PROGdir_settings_on_file web\UnpackFeature.log
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\UnpackFeature.log" file
  goto :exit_script
)

call :set_PROGdir_settings_on_file web\UnpackFeatureErr.log
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\web\UnpackFeatureErr.log" file
  goto :exit_script
)

call :set_DATAdir_settings_on_file conv\table\ccsid.tbl
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%DATA_DIR%\conv\table\ccsid.tbl" file
  goto :exit_script
)

call :set_DATAdir_settings_on_file conv\table\ccsid_part2.tbl
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%DATA_DIR%\conv\table\ccsid_part2.tbl" file
  goto :exit_script
)

call :set_DATAdir_settings_on_file conv\table\gmqlccs.tbl
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%DATA_DIR%\conv\table\gmqlccs.tbl" file
  goto :exit_script
)

call :set_mqm_member_only bin64\amqlrepa.exe
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error setting permissions on the "%PGM_DIR%\bin64\amqlrepa.exe" file
  goto :exit_script
)

REM *******************************************************
REM Remove inheritiance
REM *******************************************************
call :do_remove_inheritance
if not "%RETVAL%"=="0" (
  echo ***ERROR: Error Removing security inheritance
  goto :exit_script
)


REM *******************************************************
REM finished processing
REM *******************************************************
:exit_script
echo -----------------------------------------------------------------------
echo.
echo end time: %TIME%
echo returning "%RETVAL%"
exit /B %RETVAL%



REM *******************************************************
REM do_standard_security
REM ====================
REM Set a general purpose level of security for those
REM drectories that do not require special casing
REM *******************************************************
REM error prefix=11
:do_standard_security
echo -----------------------------------------------------------------------
echo %TIME% - start processing directory "%PGM_DIR%\%1"

if not exist "%PGM_DIR%"\%1 (
  echo not processing "%PGM_DIR%\%1" - directory not present
  goto :EOF
)

REM Query permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=1101
call :my_icacls "%PGM_DIR%"\%1
if not "%RETVAL%"=="0" goto :EOF

REM remove all explicit (non-inherited, non-superuser) security from directory
set RETVAL_ON_ERROR=1102
call :my_icacls "%PGM_DIR%"\%1 /remove:g mqm %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF

REM change permissions
set RETVAL_ON_ERROR=1103
call :my_icacls "%PGM_DIR%"\%1 /grant:r %ADMINS%:(OI)(CI)F %SYSTEM%:(OI)(CI)F %OWNER%:(OI)(CI)F
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1104
call :my_icacls "%PGM_DIR%"\%1 /grant:r mqm:(OI)(CI)RX %USERS%:(OI)(CI)RX
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1105
call :my_icacls "%PGM_DIR%"\%1 /grant:r %EVERYONE%:(OI)(CI)R
if not "%RETVAL%"=="0" goto :EOF

REM Query permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1106
call :my_icacls "%PGM_DIR%"\%1

goto :EOF


REM *******************************************************
REM do_pgmdir_security
REM ==================
REM Set the root program directory security
REM *******************************************************
REM error prefix=12
:do_pgmdir_security
echo -----------------------------------------------------------------------
echo %TIME% - start processing PROGRAM directory

if not exist "%PGM_DIR%" (
  echo ***ERROR: not processing "%PGM_DIR%" - directory not present
  set RETVAL=1201
  goto :EOF
)
if not exist "%PGM_DIR%"\isa.xml (
  echo ***ERROR: not processing "%PGM_DIR%\isa.xml" - file not present
  set RETVAL=1202
  goto :EOF
)
if not exist "%PGM_DIR%"\instinfo.tsk (
  echo ***ERROR: not processing "%PGM_DIR%\instinfo.tsk" - file not present
  set RETVAL=1203
  goto :EOF
)
if not exist "%PGM_DIR%"\mqpatch.dat (
  echo ***ERROR: not processing "%PGM_DIR%\mqpatch.dat" - file not present
  set RETVAL=1204
  goto :EOF
)

REM remove all explicit (non-inherited, non-superuser) security from directory
set RETVAL_ON_ERROR=1205
call :my_icacls "%PGM_DIR%"\%1 /remove:g mqm %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF

REM Query program directory permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=1206
call :my_icacls "%PGM_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM Set program directory permissions
set RETVAL_ON_ERROR=1207
call :my_icacls "%PGM_DIR%" /grant:r %ADMINS%:(OI)(CI)F %SYSTEM%:(OI)(CI)F %OWNER%:(OI)(CI)F
if not "%RETVAL%"=="0" goto :EOF

REM yes this should be mqm "Full Control"! The Program dir is set to the
REM permissions of the DATA directory to allow for collocation.
REM Program directory files at its root are set explicitly.
set RETVAL_ON_ERROR=1208
call :my_icacls "%PGM_DIR%" /grant:r mqm:(OI)(CI)F
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1209
call :my_icacls "%PGM_DIR%" /grant:r %USERS%:(OI)(CI)RX
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1210
call :my_icacls "%PGM_DIR%" /grant:r %EVERYONE%:(OI)(CI)RX
if not "%RETVAL%"=="0" goto :EOF

REM Query program directory permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1211
call :my_icacls "%PGM_DIR%"
if not "%RETVAL%"=="0" goto :EOF


REM Query isa.xml permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=1212
call :my_icacls "%PGM_DIR%"\isa.xml
if not "%RETVAL%"=="0" goto :EOF

REM Set isa.xml permissions
set RETVAL_ON_ERROR=1213
call :my_icacls "%PGM_DIR%"\isa.xml /grant:r %ADMINS%:F %SYSTEM%:F %OWNER%:F
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1214
call :my_icacls "%PGM_DIR%"\isa.xml /grant:r mqm:R %USERS%:R
if not "%RETVAL%"=="0" goto :EOF

REM Query isa.xml permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1215
call :my_icacls "%PGM_DIR%"\isa.xml
if not "%RETVAL%"=="0" goto :EOF


REM Query instinfo.tsk permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=1216
call :my_icacls "%PGM_DIR%"\instinfo.tsk
if not "%RETVAL%"=="0" goto :EOF

REM Set instinfo.tsk permissions
set RETVAL_ON_ERROR=1217
call :my_icacls "%PGM_DIR%"\instinfo.tsk /grant:r %ADMINS%:F %SYSTEM%:F %OWNER%:F
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1218
call :my_icacls "%PGM_DIR%"\instinfo.tsk /grant:r mqm:R %USERS%:R
if not "%RETVAL%"=="0" goto :EOF

REM Query instinfo.tsk permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1219
call :my_icacls "%PGM_DIR%"\instinfo.tsk
if not "%RETVAL%"=="0" goto :EOF


REM Query mqpatch.dat permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=1220
call :my_icacls "%PGM_DIR%"\mqpatch.dat
if not "%RETVAL%"=="0" goto :EOF

REM Set mqpatch.dat permissions
set RETVAL_ON_ERROR=1221
call :my_icacls "%PGM_DIR%"\mqpatch.dat /grant:r %ADMINS%:F %SYSTEM%:F %OWNER%:F
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1222
call :my_icacls "%PGM_DIR%"\mqpatch.dat /grant:r mqm:R %USERS%:R %EVERYONE%:R
if not "%RETVAL%"=="0" goto :EOF

REM Query mqpatch.dat permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1223
call :my_icacls "%PGM_DIR%"\mqpatch.dat
if not "%RETVAL%"=="0" goto :EOF

goto :EOF

REM *******************************************************
REM do_web_security
REM ========================
REM Set security settings for web directory
REM *******************************************************
REM error prefix=13
:do_web_security
echo -----------------------------------------------------------------------
echo %TIME% - start postprocessing web directory

if not exist "%PGM_DIR%"\%1 (
  echo not processing "%1" - directory not present
  goto :EOF
)

REM Query permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=1301
call :my_icacls "%PGM_DIR%"\%1
if not "%RETVAL%"=="0" goto :EOF

REM remove all explicit (non-inherited, non-superuser) security from directory
set RETVAL_ON_ERROR=1302
call :my_icacls "%PGM_DIR%"\%1 /remove:g mqm %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF


REM change permissions
set RETVAL_ON_ERROR=1303
call :my_icacls "%PGM_DIR%"\%1 /grant:r %ADMINS%:(OI)(CI)F %SYSTEM%:(OI)(CI)F %OWNER%:(OI)(CI)F
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1304
call :my_icacls "%PGM_DIR%"\%1 /grant:r mqm:(OI)(CI)RX
if not "%RETVAL%"=="0" goto :EOF

REM Query permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1305
call :my_icacls "%PGM_DIR%"\%1

goto :EOF

REM *******************************************************
REM do_restricted_directory_READONLY
REM ===========================
REM Tweak security settings for uninst and zips directories
REM *******************************************************
REM error prefix=14
:do_restricted_directory_READONLY
echo -----------------------------------------------------------------------
echo %TIME% - start postprocessing %1 directory

if not exist "%PGM_DIR%"\%1 (
  echo not processing "%1" - directory not present
  goto :EOF
)

REM Query permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=1401
call :my_icacls "%PGM_DIR%"\%1
if not "%RETVAL%"=="0" goto :EOF

REM remove all explicit (non-inherited, non-superuser) security from directory
set RETVAL_ON_ERROR=1402
call :my_icacls "%PGM_DIR%"\%1 /remove:g mqm %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF

REM change permissions
set RETVAL_ON_ERROR=1403
call :my_icacls "%PGM_DIR%"\%1 /grant:r mqm:(OI)(CI)R %USERS%:(OI)(CI)R %EVERYONE%:(OI)(CI)R
if not "%RETVAL%"=="0" goto :EOF

REM Query permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1404
call :my_icacls "%PGM_DIR%"\%1

goto :EOF

REM *******************************************************
REM do_AMQP_MQXR
REM ===========================
REM Set Security on MQXR and AMQP
REM *******************************************************
REM error prefix=15
:do_AMQP_MQXR
echo -----------------------------------------------------------------------
echo %TIME% - start processing "%PGM_DIR%\%1" directory

REM leave if no XR or AMPQ installed
if not exist "%PGM_DIR%"\%1 (
  echo not processing "%PGM_DIR%\%1" - directory not present
  goto :EOF
)

REM skip the ...\bin directory if not present - infrastructure issues
if not exist "%PGM_DIR%\%1\bin" (
  goto :skip_do_AMQP_MQXR_bin
)

REM Query permissions before changing [amqp|mqxr]\bin dir
echo.
echo PERMISSIONS BEFORE "%PGM_DIR%\%1\bin CHANGES"...
set RETVAL_ON_ERROR=1501
call :my_icacls "%PGM_DIR%"\%1\bin
if not "%RETVAL%"=="0" goto :EOF

REM remove all explicit (non-inherited, non-superuser) security from directory
set RETVAL_ON_ERROR=1502
call :my_icacls "%PGM_DIR%"\%1\bin /remove:g mqm %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF

REM change permissions on [amqp|mqxr]\bin dir - no User execute on bin directory
set RETVAL_ON_ERROR=1503
call :my_icacls "%PGM_DIR%"\%1\bin /grant:r %ADMINS%:(OI)(CI)F %SYSTEM%:(OI)(CI)F %OWNER%:(OI)(CI)F
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1504
call :my_icacls "%PGM_DIR%"\%1\bin /grant:r mqm:(OI)(CI)RX
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1505
call :my_icacls "%PGM_DIR%"\%1\bin /grant:r %USERS%:(OI)(CI)R %EVERYONE%:(OI)(CI)R
if not "%RETVAL%"=="0" goto :EOF

REM Query permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1506
call :my_icacls "%PGM_DIR%"\%1\bin
if not "%RETVAL%"=="0" goto :EOF

:skip_do_AMQP_MQXR_bin

REM Query permissions before changing [amqp|mqxr] dir
echo.
echo PERMISSIONS BEFORE "%PGM_DIR%\%1" CHANGES...
set RETVAL_ON_ERROR=1507
call :my_icacls "%PGM_DIR%"\%1
if not "%RETVAL%"=="0" goto :EOF

REM remove all explicit (non-inherited, non-superuser) security from directory
set RETVAL_ON_ERROR=1508
call :my_icacls "%PGM_DIR%"\%1 /remove:g mqm %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF

REM change permissions on [amqp|mqxr] dir - standard settings
set RETVAL_ON_ERROR=1509
call :my_icacls "%PGM_DIR%"\%1 /grant:r %ADMINS%:(OI)(CI)F %SYSTEM%:(OI)(CI)F %OWNER%:(OI)(CI)F
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1510
call :my_icacls "%PGM_DIR%"\%1 /grant:r mqm:(OI)(CI)RX %USERS%:(OI)(CI)RX
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=1511
call :my_icacls "%PGM_DIR%"\%1 /grant:r %EVERYONE%:(OI)(CI)R
if not "%RETVAL%"=="0" goto :EOF

REM Query permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1512
call :my_icacls "%PGM_DIR%"\%1

goto :EOF


REM *******************************************************
REM do_remove_inheritance
REM ===========================
REM Remove inheritance from the directories we have now
REM set the security on
REM *******************************************************
REM error prefix=16
:do_remove_inheritance
echo -----------------------------------------------------------------------
echo removing security inheritance

REM amqp
set TARGET_DIR=%PGM_DIR%\amqp
set RETVAL_ON_ERROR=1601
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1602
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\amqp\bin
set RETVAL_ON_ERROR=1603
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1604
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM bin
set TARGET_DIR=%PGM_DIR%\bin
set RETVAL_ON_ERROR=1605
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1606
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM bin64
set TARGET_DIR=%PGM_DIR%\bin64
set RETVAL_ON_ERROR=1607
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1608
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM ------------------------------------------------------------
REM conv directory
REM ------------------------------------------------------------
set TARGET_DIR=%PGM_DIR%\conv
set RETVAL_ON_ERROR=1609
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1610
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM doc
set TARGET_DIR=%PGM_DIR%\doc
set RETVAL_ON_ERROR=1611
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1612
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM gskit8
set TARGET_DIR=%PGM_DIR%\gskit8
set RETVAL_ON_ERROR=1613
if exist "%TARGET_DIR%" (
  call :my_icacls "%TARGET_DIR%" /inheritance:r
  if not "%RETVAL%"=="0" goto :EOF
  echo.
  echo AFTER INHERITANCE REMOVAL
  set RETVAL_ON_ERROR=1614
  call :my_icacls "%TARGET_DIR%"
  if not "%RETVAL%"=="0" goto :EOF
)

REM gskit9
set TARGET_DIR=%PGM_DIR%\gskit9
set RETVAL_ON_ERROR=1613
if exist "%TARGET_DIR%" (
  call :my_icacls "%TARGET_DIR%" /inheritance:r
  if not "%RETVAL%"=="0" goto :EOF
  echo.
  echo AFTER INHERITANCE REMOVAL
  set RETVAL_ON_ERROR=1614
  call :my_icacls "%TARGET_DIR%"
  if not "%RETVAL%"=="0" goto :EOF
)

REM java
set TARGET_DIR=%PGM_DIR%\java
set RETVAL_ON_ERROR=1615
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1616
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM Licenses
set TARGET_DIR=%PGM_DIR%\Licenses
set RETVAL_ON_ERROR=1617
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1618
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM MQExplorer
set TARGET_DIR=%PGM_DIR%\MQExplorer
set RETVAL_ON_ERROR=1619
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1620
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM ------------------------------------------------------------
REM mqft directory DOES inherit from PROG/DATA dir, inheritance
REM should NOT be broken
REM Inheritance should be removed at each of the lower level
REM PROGRAM DIRECTORY directories
REM ------------------------------------------------------------
set TARGET_DIR=%PGM_DIR%\mqft\ant
set RETVAL_ON_ERROR=1621
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1622
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\mqft\lib
set RETVAL_ON_ERROR=1623
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1624
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\mqft\samples
set RETVAL_ON_ERROR=1625
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1626
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\mqft\sql
set RETVAL_ON_ERROR=1627
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1628
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\mqft\web
set RETVAL_ON_ERROR=1629
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1630
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF
REM ------------------------------------------------------------
REM end of mqft
REM ------------------------------------------------------------

REM mqxr
set TARGET_DIR=%PGM_DIR%\mqxr
set RETVAL_ON_ERROR=1631
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1632
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\mqxr\bin
set RETVAL_ON_ERROR=1633
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1634
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM Readmes
set TARGET_DIR=%PGM_DIR%\Readmes
set RETVAL_ON_ERROR=1635
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1636
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM samp
set TARGET_DIR=%PGM_DIR%\samp
set RETVAL_ON_ERROR=1637
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1638
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM swidtag
set TARGET_DIR=%PGM_DIR%\swidtag
set RETVAL_ON_ERROR=1639
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1640
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM tools
set TARGET_DIR=%PGM_DIR%\tools
set RETVAL_ON_ERROR=1641
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1642
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM uninst
set TARGET_DIR=%PGM_DIR%\uninst
set RETVAL_ON_ERROR=1643
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1644
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM ------------------------------------------------------------
REM web directory DOES inherit from PROG/DATA dir, inheritance
REM should NOT be broken
REM Inheritance should be removed at each of the lower level
REM PROGRAM DIRECTORY directories
REM ------------------------------------------------------------
set TARGET_DIR=%PGM_DIR%\web\bin
set RETVAL_ON_ERROR=1645
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1646
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\web\clients
set RETVAL_ON_ERROR=1647
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1648
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\web\dev
set RETVAL_ON_ERROR=1649
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1650
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\web\etc
set RETVAL_ON_ERROR=1651
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1652
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\web\lib
set RETVAL_ON_ERROR=1653
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1654
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\web\mq
set RETVAL_ON_ERROR=1655
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1656
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=%PGM_DIR%\web\templates
set RETVAL_ON_ERROR=1657
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1658
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF
REM ------------------------------------------------------------
REM end of web
REM ------------------------------------------------------------

REM zips
set TARGET_DIR=%PGM_DIR%\zips
set RETVAL_ON_ERROR=1659
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1660
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM REMOVE INHERITANCE ON PROGRAM DIRECTORY
set TARGET_DIR=%PGM_DIR%
set RETVAL_ON_ERROR=1661
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1662
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM ***FILE*** security inheritance

REM REMOVE INHERITANCE ON isa.xml
set TARGET_DIR=%PGM_DIR%\isa.xml
set RETVAL_ON_ERROR=1663
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1664
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM REMOVE INHERITANCE ON instinfo.tsk
set TARGET_DIR=%PGM_DIR%\instinfo.tsk
set RETVAL_ON_ERROR=1665
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1666
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM REMOVE INHERITANCE ON mqpatch.dat
set TARGET_DIR=%PGM_DIR%\mqpatch.dat
set RETVAL_ON_ERROR=1667
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.
echo AFTER INHERITANCE REMOVAL
set RETVAL_ON_ERROR=1668
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

set TARGET_DIR=

echo inheritance removed

goto :EOF


REM *******************************************************
REM set_PROGdir_settings_on_file
REM ============================
REM Set standard program directory settings on a file in
REM the program directory
REM *******************************************************
REM error prefix=17
:set_PROGdir_settings_on_file
echo -----------------------------------------------------------------------
echo %TIME% - start processing file "%PGM_DIR%\%1"

if not exist "%PGM_DIR%"\%1 (
  echo not processing "%PGM_DIR%\%1" - file not present
  goto :EOF
)

REM Query permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=1701
call :my_icacls "%PGM_DIR%"\%1
if not "%RETVAL%"=="0" goto :EOF

REM remove all explicit (non-inherited, non-superuser) security from file
set RETVAL_ON_ERROR=1702
call :my_icacls "%PGM_DIR%"\%1 /remove:g mqm %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF

REM change permissions
set RETVAL_ON_ERROR=1703
call :my_icacls "%PGM_DIR%"\%1 /grant:r %ADMINS%:F %SYSTEM%:F %OWNER%:F
if not "%RETVAL%"=="0" goto :EOF
set RETVAL_ON_ERROR=1704
call :my_icacls "%PGM_DIR%"\%1 /grant:r mqm:RX %USERS%:RX
if not "%RETVAL%"=="0" goto :EOF
set RETVAL_ON_ERROR=1705
call :my_icacls "%PGM_DIR%"\%1 /grant:r %EVERYONE%:R
if not "%RETVAL%"=="0" goto :EOF

REM Remove INHERITANCE from the file
set RETVAL_ON_ERROR=1706
call :my_icacls "%PGM_DIR%\%1" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF

REM Query permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1707
call :my_icacls "%PGM_DIR%"\%1

goto :EOF

REM *******************************************************
REM set_DATAdir_settings_on_file
REM ============================
REM Set standard Data directory settings on a file in the
REM data directory
REM *******************************************************
REM error prefix=18
:set_DATAdir_settings_on_file
echo -----------------------------------------------------------------------
echo %TIME% - start processing file "%DATA_DIR%\%1"

if not exist "%DATA_DIR%"\%1 (
  echo not processing "%DATA_DIR%\%1" - file not present
  goto :EOF
)

REM Query permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=1801
call :my_icacls "%DATA_DIR%"\%1
if not "%RETVAL%"=="0" goto :EOF

REM remove all explicit (non-inherited, non-superuser) security from directory
set RETVAL_ON_ERROR=1802
call :my_icacls "%DATA_DIR%"\%1 /remove:g mqm %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF

REM change permissions
set RETVAL_ON_ERROR=1803
call :my_icacls "%DATA_DIR%"\%1 /grant:r %ADMINS%:F %SYSTEM%:F %OWNER%:F
if not "%RETVAL%"=="0" goto :EOF
set RETVAL_ON_ERROR=1804
call :my_icacls "%DATA_DIR%"\%1 /grant:r mqm:F
if not "%RETVAL%"=="0" goto :EOF
set RETVAL_ON_ERROR=1805
call :my_icacls "%DATA_DIR%"\%1 /grant:r %USERS%:RX %EVERYONE%:RX
if not "%RETVAL%"=="0" goto :EOF

REM Remove INHERITANCE from the file
set RETVAL_ON_ERROR=1806
call :my_icacls "%DATA_DIR%\%1" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF

REM Query permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=1807
call :my_icacls "%DATA_DIR%"\%1


goto :EOF


REM *******************************************************
REM save_security_settings
REM ======================
REM Save security information to an SDDL file prior to
REM changing  any of the settings.  This might be used to
REM later restore the settings in case of problems.
REM *******************************************************
REM error prefix=19
:save_security_settings
echo -----------------------------------------------------------------------
echo Save Security Settings to backup file

if "%TEMP%"=="" (
  echo ***ERROR: The TEMP environment variable is not set and is required
  set RETVAL=1901
  goto :EOF
)

set RETVAL_ON_ERROR=1902
call :my_icacls "%PGM_DIR%\*" /save "%TEMP%\amqidsec-%INSTALLATION%.sddl" /T /C /Q
if "%ERRORLEVEL%"=="0" (
  echo settings saved to "%TEMP%\amqidsec-%INSTALLATION%.sddl"
) else  (
  echo ERRORLEVEL non-zero - save of security settings may have contained errors, review previous messages.
)

echo To reapply the original security settings use the command:
echo   icacls "[Program directory location]" /restore "%TEMP%-[installation name].sddl" /T /C /Q
echo substuting appropriate values for [Program directory location] and [installation name]

goto :EOF


REM *******************************************************
REM secure_service_directory
REM ========================
REM Sets very high (Read and Execute) security on a Maint or a
REM fixpack "source" directory
REM *******************************************************
REM error prefix=20
:secure_service_directory
set SERVICE_DIR=%*
echo %TIME% - start processing service directory "%SERVICE_DIR%"

if not exist "%SERVICE_DIR%" (
  echo ***ERROR: not processing "%SERVICE_DIR%" - directory not present
  set RETVAL=2001
  goto :EOF
) else (
  echo directory "%SERVICE_DIR%" is present
)

REM Check directory is not "dangerous" before setting its security
call :check_suitable_service_directory %SERVICE_DIR%
if not "%RETVAL%"=="0" (
  echo ***ERROR: Setting security on directory "%SERVICE_DIR%" not considered safe
  goto :EOF
) else (
  echo Setting security on directory "%SERVICE_DIR%" is permitted
)

REM Check directory security has not already been done
set ALREADY_SECURED=FALSE
call :check_directory_already_secured %SERVICE_DIR%
if "%ALREADY_SECURED%"=="TRUE" (
  echo No need to secure "%SERVICE_DIR%" as it has already been done
  goto :EOF
) else (
  echo security on "%SERVICE_DIR%" has NOT already been set
)

REM Query permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=2002
call :my_icacls "%SERVICE_DIR%"
if not "%RETVAL%"=="0" goto :EOF

REM remove all explicit (non-inherited, non-superuser) security from directory
set RETVAL_ON_ERROR=2003
call :my_icacls "%SERVICE_DIR%" /remove:g mqm %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF

REM change permissions
set RETVAL_ON_ERROR=2004
call :my_icacls "%SERVICE_DIR%" /grant:r %ADMINS%:(OI)(CI)F %SYSTEM%:(OI)(CI)F %OWNER%:(OI)(CI)F
if not "%RETVAL%"=="0" goto :EOF

set RETVAL_ON_ERROR=2005
call :my_icacls "%SERVICE_DIR%" /grant:r mqm:(OI)(CI)RX %USERS%:(OI)(CI)RX %EVERYONE%:(OI)(CI)R
if not "%RETVAL%"=="0" goto :EOF

REM Query permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=2006
call :my_icacls "%SERVICE_DIR%"

REM Remove inheritance from directory
set TARGET_DIR=%SERVICE_DIR%
set RETVAL_ON_ERROR=2007
call :my_icacls "%TARGET_DIR%" /inheritance:r
if not "%RETVAL%"=="0" goto :EOF
echo.

REM Query permissions after removing inheritance
echo AFTER INHERITANCE REMOVAL...
set RETVAL_ON_ERROR=2008
call :my_icacls "%TARGET_DIR%"
if not "%RETVAL%"=="0" goto :EOF

goto :EOF


REM *******************************************************
REM check_suitable_service_directory
REM ================================
REM Check this is not a dumb place to start setting the
REM security - e.g. a root drive or C:\Windows
REM *******************************************************
REM error prefix=21
:check_suitable_service_directory
set SAFE_DIR=%*
echo is it safe to secure directory "%SAFE_DIR%" ?

REM check not a relative directory (2nd and 3rd chars are ":\"
set SAFE_DIR_2AND3=%SAFE_DIR:~1,2%
echo SAFE_DIR_2AND3="%SAFE_DIR_2AND3%"
if "%SAFE_DIR_2AND3%"=="" (
  echo ***ERROR: directory "%SAFE_DIR%" does not start with drive specification [1]
  set RETVAL=2101
  goto :EOF
)
if not "%SAFE_DIR_2AND3%"==":\" (
  echo ***ERROR: directory "%SAFE_DIR%" does not start with drive specification [2]
  set RETVAL=2102
  goto :EOF
)

REM check not a root directory
if "%SAFE_DIR:~1%"==":\" (
  echo ***ERROR: "%SAFE_DIR%" is a root drive
  set RETVAL=2103
  goto :EOF
) else (
  echo "%SAFE_DIR%" is NOT a root drive
)

REM Check it's not in the Windows directory
if not "!SAFE_DIR:%WINDIR%=!"=="!SAFE_DIR!" (
  echo ***ERROR: Cannot set directory "%SAFE_DIR%" permissions as it is in Windows directory
  set RETVAL=2104
  goto :EOF
) else (
  echo "%SAFE_DIR%" is NOT under the Windows directory
)

goto :EOF


REM *******************************************************
REM check_directory_already_secured
REM ===============================
REM Checks whether the directory concerned has already been
REM secured or not
REM *******************************************************
REM error prefix=22
:check_directory_already_secured
set CHECK_DONE_DIR=%*
echo check if "%CHECK_DONE_DIR%" has already been secured

REM default to done already
set ALREADY_SECURED=TRUE

REM get the directory permissions
echo CHECK PERMISSIONS...
set RETVAL_ON_ERROR=2201
call :my_icacls "%CHECK_DONE_DIR%" >nul 2>&1
if not "%RETVAL%"=="0" (
  echo ***ERROR: error running icacls - see above
  goto :EOF
) else (
  echo no error back from icacls
)

REM Analyze permissions looking for any "(I)" which would indicate inheritance is still in place
echo about to run loop
for /F "usebackq delims=" %%A in (`%WINDIR%\System32\icacls "%CHECK_DONE_DIR%"`) do (
  set ICACLS_OUTPUT_LINE=%%A
  set ICACLS_OUTPUT_LINE="!ICACLS_OUTPUT_LINE:%CHECK_DONE_DIR%=!"
  echo LINE: "!ICACLS_OUTPUT_LINE!"
  if not "!ICACLS_OUTPUT_LINE!"=="!ICACLS_OUTPUT_LINE:(I)=!" (
    echo *** inherited permisssion line
    set ALREADY_SECURED=FALSE
  )
)
echo ran loop

if "%ALREADY_SECURED%"=="TRUE" (
  echo NO inherited permissions - directory has already been fixed up
) else (
  echo inherited permissions - directory not already processed
)

goto :EOF


REM *******************************************************
REM secure_fix_pack
REM ===============
REM secure the loaded fix pack files directory, by default
REM this is "C:\Program Files\IBM\Source\MQ v.r.m.f"
REM *******************************************************
REM error prefix=23
:secure_fix_pack
echo -----------------------------------------------------------------------
echo Secure fix pack source directory for MQ VRMF "%1"
echo.

set REG_LOCATION=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBM MQ (fix pack %1 files)
echo REG_LOCATION="%REG_LOCATION%"

set REG_LINE=
for /F "usebackq delims=" %%A in (`%WINDIR%\System32\reg query "%REG_LOCATION%" /v InstallLocation /reg:64`) do set REG_LINE=%%A
if "%REG_LINE%"=="" (
  echo ***ERROR: Unable to get Fix pack Install location from registry, exiting
  set RETVAL=2301
  goto :EOF
) else (
  echo REG_LINE="%REG_LINE%"
)

echo.
echo -- Parse line containing FilePath
set SOURCE_DIR=
for /f "tokens=2* delims= " %%A in ("%REG_LINE%") do set f3=%%B
set SOURCE_DIR=%f3%
if "%SOURCE_DIR%"=="" (
  echo ***ERROR: Unable to parse Filepath, exiting
  set RETVAL=2302
  goto :EOF
) else (
  echo Source Path is "%SOURCE_DIR%"
)

call :secure_service_directory %SOURCE_DIR%
if "%RETVAL%"=="0" (
  echo secure_fix_pack : returning without error
) else (
  echo ***ERROR: secure_fix_pack : returning with error %RETVAL%
)
goto :EOF


REM *******************************************************
REM secure_maint_directories
REM ========================
REM secure each of the  Maint directory ie "Maint_0.1" for
REM a specified Installation
REM *******************************************************
REM error prefix=24
:secure_maint_directories
echo -----------------------------------------------------------------------
echo Secure Maint directories for installationMQ "%1"
echo.

set REG_LOCATION=HKLM\SOFTWARE\IBM\WebSphere MQ\Installation\%INSTALLATION%\Maintenance Applied
echo REG_LOCATION="%REG_LOCATION%"

set REG_LINE=
for /F "usebackq delims=" %%A in (`%WINDIR%\System32\reg query "%REG_LOCATION%" /reg:64`) do (
  set REG_LINE=%%A
  if not "!REG_LINE!"=="!REG_LINE:Maint_=!" (
    echo --------
    echo process line "!REG_LINE!"

    set MAINT_DIR=
    for /f "tokens=2* delims= " %%A in ("!REG_LINE!") do set MAINT_DIR=%%B

    if "!MAINT_DIR!"=="" (
      echo ***ERROR: Unable to parse Maint_x.x line, exiting
      echo --------
      set RETVAL=2401
      goto :EOF
    ) else (
      echo Maint dir located at "!MAINT_DIR!"
      call :secure_service_directory !MAINT_DIR!
      if not "!RETVAL!"=="0" goto :EOF
      echo good rc - !RETVAL! - from secure_service_directory
    )

    echo --------
  ) else (
    echo do not process registry line "!REG_LINE!"
  )
)

if "%RETVAL%"=="0" (
  echo secure_maint_directories : returning without error
) else (
  echo ***ERROR: secure_maint_directories : returning with error %RETVAL%
)
goto :EOF


REM *******************************************************
REM check_allowed_directories_only
REM ==============================
REM check the only directories in the program directory are
REM those expected and valid Maint directories.
REM *******************************************************
REM error prefix=25
:check_allowed_directories_only
echo -----------------------------------------------------------------------
echo checking for unhandled program directory subdirectories
echo.

REM check kill switch 2 - don't run directory check code
echo -- Check for Kill switch 2 in registry
echo Kill switch name is SKIP_AMQIDSEC_DIRECTORY_CHECK
%WINDIR%\System32\reg query "HKLM\SOFTWARE\IBM\WebSphere MQ" /v SKIP_AMQIDSEC_DIRECTORY_CHECK /reg:64
if "%ERRORLEVEL%"=="0" (
  echo KILL SWITCH 2 FOUND - Exiting subroutine with return code zero [PASS]
  set RETVAL=0
  goto :EOF
) else (
  echo KILL SWITCH 2 ABSENT - directory check will be executed
)

REM check if we are running on a IBM test machine
set DEV_BUILD=FALSE
echo looking for IP address
for /F "usebackq delims=" %%A in (`"%WINDIR%\System32\ipconfig" `) do (
  set IPCONFIG_LINE=%%A
  if not "!IPCONFIG_LINE:IPv4 Address=!"=="!IPCONFIG_LINE!" (
    echo "!IPCONFIG_LINE!"

    for /f "tokens=1,2 delims=:" %%A in ("!IPCONFIG_LINE!") do set IP_ADDRESS=%%B
    echo IP v4 Address: !IP_ADDRESS!

    for /f "tokens=1,2 delims=. " %%A in ("!IP_ADDRESS!") do set IP_ADDRESS_1=%%A&set IP_ADDRESS_2=%%B
    echo IP v4 Address parts 1 and 2: !IP_ADDRESS_1! and !IP_ADDRESS_2!

    if "!IP_ADDRESS_1!"=="9" (
      if "!IP_ADDRESS_2!"=="20" (
        echo ***found a 9.20 IP address
        set DEV_BUILD=TRUE
      )
    )
  )
)
if "!DEV_BUILD!"=="TRUE" (
  echo Running on an English language Hursley machine, continue checking
) else (
  echo not running at Hursley, skip the directory checking
  goto :EOF
)
echo.

REM build a list of all expected directories - case non-specific
set EXPECTED_DIRS=amqp bin bin64 conv doc gskit8 gskit9 java Licenses MQExplorer mqft mqxr Readmes samp swidtag tools uninst web zips

REM account for MQXR clients
set EXPECTED_DIRS=%EXPECTED_DIRS% SDK lib

if "%PGM_DIR%"=="%DATA_DIR%" (
  echo Collocated install
  set EXPECTED_DIRS=%EXPECTED_DIRS% config errors exits exits64 log qmgrs shared sockets trace
)
echo Expected directories are:
echo "%EXPECTED_DIRS%"

REM store a list of the unexpected directories found
set UNEXPECTED_DIRECTORY_NAMES=

for /F "usebackq delims=" %%A in (`dir /b /A:D "%PGM_DIR%" `) do (
  set DIR_FOUND=%%A
  set DIR_EXPECTED=FALSE

  for %%A in (%EXPECTED_DIRS%) do (
    if /i "%%A"=="!DIR_FOUND!" (
      set DIR_EXPECTED=TRUE
    )
  )
  if "!DIR_EXPECTED!"=="TRUE" (
    REM this directory was in the list of expected directories
    echo found expected dir: "!DIR_FOUND!"
  ) else (
    echo.
    echo processing unexpected dir: "!DIR_FOUND!"
    set MATCH_FOUND=FALSE
    call :is_this_a_maint_directory %INSTALLATION% "%PGM_DIR%\!DIR_FOUND!"
    if "!MATCH_FOUND!"=="TRUE" (
      echo directory "!DIR_FOUND!" is a Maint directory
      set DIR_EXPECTED=FALSE
      echo.
    ) else (
      echo directory "!DIR_FOUND!" is NOT a Maint directory, adding to unexpected directory list
      echo directory of "%PGM_DIR%\!DIR_FOUND!" follows:
      dir "%PGM_DIR%\!DIR_FOUND!"
      echo.
      set UNEXPECTED_DIRECTORY_NAMES="!DIR_FOUND!" !UNEXPECTED_DIRECTORY_NAMES!
    )
  )
)

If not "!UNEXPECTED_DIRECTORY_NAMES!"=="" (
  echo ***ERROR: unexpected subdirectory or directories found in Program directory:
  if "!UNEXPECTED_DIRECTORY_NAMES:~-1!"==" " (
    set UNEXPECTED_DIRECTORY_NAMES=!UNEXPECTED_DIRECTORY_NAMES:~0,-1!
  )
  echo !UNEXPECTED_DIRECTORY_NAMES!
  REM *****************************************************
  REM this code has been re-enabled as the MQ test
  REM infrastructure should now have stopped leaving unknown
  REM directories lying around.  It can be re-enabled again
  REM by commenting out the line below:
  set RETVAL=2501
  REM *****************************************************
) else (
  echo No unexpected subdirectories found in Program directory.
  echo.
)

goto :EOF


REM *******************************************************
REM is_this_a_maint_directory
REM ========================
REM decide whether a directory is a maint directory
REM *******************************************************
REM error prefix=26
:is_this_a_maint_directory
echo ...checking whether "%2" is an "%INSTALLATION%" Maint directory
set CHECK_DIR=%2

set REG_LOCATION=HKLM\SOFTWARE\IBM\WebSphere MQ\Installation\%INSTALLATION%\Maintenance Applied
echo ...REG_LOCATION="%REG_LOCATION%"

set REG_LINE=
for /F "usebackq delims=" %%A in (`%WINDIR%\System32\reg query "%REG_LOCATION%" /reg:64`) do (
  set REG_LINE=%%A

  if not "!REG_LINE!"=="!REG_LINE:Maint_=!" (
    echo ...Maint dir found: "!REG_LINE!"

    set MAINT_DIR=
    for /f "tokens=2* delims= " %%A in ("!REG_LINE!") do set MAINT_DIR=%%B

    if "!MAINT_DIR!"=="" (
      echo ...***ERROR: Unable to parse Maint_x.x line, exiting
      set RETVAL=2601
      goto :EOF
    ) else (

      echo ...Maint dir is "!MAINT_DIR!"
      set CHECK_DIR=!CHECK_DIR:"=!
      echo ...Check dir is "!CHECK_DIR!"

      if "!MAINT_DIR!"=="!CHECK_DIR!" (
        echo ...MATCH
        set MATCH_FOUND=TRUE
      ) else (
        echo ...no match
      )
    )
  ) else (
    echo ...ignore registry line: "!REG_LINE!"
  )
)
echo ...is Maint directory : "%MATCH_FOUND%"

if "%RETVAL%"=="0" (
  echo ...is_this_a_maint_directory : returning without error
) else (
  echo ...***ERROR: is_this_a_maint_directory : returning with error "%RETVAL%"
)
goto :EOF


REM *******************************************************
REM my_icacls
REM ===========================
REM Wrapper around icacls to simplify the code required to
REM call icacls and process the results
REM *******************************************************
REM error prefix=27
:my_icacls
echo.
echo ---running: icacls %*
if not "%TARGET_DIR%"=="" (
  if not exist "%TARGET_DIR%" (
    echo info: target directory "%TARGET_DIR%" does not exist, skipping
    goto :EOF
  )
)

%WINDIR%\System32\icacls %*
if not "%ERRORLEVEL%"=="0" (
  echo ***ERROR: icacls returned ERRORLEVEL %ERRORLEVEL%
  set RETVAL=%RETVAL_ON_ERROR%
)

REM report an error if this RC on error matches a debug env var
if "%AMQIDSEC_DEBUG_ERROR_RETVAL%"=="%RETVAL_ON_ERROR%" (
  echo ***ERROR: Debug parameter forced error - %RETVAL_ON_ERROR% - to be reported here
  set RETVAL=%RETVAL_ON_ERROR%
)

goto :EOF

REM *******************************************************
REM set_mqm_member_only
REM ========================
REM Set access to mqm member group only
REM *******************************************************
REM error prefix=13
:set_mqm_member_only
echo -----------------------------------------------------------------------
echo %TIME% - start postprocessing access to mqm member group only

if not exist "%PGM_DIR%"\%1 (
  echo not processing "%1" - directory not present
  goto :EOF
)

REM Query permissions before changing them
echo.
echo PERMISSIONS BEFORE...
set RETVAL_ON_ERROR=2701
call :my_icacls "%PGM_DIR%"\%1
if not "%RETVAL%"=="0" goto :EOF

echo Take a Ownership of the File
takeown /F "%PGM_DIR%"\%1

echo remove inheritance
set RETVAL_ON_ERROR=2702
call :my_icacls "%PGM_DIR%"\%1 /inheritance:r
if not "%RETVAL%"=="0" goto :EOF

REM remove all explicit security
set RETVAL_ON_ERROR=2703
call :my_icacls "%PGM_DIR%"\%1 /remove:g %USERS% %EVERYONE%
if not "%RETVAL%"=="0" goto :EOF

echo Grant permission
set RETVAL_ON_ERROR=2704
call :my_icacls "%PGM_DIR%"\%1 /grant:r mqm:F %ADMINS%:F %SYSTEM%:F
if not "%RETVAL%"=="0" goto :EOF

REM Query permissions after changing them
echo.
echo PERMISSIONS AFTER...
set RETVAL_ON_ERROR=2705
call :my_icacls "%PGM_DIR%"\%1
goto :EOF