#define CRLF Chr(13)+Chr(10)

PROC RUN_REPORT_TURNSUP
LOCAL cLiefma := Space(8)
LOCAL nYear := Year(Date())-3,cYear
LOCAL hArt
LOCAL cMatch
LOCAL getlist := {}
LOCAL hProducts,nCount,nX,nPreis,nOldTot,nTotQty,nNewTot,nY,cArtlief
LOCAL cFile

Head("Umsaetze Lieferant")

NetUse("engkund","ku")

@ 01,00 SAY "ab Jahr    " GET nYear PICTURE "9999"
@ 02,00 SAY "Lieferant  " GET cLiefma VALID FindAd(cLiefma,"L",02,20) PICTURE "@!"
READ

If LastKey() == 27
   Return
Endif


NetUse("folgeart","fol",.F.,0)
fol->(dbSetOrder(2))
NetUse("engrech","rech",.F.,0)

NetUse("rechpos","rpos")
rpos->(dbSetOrder(1))
NetUse("artikel","art",.F.,0)
art->(dbSetOrder(2))
NetUse("manufact","manu",.F.,0)

NetUse("artlief","ali")
ali->(dbSetOrder( 1 ))

ku->(dbSetOrder(8))

hProducts := {=>}
nCount := 0
@ 15,00 SAY "Daten werden gesammelt"

rech->(dbSetOrder(1))
rech->(dbSeek( cLiefma+Str(nYear,4)+"0101" ,.T. ))

DO WHILE ! rech->(Eof()) .AND. Year(rech->Rechdat) >= nYear .AND. rech->Liefma == cLiefma

   ku->(dbSetOrder(1))
   ku->(dbSeek( rech->liefma+"L" ))
   rpos->(dbSeek( rech->Liefma+rech->Rechnr ))
   DO WHILE ( rpos->liefma == rech->Liefma .AND. rpos->Beleg == rech->Rechnr  ) //aSup[ni] )
     IF nCount%70 == 0
	     @ 15,22 SAY Replicate(".",(nCount/70) % 4)+Space(3)
	  ENDIF

      art->(dbSeek(Str(rpos->artikelnr,6)))
      cMatch := Trim(art->Matchcode)
      IF ali->(dbSeek(cLiefma+Str(rpos->artikelnr,6))) .AND. ! Empty(ali->Artlief)
         cArtlief := Trim(ali->Artlief)
      ELSE
         cArtlief := ""
      ENDIF

      cYear := Str(Year(rech->Rechdat),4)
      IF Year(rech->Rechdat) == Year(Date())
         cYear += "YTD"
      ENDIF

      IF rpos->Menge != 0
         IF ! HHasKey(hProducts,cMatch)
            hProducts[cMatch] := {=>}
         ENDIF
         FOR nX := 1 TO IF(Year(rech->Rechdat) == Year(Date())-1 .AND. rech->Rechdat <= AddMonth(Date(),-12),2,1)
            IF nX == 2
               cYear += "YTD"
            ENDIF

            IF ! HHasKey(hProducts[cMatch],cYear)
               hProducts[cMatch][cYear] := {"QTY"=>0,"PRICE"=>0,"ARTLIEF"=>cArtlief}
            ENDIF

            nPreis := rpos->ekpr/rpos->pe*rech->Rate
            nOldTot := hProducts[cMatch][cYear]:price*hProducts[cMatch][cYear]:qty
            nNewTot := rpos->Menge*nPreis
            nTotQty := hProducts[cMatch][cYear]:qty+rpos->Menge

            IF nTotQty != 0
               hProducts[cMatch][cYear]:price := (nOldTot+nNewTot)/nTotQty
            ELSE
               hProducts[cMatch][cYear]:price := 0
            ENDIF
            hProducts[cMatch][cYear]:Qty   += rpos->Menge
         NEXT
      ENDIF
      
      rpos->(dbSkip())
      nCount++
   ENDDO
   rech->(dbSkip())
ENDDO

cFile := Trim(Tr_Getini(1))+"\export\TURN_"+Trim(cLiefma)+"_"+Str(nYear,4)+"_PRODUCTS.csv"
SET PRINTER TO (cFile)
SET PRINTER ON
?? "Artikel;Lieferantenbezeichnung"
FOR nY := nYear TO Year(Date())+1
   IF nY >= Year(Date())
      cYear := Right(Str(nY-1,4),2)+" YTD"
   ELSE
      cYear := Right(Str(nY,4),2)
   ENDIF
   ?? ";Menge "+cYear+";EK "+cYear+"; Summe "+cYear
NEXT

FOR EACH hArt IN hProducts
	cMatch := hArt:__enumKey()
	art->(dbSeek(cMatch))
   ? Trim(cMatch)
   ?? ";"+Trim(HGetValueAt(hArt,1):ArtLief)
   FOR nY := nYear TO Year(Date())+1
		IF nY >= Year(Date())
         cYear := Str(nY-1,4)+"YTD"
		ELSE
		   cYear := Str(nY,4)
		ENDIF
      IF HHasKey(hArt,cYear)
         ?? ";"+StrTran(Transform(hArt[cYear]:Qty,Me(art->me)),".",",")+";"+StrTran(Str(hArt[cYear]:Price),".",",")+";"+StrTran(Str(hArt[cYear]:Qty*hArt[cYear]:Price),".",",")
      ELSE
         ?? ";0;0;0"
      ENDIF
   NEXT
NEXT
SET PRINTER OFF
SET PRINTER TO

Wapi_Shellexecute(,"open",cFile)

Tone(700,10);Tone(900,10);Tone(1100,10)
