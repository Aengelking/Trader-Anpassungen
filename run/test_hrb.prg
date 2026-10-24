#include 'y:\hb32\include\hbhrb.ch'
LOCAL cDir := Trim(Tr_getIni(1))+"\modules\"
LOCAL aDir := Directory(cDir+"*.hrb")

MEMVAR pHrb
PUBLIC pHrb

FOR nX := 1 TO Len(aDir)
   pHrb := HB_HRBLoad(HB_HRB_BIND_OVERLOAD,cDir+aDir[1,1])
NEXT
//ArtFo()