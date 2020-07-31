NetUse( "rechpos" ,"rpos")
NetUse( "engrech" ,"rech")
NetUSe( "artikel" ,"art" )

nTot := 0
aMonth := Array(12)
AFill(aMonth,0)     

CLS   

DO WHILE ! rpos->(EOF())
   IF Between(rpos->Date,SToD("20130101"),SToD("20131231")) .AND. rpos->Artikelnr > 0
      rech->(dbSeek( rpos->Liefma+rpos->Beleg, .F. ))
      art->(dbSeek( rpos->Matchcode ))

		nPreis := rpos->ekpr/rpos->pe
		nPreis := Round(nPreis-(nPreis*rpos->rabatt/100),2)
      nPreis *= rech->rate
      IF nPreis > art->avpreis
         // ?rech->Liefma,rpos->Matchcode,nPreis,art->avpreis,rpos->Menge
         nTot += (nPreis-art->avPreis)*rpos->Menge
         aMonth[Month(rpos->Date)] +=  (nPreis-art->avPreis)*rpos->Menge
      ENDIF
   ENDIF
   rpos->(dbSkip())
ENDDO

? nTot
FOR nX := 1 TO 12
   ? nX,aMonth[nX]
NEXT

Inkey(0,128)