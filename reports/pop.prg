#define CRLF Chr(13)+Chr(10)

LOCAL nManu := 1
LOCAL nYear := Year(Date())-3
LOCAL hArt
LOCAL cMatch

Head("Generate POP Reporting")

aManu := GetManufacturerArray()
@ 01,00 SAY "ab Jahr    " GET nYear
@ 02,00 SAY "Hersteller "
@ 02,12,14,50 GET nManu LISTBOX aManu[2]
READ
//nManu := Achoice(01,12,14,50,aManu[2])
//@ 02,12 SAY aManu[2][1]

If LastKey() == 27
   Return
Endif


NetUse("folgeart","fol",.F.,0)
fol->(dbSetOrder(2))
NetUse("engrech","rech",.F.,0)
rech->(dbSetOrder(3))
NetUse("rechpos","rpos")
rpos->(dbSetOrder(1))
NetUse("artikel","art",.F.,0)
art->(dbSetOrder(2))
NetUse("manufact","manu",.F.,0)
NetUse("engkund","ku",.F.,0)
NetUse("artlief","ali")
ali->(dbSetOrder( 1 ))

ku->(dbSetOrder(8))
cManu := Space(8)
manu->(dbSeek( Str(aManu[1][nManu],5) ))
If manu->address != 0 .AND. ! ku->(dbSeek( Str(manu->address,6) ))
   Alert("Supplier not found")
Else
   cManu := ku->Kunde
Endif

hProducts := {=>}
nCount := 0
@ 15,00 SAY "Daten werden gesammelt"
rech->(dbSeek( Str(nYear,4)+"0101" ,.T. ))

DO WHILE ! rech->(Eof()) .AND. Year(rech->Rechdat) >= nYear //nI <= len(aSup)

   //? aSup[ni],pr(4)
   cSup := rech->Liefma

   ku->(dbSetOrder(1))
   ku->(dbSeek( rech->liefma+"L" ))
   rpos->(dbSeek( rech->Liefma+rech->Rechnr ))
   DO WHILE ( rpos->liefma == rech->Liefma .AND. rpos->Beleg == rech->Rechnr  ) //aSup[ni] )
     IF nCount%70 == 0
	     @ 15,22 SAY Replicate(".",(nCount/70) % 4)+Space(3)
	  ENDIF

      art->(dbSeek(Str(rpos->artikelnr,6)))
      IF art->Manufactur == aManu[1][nManu] .AND.  ! fol->(dbSeek( Str(art->artikelnr,6) ))
         cMatch := Trim(art->Matchcode)
         IF ali->(dbSeek(cManu+Str(rpos->artikelnr,6))) .AND. ! Empty(ali->Artlief)
            cMatch := Trim(ali->Artlief)
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
                  hProducts[cMatch][cYear] := {"QTY"=>0,"PRICE"=>0}
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
      ENDIF
      rpos->(dbSkip())
      nCount++
   ENDDO
   rech->(dbSkip())
ENDDO


SET PRINTER TO (Trim(Tr_Getini(1))+"\export\POP_"+Trim(aManu[2][nManu])+"_"+Str(nYear,4)+"_PRODUCTS.csv")
SET PRINTER ON
?? "Artikel"
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


Tone(700,10);Tone(900,10);Tone(1100,10)
