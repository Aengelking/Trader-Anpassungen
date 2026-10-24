@echo off
rem ************
rem command line: david.bat username originalfile
echo @@OWNERNAME %1@@ >>%2
echo %2 "\\bull\david\import\%1_%date:~0%_%time:~0,2%_%time:~3,2%-%time:~6,2%-%time:~9,2%.pcl"
copy %2 "\\bull\david\import\%1_%date:~0,2%_%date:~3,2%_%date:~6,3%_%time:~0,2%_%time:~3,2%-%time:~6,2%-%time:~9,2%.pcl"
if errorlevel 1 pause
