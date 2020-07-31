NetUse("engabg","abg")
NetUse("engbes","bes")

bes->(dbSetOrder( 1 ))
abg->(dbSetOrder( 3 ))

cMatch := "BX0011/1"

abg->(dbSeek( cMatch ))

nAvPreis := 0

DO WHILE Trim(abg->Matchcode) == cMatch
   IF Trim(abg->Buart) == "WE" .AND. abg->Bestand > 0
      bes->(dbSeek( Str(abg->besnr,6)+Str(abg->BesPos,3)))
      nPrice := bes->ekpr / Max(bes->pe,1) * If(bes->bestat==3.AND.bes->rate!=0,bes->rate,Currate(bes->Money,"E")) * ( 100 - bes->rabatt )/ 100

      //Gleitender Durchschnittspreis
      nAvPreis := ((abg->Bestand-abg->Menge)*nAvPreis + abg->Menge*nPrice) / abg->Bestand
      ? abg->Besnr,abg->Datum,abg->Bestand-abg->Menge,abg->Menge,nPrice,nAvPreis
   ENDIF
   abg->(dbSkip(1))
ENDDO

? nAvPreis
Inkey(0,128)
