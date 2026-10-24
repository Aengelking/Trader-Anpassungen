#define CRLF Chr(13)+Chr(10)

FUNCTION RUN_INFORM_SALES_STOCK_BLOCK(nArtnr, nMenge)
   LOCAL aEnv := SaveEnv()
   LOCAL cMatch := ""
   LOCAL cSubject
   LOCAL cBody
   LOCAL nBuyer
   LOCAL cBuyerKey
   LOCAL hBuyers := {=>}
   LOCAL hBuyer
   LOCAL cEmail
   LOCAL cName
   LOCAL nOpen
   LOCAL cLine
   LOCAL cKunde 
   LOCAL cKundeName
   LOCAL cTerm 

   Default(@nArtnr, 0)
   Default(@nMenge, 0)

   IF nArtnr <= 0
      RestEnv(aEnv, .F.)
      RETURN .F.
   ENDIF

   NetUse("engauf", "auf")
   NetUse("buyer", "buy")
   NetUse("artikel", "art")
   NetUse("engkund", "ku")

   art->(dbSetOrder(2))
   IF art->(dbSeek(Str(nArtnr, 6)))
      cMatch := AllTrim(art->Matchcode)
   ENDIF

   auf->(dbSetOrder( 3 )) //matchcode+bestat
   
   auf->(dbClearFilter())
   auf->(dbSetFilter({||  (auf->VkQty - auf->GelQty) != 0}, ;
                     "(VkQty - GelQty) != 0"))
  
   auf->(dbSeek( art->Matchcode , .T. ))

   DO WHILE ! auf->(Eof()) .AND. auf->Artikelnr == nArtnr .AND. auf->Bestat < 3
      nBuyer := auf->Buyer
      IF nBuyer <= 0
         auf->(dbSkip())
         LOOP
      ENDIF

      
      

      cBuyerKey := Str(nBuyer, 6)
      IF ! HHasKey(hBuyers, cBuyerKey)
         buy->(dbGoTo(nBuyer))
      
         hBuyers[cBuyerKey] := {=>}
         hBuyers[cBuyerKey]["email"] := AllTrim(buy->Email)
         hBuyers[cBuyerKey]["name"] := AllTrim(buy->Buyer)
         hBuyers[cBuyerKey]["lines"] := {}
      ENDIF

      IF Empty(hBuyers[cBuyerKey]["email"])
         auf->(dbSkip())
         LOOP
      ENDIF

      cKunde := AllTrim(auf->Kundma)
      cKundeName := ""
      ku->(dbSetOrder(1))
      IF ku->(dbSeek(Pad(cKunde, 8) + "K"))
         cKundeName := AllTrim(ku->Name1)
      ENDIF

      nOpen := auf->VkQty - auf->GelQty
      IF ValType(auf->BDatum) == "D" .AND. ! Empty(auf->BDatum)
         cTerm := DToC(auf->BDatum)
      ELSE
         cTerm := LTrim(Str(auf->DTerm, 4))
      ENDIF

      cLine := "Auftrag " + LTrim(Str(auf->AbNr, 6)) + ;
               " Pos " + LTrim(Str(auf->Itmnr, 3)) + ;
               " Kunde " + cKunde + IF(Empty(cKundeName), "", " (" + cKundeName + ")") + ;
               " Offen " + LTrim(Str(nOpen)) + ;
               " Termin " + cTerm

      AAdd(hBuyers[cBuyerKey]["lines"], cLine)

      auf->(dbSkip())
   ENDDO

   auf->(dbClearFilter())

   FOR EACH hBuyer IN hBuyers
      cEmail := hBuyer["email"]
      cName := hBuyer["name"]
      IF ! Empty(cEmail)
         cSubject := "Lieferung gef„hrdet: " + IF(Empty(cMatch), LTrim(Str(nArtnr, 6)), cMatch)

         cBody := "Ein Artikel wurde in ein Sperrlager bewegt. Die Lieferung folgender Auftr„ge kann gef„hrdet sein:" + CRLF + CRLF
         cBody += "Artikel: " + IF(Empty(cMatch), LTrim(Str(nArtnr, 6)), cMatch) + CRLF
         cBody += "Menge blockiert: " + LTrim(Str(nMenge)) + CRLF + CRLF

         FOR EACH cLine IN hBuyer["lines"]
            cBody += "- " + cLine + CRLF
         NEXT

         SendMail({{cEmail, cName}}, cSubject, cBody)
         //SendMail({{"amos.engelking@engelking.de", cName}}, cSubject, cBody)
      ENDIF
   NEXT

   RestEnv(aEnv, .F.)

RETURN .T.
