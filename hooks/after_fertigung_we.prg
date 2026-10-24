#define CRLF Chr(13)+Chr(10)
FUNCTION HOOK_AFTER_FERTIGUNG_WE(oWerk,nQty)
   LOCAL cText,aTo
   LOCAL oExtra,cVerp,nVerpQty,aMsg
   LOCAL hUmlauf := {=>}
   LOCAL hVerpNames := {=>}
   
   HB_SYMBOL_UNUSED(nQty)
   IF art->Charge
      //SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel mit Chargenverwaltung eingebucht "+Trim(art->Matchcode))
   ENDIF
   IF wer->Status == 4  //abgeschlossen
      IF wer->BadQty > wer->PlanBad 
         cText := "Artikel: "+art->Matchcode+CRLF
         cText += "Ausschuss: "+LTrim(Transform(wer->BadQty,Me(art->Me)))+" "+art->Me+CRLF
         cText += "Geplant: "+LTrim(Transform(wer->PlanBad,Me(art->Me)))+" "+art->Me+CRLF      
         
         StickPrint("Sperrvermerk_Intern")
         

         cText += "Ausschuss bersteigt Planung"
         //aTo := {{"chris.chertes@engelking.de","Chris"}}
         //aTo := {}
         //Aadd(aTo,{"amos.engelking@engelking.de","Amos"})         
         SendMessage("Qualitaet | Ausschuss zu hoch","Ausschuss bei FA "+LTrim(Str(wer->Aufno)),cText)
      ENDIF
   

      //Umlaufverpackungen prfen
      NetUse("werks","we")

      art->(dbSetOrder(2))
      art->(dbSeek( Str(wer->Artno),6))

      oExtra := art->(ExtraData():New(wer->Artno))
      cVerp := Trim(oExtra:Umlauf)  //Artikel kommt in Umlaufverpackung zurck
      IF ! Empty(cVerp)         
         hUmlauf[cVerp] := Ceiling(oWerk:GelQty,CountPerUmlauf(cVerp))*-1 //negativ weil es in der Verpackung bleibt
         //? "Umlaufverpackung ben”tigt: "+cVerp+" Menge: "+LTrim(Str(hUmlauf[cVerp]))
      ENDIF

      //jetzt prfen wir wieviele Umlaufverpackungen an den Auftrag geliefert wurden
      we->(dbSeek( Str(wer->Aufno,6) ))
      DO WHILE we->Aufno == wer->Aufno .AND. ! we->(EOF())      
         art->(dbSeek( Str(we->Partart),6))
         oExtra := art->(ExtraData():New(we->Partart))
         cVerp := Trim(oExtra:Umlauf)  //Artikel wurde in Umlaufverpackung geliefert
         IF ! Empty(cVerp)
            IF ! HHasKey(hUmlauf,cVerp) 
               hUmlauf[cVerp] := 0
            ENDIF
            hUmlauf[cVerp] += Ceiling(we->BookQty * we->Factor/CountPerUmlauf(cVerp))
            //? we->Pos,art->Matchcode
            //? "Umlaufverpackung geliefert: "+cVerp+" Menge: "+LTrim(Str(Ceiling(oWerk:GelQty * we->Factor/CountPerUmlauf(cVerp))))
         ENDIF
         we->(dbSkip())
      ENDDO

      aMsg := {"Wurden die folgeenden Umlaufverpackungen zurckgegeben?"}
      FOR EACH nVerpQty IN hUmlauf
         IF nVerpQty >= 0                     
            Aadd(aMsg,"Verpackung: "+nVerpQty:__eNumKey()+", Menge: "+LTrim(Str(nVerpQty)))
         ENDIF
      NEXT
      IF Len(aMsg) > 1 .AND. Tr_MsgBox(aMsg,,{"Nein","Ja"}) != 2
         SendMessage("Produktion | Umlaufverpackungen fehlen","Nicht alle Umlaufverpackungen zurckgegeben bei FA "+LTrim(Str(wer->Aufno)))
      ENDIF
   ENDIF
   
RETURN .T.

STATIC FUNCTION CountPerUmlauf(cVerp)
   LOCAL aMatch := HB_Regex("[0-9]+" ,cVerp) // check if cVerp is a number
   
   IF Len(aMatch) == 0
      //Tr_MsgBox("Umlaufverpackung enth„lt keine Zahl!")
      RETURN 1      
   ENDIF

RETURN Val(aMatch[1]) // convert to number
