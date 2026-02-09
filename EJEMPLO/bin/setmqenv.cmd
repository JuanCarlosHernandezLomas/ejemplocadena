@echo off

REM ---------------------------------------------------------------------------
REM File Name : setmqenv.cmd
REM Descriptive File Name : Set the environment for IBM MQ
REM ---------------------------------------------------------------------------
REM   <copyright
REM   notice="lm-source-program"
REM   pids="5724-H72,"
REM   years="2010,2022"
REM   crc="4107220323" >
REM   Licensed Materials - Property of IBM
REM
REM   5724-H72,
REM
REM   (C) Copyright IBM Corp. 2010, 2022 All Rights Reserved.
REM
REM   US Government Users Restricted Rights - Use, duplication or
REM   disclosure restricted by GSA ADP Schedule Contract with
REM   IBM Corp.
REM   </copyright>
REM ---------------------------------------------------------------------------
REM @(#) MQMBID sn=p945-L260120 su=cf26678a1a640aba7dc4f9c41871946713dc9a38 pn=cmd/tools/setmqenv/setmqenv.cmd
REM ---------------------------------------------------------------------------
REM File Description :
REM
REM This script is used to set the environment for IBM MQ. The arguments
REM specified are passed directly to crtmqenv whose usage is as follows. At
REM least one of -m, -n, -p, -r or -s must be specified. Use -s to set up the
REM environment for the installation that this script comes from.
REM
REM crtmqenv usage:
REM -j 2.0|3.0         : Set up the environment for JMS 2.0 or 3.0 (Default: 2.0)
REM -m name            : Set up the environment for the specified queue manager
REM -n name            : Set up the environment for the specified installation
REM -p name            : Set up the environment for the installation with the
REM                      specified path
REM -r                 : Remove IBM MQ from the environment
REM -s                 : Set up the environment for the installation that this
REM                      script comes from
REM -x 32|64           : Set up either a 32 or 64-bit environment
REM
REM ---------------------------------------------------------------------------

pushd %~dps0
if exist "..\bin64\crtmqenv.exe" (
for /f "tokens=*" %%I in ('..\bin64\crtmqenv.exe -z %*') do set %%I
) else (
for /f "tokens=*" %%I in ('.\crtmqenv.exe -z %*') do set %%I
)
popd

(set MQ_RETVAL=) & (exit /b %MQ_RETVAL%)
