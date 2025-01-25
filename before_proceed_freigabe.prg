#define CRLF Chr(13)+Chr(10)

FUNCTION HOOK_BEFOER_PROCEED_FREIGABE(nNr,cLevel,cNext,nArtnr,nSupplier,aFields,nUser,cCust,nPerson,dDate,lFree,lSonder,nSoQty,dSoDate)
   LOCAL oExtra := art->(ExtraData():New(nArtnr))
   LOCAl oArt,oLief
   LOCAL cList := ""
   
   HB_SYMBOL_UNUSED(nNr)
   HB_SYMBOL_UNUSED(cNext)
   //HB_SYMBOL_UNUSED(nSupplier)
   HB_SYMBOL_UNUSED(aFields)
   HB_SYMBOL_UNUSED(nUser)
   HB_SYMBOL_UNUSED(cCust)
   HB_SYMBOL_UNUSED(nPerson)
   HB_SYMBOL_UNUSED(dDate)
   HB_SYMBOL_UNUSED(lSonder)
   HB_SYMBOL_UNUSED(nSoQty)
   HB_SYMBOL_UNUSED(dSoDate)


   IF lFree .AND. Trim(cLevel) == "UNT" .AND. oExtra:Critical .AND.;
      Tr_MsgBox({"Wurde die StÅckliste gegen die Anforderungen aus der Liste der kritischen Komponenten geprÅft?"},"KRITISCHE KOMPONENTE",{"Nein","Ja"}) != 2
      RETURN .F.
   ENDIF

   IF lFree .AND. Trim(cLevel) $ {"KU","DONE"} .AND. nSupplier != 0
      oArt := Artikel():New()
      oArt:Load(nArtnr)
      oLief := Adresse():New()
      oLief:Load(nSupplier)
      Alert(oLief:Kunde)

      NetUse("engbes","bes")
      bes->(dbSetOrder( 8 ))
      bes->(dbSeek( oLief:Kunde+oArt:Matchcode ))
      DO WHILE bes->Bestat < 3 .AND. bes->Liefma == oLief:Kunde .AND. bes->Matchcode == oArt:Matchcode
         cList += Str(bes->Besnr)+CRLF
         bes->(dbSkip())
      ENDDO

      IF ! Empty(cList)
         SendMail({{"purchasing@engelking.de","Einkauf"}},"Bestellungen freigeben","Bitte prÅfe ob bei den folgenden Bestellung die Materialfreigabe aufgehoben werden kann:"+CRLF+CRLF+cList)
      ENDIF
   ENDIF
RETURN .T.