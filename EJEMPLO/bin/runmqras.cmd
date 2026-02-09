@echo off

REM ---------------------------------------------------------------------------
REM File Name : runmqras.cmd
REM Descriptive File Name : Start the standalone MQ Document Collector
REM ---------------------------------------------------------------------------
REM   <copyright
REM   notice="lm-source-program"
REM   pids="5724-H72,"
REM   years="2009,2019"
REM   crc="863412749" >
REM   Licensed Materials - Property of IBM
REM
REM   5724-H72,
REM
REM   (C) Copyright IBM Corp. 2009, 2019 All Rights Reserved.
REM
REM   US Government Users Restricted Rights - Use, duplication or
REM   disclosure restricted by GSA ADP Schedule Contract with
REM   IBM Corp.
REM   </copyright>
REM ---------------------------------------------------------------------------
REM @(#) MQMBID sn=p945-L260120 su=cf26678a1a640aba7dc4f9c41871946713dc9a38 pn=cmd/cs/runmqras.cmd
REM ---------------------------------------------------------------------------
REM File Description :
REM
REM This script is used to launch the standalone document collector
REM the arguments are passed directly to crtmqras whose usage is as follows
REM
REM
REM crtmqras usage:
REM -inputfile file    : fully qualified name of the XML input file (required)
REM -zipfile file      : fully qualified name for the zip output file (required)
REM -workdirectory dir : fully qualified name of an empty work directory (required)
REM -section name      : execute named section in XML
REM -help              : provide simple help (optional)
REM -demo              : list work that would be executed (optional)
REM -v                 : verbose output into console log(optional)
REM
REM
REM ---------------------------------------------------------------------------

setlocal

rem checking path to java command

set pgmname=runmqras.cmd

rem Command can be run via path or specifying the path - cater for both
rem cases to try to identify where the GSKIT jre might be:
SET pgmdir=%~dp0
for %%i in (%pgmname%) do SET pgmPATHdir=%%~dp$PATH:i

rem Set the environment up for this installation
if not defined MQ_INSTALLATION_NAME (
  pushd "%~dps0"
  if exist "..\bin64\crtmqenv.exe" (
    for /f "delims=" %%x in ('..\bin64\crtmqenv.exe -x64 -s') do set %%x
  ) else (
    for /f "delims=" %%x in ('.\crtmqenv.exe -x32 -s') do set %%x
  )
  popd
)

rem v7 installs: Use specific environment variable
set JREPATH=%MQ_JRE_PATH%\bin

rem Attempt to locate a Java runtime by trying various locations
if not exist "%JREPATH%\java.exe" set JREPATH=%pgmdir%\..\java\jre\bin
if not exist "%JREPATH%\java.exe" set JREPATH=%pgmPATHdir%\..\java\jre\bin
if not exist "%JREPATH%\java.exe" set JREPATH=%JAVA_HOME%\bin
rem if all else fails search all the "Program Files" directories
if not exist "%JREPATH%\java.exe" (
  for /R "%PROGRAMFILES%" %%i in (java.exe) do (
    if exist %%i (
      if not exist "%JREPATH%\java.exe" (
        set JREPATH=%%~dp$PATH:i
        goto SKIP
      )
    )
  )
)

:SKIP

if not exist "%JREPATH%\java.exe" GOTO NO_JAVA

SET ARGS=%*

SET XML="%MQ_INSTALLATION_PATH%\isa.xml"

rem Construct a default path containing date and time
rem ..Prefix times before 10am with a zero
SET TIMED=%time: =0%
SET TD=c:\temp\runmqras_%date:/=%_%TIMED::=%
if exist %temp% SET TD=%temp%\runmqras_%date:/=%_%TIMED::=%

rem Set the platform specific defaults for each of the main arguments
SET props=-DdefaultRasInput=%XML% -DdefaultRasWork="%TD%"

SET props=%props% -DMQ_INSTALLATION_NAME=%MQ_INSTALLATION_NAME%

rem build the path up from the install dir; not the lib path as the lib64 doesn't have the JARs
set JAR_CLASSPATH_PATH=%MQ_JAVA_INSTALL_PATH%\lib
if not exist "%JAR_CLASSPATH_PATH%" set JAR_CLASSPATH_PATH=%pgmdir%\..\java\lib
for %%i in (com.ibm.mq.tools.ras.jar) do if exist "%%~$JAR_CLASSPATH_PATH:i" @set MQ_TOOLS_JAR=%%~$JAR_CLASSPATH_PATH:i
for %%i in (com.ibm.mq.commonservices.jar) do if exist "%%~$JAR_CLASSPATH_PATH:i" @set MQ_CS_JAR=%%~$JAR_CLASSPATH_PATH:i
set CP=-cp "%MQ_CS_JAR%";"%MQ_TOOLS_JAR%"
set CMD="%JREPATH%\java.exe" %props% %CP% crtmqras.Zipper %ARGS%

echo using "%JREPATH%\java.exe":
"%JREPATH%\java.exe" -version
echo %CMD%
%CMD%

GOTO END

:NO_JAVA
"%MQ_INSTALLATION_PATH%\bin\mqrc" -b -c runmqras amq8599
GOTO END

:END
echo finished running %pgmname%
