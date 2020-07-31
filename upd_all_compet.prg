LOCAL nLast := 30
LOCAL bFilt := {|| cmpr->LastReq >= Date() - nLast }
LOCAL cFilt := "LastReq >= Date() - "+LTrim(Str(nLast))
LOCAL nRec,nArt
LOCAL nSec
LOCAL nMinSec := 10

Head("Konkurrenzpreise "+Ltrim(Str(nLast))+" Tage aktuell halten")

NetUse("compprice","cmpr")
NetUse("artikel","art")

cmpr->(dbSetFilter(bFilt,cFilt))
cmpr->(dbGoTop())



DO WHILE ! cmpr->(EOF())
   nSec := Seconds()

   nArt := cmpr->Artikelnr
   art->(dbSetOrder( 2 ))

   IF cmpr->Datum < Date()-3 .AND. art->(dbSeek( Str(cmpr->Artikelnr,6) ))
      ? cmpr->Artikelnr,art->Matchcode
      nRow := Row()
      nRec := cmpr->(Recno())
      cmpr->(dbClearFilter())
      MBaseRun(Trim(Tr_getini(1))+"\run\prices\updcompet",{,.T.})
      cmpr->(dbSetFilter(bFilt,cFilt))
      cmpr->(dbGoto( nRec ))
      SetPos(nRow,0)
      IF cmpr->(EOF())
         ? "EOF"
      ENDIF
   ENDIF

   DO WHILE cmpr->Artikelnr == nArt .AND. ! cmpr->(EOF())
      cmpr->(dbSkip())
   ENDDO

   IF nMinSec-(Seconds()-nSec) > 0  //at least nMinSec seconds between request
      Inkey( nMinSec-(Seconds()-nSec), 0 )
   ENDIF

ENDDO

? "done"
IF ! GetConfigValue("BATCHMODE")
   Inkey(0,128)
ENDIF