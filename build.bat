@echo off
rem Build Batch file for PMODELIB
rem  By Peter Johnson, 2001
rem
rem $Id: build.bat,v 1.2 2001/10/17 20:54:50 pete Exp $
if .%EXTLIBS%. == .. goto needextlibs
echo Compiling. Please wait...
make libobjs
set LFN=N
make all
set LFN=
goto end
:needextlibs
echo Please set EXTLIBS to point to the directory that contains the
echo following three directories and their contents:
echo  lpng108 - LibPNG 1.0.8
echo  zlib - zlib (high enough version to support LibPNG)
echo  jpeg-6b - JPEG library
echo For example:
echo  SET EXTLIBS=v:/ece291/utils
:end
