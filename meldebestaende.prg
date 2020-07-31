NetUse("artikel","art")
NetUse("liefstock","lsto")


cFilter := "manufactur == 1"
art->(dbSetFilter({|| &cFilter },cFilter))
art->(dbGoTop())

CLS

nCount := 0
DO WHILE ! art->(EOF()) .AND. nCount <= 30
   hReqInc := GetProductRequirementAndIncoming(art->artikelnr)
   IF art->Mindest > 0 .AND. art->Mindest >= hReqInc["forecast"] .AND.  lsto->(dbSeek( Pad("WALDOM",8)+Str(art->Artikelnr,6) )) .AND. lsto->Stock >= hReqInc["forecast"]*2
      ? art->Matchcode
   nCount++
   ENDIF
/*   IF hReqInc["cust_count"] > 3 .AND. hReqInc["forecast"] > 50
      ? art->Matchcode
   ENDIF*/
   art->(dbSkip())
ENDDO

art->(dbClearFilter())

? "___"
SInkey(0)