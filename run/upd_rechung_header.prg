PROC RUN_UPD_RECHUNG_HEADER
LOCAL aFields  := {}
LOCAL hFields  := {=>}
LOCAL cField,bFieldOld,xValue

//#define TEST

IF Tr_Getini(28) != 9
   Alert("Zugriff verweigert")
   RETURN   
ENDIF
IF Tr_MsgBox("Rechnungsk”pfe ersetzten?",,{"Nein","Ja"}) != 2
   RETURN
ENDIF

NetUse("englsre","re")
NetUse("rechnung","reh")
NetUse("engkund","ku")

re->(dbSetOrder( 8 ))
re->(dbSeek( Str(0,3)+Str(54074,6) ))

CLS


/*Aadd(aFields,"RechDat")
Aadd(aFields,"Kunde")
Aadd(aFields,"Skonto")
Aadd(aFields,"DelAd")
Aadd(aFields,"Money")
Aadd(aFields,"TaxCode")
Aadd(aFields,"ReArt")
Aadd(aFields,"Rabatt")
Aadd(aFields,"Mahnen")
Aadd(aFields,"Person")
Aadd(aFields,"Express")
Aadd(aFields,"Versandart")
Aadd(aFields,"Ablade")*/


/*hFields["Porto"] := {|| Round(re->ofqty,2) }
hFields["KuNummer"] := {|| ku->Nummer }
hFields["MwStRate"] := {|| re->Kurs }
hFields["MwSt"] := {|| re->Preis }
hFields["Brutto"] := {|| re->PosWt }
hFields["MahnDat"] := {|| re->MaDate }
hFields["LastMahn"] := {|| re->LastMa }
hFields["Mahnung"] := {|| re->Rem }
hFields["NextMahn"] := {|| re->Nextma }
hFields["ReLiefAd"] := {|| re->ReLiefAdr }*/
hFields["Bezahlt"] := {|| re->Code >= 3 }
//hFields["Ready"] := {|| re->Code >= 1 }
//hFields["Gedruckt"] := {|| re->Code >= 2 }
//hFields["ZahlBetrag"] := {|| Round(re->AoQty,2) }
//hFields["ZahlDatum"] := {|| re->PayDate }
//hFields["Versandt"] := {|| re->Packed }
//hFields["Transfer"] := {|| re->Transfer }

//hFields["pnum"] := {|| re->Termin }  //field does not exist


FOR EACH cField IN aFields
   hFields[cField] := {|| re->(FieldGet( re->(FieldPos(cField)) )) }
NEXT


DO WHILE re->RePosnr == 0 .AND. ! re->(Eof())
   @ MaxRow(),00 SAy re->Rechnr
   ku->(dbSeek( re->Kunde+"K" ))


   IF ! reh->(dbSeek( Str(re->Rechnr,6) ))
      ? "New"
      #ifndef TEST
         reh->(Add_Rec(0))
         reh->Rechnr  := RE->rechnr
      #endif
   ELSE
      reh->(Rec_Lock())
   ENDIF

   FOR EACH bFieldOld IN hFields
      cField := bFieldOld:__enumKey()
      nFieldPos := reh->(FieldPos(cField))
      xValue := reh->(FieldGet( nFieldPos ))
      IF xValue != Eval(bFieldOld)
         ? re->Rechnr,cField,"re:",ValToPrg(Eval(bFieldOld)),"reh:",ValToPrg(xValue)
         
         #ifndef TEST
            ?? ", Set: ",reh->(FieldPut(nFieldPos,Eval(bFieldOld)))
         #endif

      ENDIF
   NEXT

   reh->(dbUnLock())

/*   reh->Porto   := RE->ofqty
   reh->RechDat := RE->rechdat
   reh->Kunde   := RE->kunde
   reh->KuNummer := ku->Nummer
   reh->Skonto  := RE->skonto
   reh->DelAd   := re->delad
   reh->Money   := re->Money
   reh->MwStRate    := re->Kurs
   reh->MwSt    := re->Preis
   reh->Brutto  := re->PosWt
   reh->TaxCode := RE->taxcode
   reh->ReArt   := RE->reart
   reh->Rabatt  := re->rabatt
   reh->Mahnen  := re->mahnen
   reh->MahnDat := re->MaDate
   reh->LastMahn := re->LastMa
   reh->Mahnung  := re->Rem
   reh->NextMahn := re->Nextma
   reh->Person  := RE->PERSON
   reh->ReLiefAd := re->ReLiefAdr
   reh->Versandart := re->versandart
   reh->Express   := re->express
   reh->Ablade    := re->Ablade
   reh->Bezahlt    := re->Code >= 3
   reh->Ready     := re->Code >= 1
   reh->Gedruckt  := re->Code >= 2*/
/*   reh->ZahlBetrag := re->AoQty
   reh->ZahlDatum  := re->PayDate
   reh->Versandt   := re->Packed
   reh->Transfer   := re->Transfer
   reh->(dbUnLock())*/

   re->(dbSkip())
   nKey := Inkey()
   IF nKey == 27
      EXIT
   ELSEIF Upper(Chr(nKey)) == "P"
      SInkey(0)
   ENDIF
ENDDO

SInkey(0)

/**
   FIELDS that could be removed later :
   Rechdat
   Skonto
   Delad
   Money
   Kurs   //except if this is used for the exchange rate on the positions
   TaxCode
   ReArt
   Mahnen
   ReLiefAdr
   Versandart
   Express
   Ablade
   PayDate
   Packed
   Transder
**/