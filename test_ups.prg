LOCAL cFilter, nCount := 1
CLS
NetUse("paknum","pnum")
cFilter := "AT('1Z',nummer)==1 .AND. STATUS != 'DEL'"
pnum->(dbSetFilter( {|| &(pnum->(cFilter)) }, cFilter ))
pnum->(dbGoBottom())
DO WHILE ! pnum->(BOF()) .AND. nCount <= 20
   ? pnum->Nummer
   aData := MBaseRun(Trim(Tr_Getini(1))+"\run\ship\track\2",{Trim(pnum->Nummer)})
   IF ! Empty(aData[1])
      pnum->(Rec_Lock())
      pnum->Status := aData[1]
      pnum->StatDate := aData[2]
      pnum->(dbUnLock())
   ENDIF
   pnum->(dbSkip(-1))
   nCount++
ENDDO
pnum->(dbClearFilter())
//Wvt_DrawImage( 22,01,23,02, "X:\run\LOGO_S.gif" )
//@ 22,04 SAY "UPS, the UPS brand mark, and the Color Brown are trademarks of United Parcel Service"
//@ 23,04 SAY "of America, Inc. All Rights Reserved."
Sinkey(0)