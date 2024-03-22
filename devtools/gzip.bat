echo off
REM ignore gzip flags in %1. %2 s/b .tar
"C:\Program Files\7-Zip\7z.exe" a -r "%2.gz" "%2"
