@echo off
rem Build Batch file for PMODELIB
rem  By Peter Johnson, 2001
rem
rem $Id: build.bat,v 1.1 2001/04/17 23:51:47 pete Exp $
echo Compiling. Please wait...
make libobjs
set LFN=N
make2 lib
set LFN=
make all
