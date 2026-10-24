#include 'x:\hooks\archive.ch'
LOCAL cTyp
LOCAL cArchDir := GetConfigValue("ARCHIVE_DIR") //"C:\Archive-Temp\10J2017\" //
LOCAL cDir,aDir
LOCAL nX
LOCAL nQty := 30000

CLS

NetUse("englsre","re")
re->(dbSetOrder( 8 ))

FOR EACH cTyp IN {"RE"}
   cDir := cArchDir+"\"+hTypes[cTyp]:Dir+"\"
   aDir := Directory(cDir+hTypes[cTyp]:Prefix+"*.*")
   ASort(aDir,,,{|x,y| x[1] < y[1] })
   nQty := Min(Len(aDir),nQty)
   nLastNum := _GetNum(aDir[Len(aDir)-nQty+1,1])
   ? aDir[Len(aDir)-nQty+2,3]
   FOR nX := Len(aDir)-nQty+2 TO Len(aDir)
      nNum := _GetNum(aDir[nX,1])
      IF nNum >= 34169 //2.1.14         
         //? nNum,aDir[nX,1]
         IF nNum > nLastNum+1
            re->(dbSeek( Str(0,3)+Str(nLastNum+1,6) ))
            ? nLastNum+1,re->Rechdat
            IF nNum-1 != nLastNum+1
               re->(dbSeek( Str(0,3)+Str(nNum+1,6) ))
               ?? " to",nNum-1,re->Rechdat
            ENDIF
            ??" missing"
         ENDIF
      ENDIF
      nLastNum := nNum
   NEXT
NEXT
Sinkey(0)

STATIC FUNCTION _GetNum(cFileName)
   LOCAL aRegex := HB_Regex("[0-9]{6}",cFileName)
   IF Len(aRegex) == 0
      RETURN 0
   ENDIF
RETURN Val(aRegex[1])
