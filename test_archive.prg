#include 'X:\hooks\archive.ch'

CLS

//aList := GetArchiveDirList(hTypes["RE"])
//? ValToPrg(aList)

//19541
/*IF Hook("has_archive_file",{"RE",19541,""}) //cTyp,nNo,cFileName
   ? "Invoice 19541 found"
ENDIF*/

//? ValToPrg(GetArchiveFiles({"RE"=>19541}))
cDir := GetArchiveDir(hTypes["ER"],StoD("20170101"))
? cDir
? CreateArchiveDir(cDir)

SInkey(0)

#include 'X:\hooks\archive.prg'