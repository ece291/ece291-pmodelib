@echo off
rem Build Batch file for PMODELIB
rem  By Peter Johnson, 2001
rem
rem $Id: build.bat,v 1.3 2001/12/12 07:12:09 pete Exp $
if .%EXTLIBS%. == .. goto needextlibs
echo Compiling. Please wait...
make all
goto end
:needextlibs
echo Please set EXTLIBS to point to the directory that contains the
echo following three directories and their contents:
echo  lpng - LibPNG
echo  zlib - zlib (high enough version to support LibPNG)
echo  jpeg-6b - JPEG library
echo For example:
echo  SET EXTLIBS=v:/ece291/utils
:end
