PROC TEST_UpdateBranch
   LOCAL cKunde := Space(8)
   LOCAL getlist := {}
   LOCAL cFilter,nCount := 0,nSuccess := 0
   LOCAL nRec,nNextRec

   Head("Kunden mit AI einer Branche zuweisen")

   NetUse("engkund","ku")
   NetUse("kuinfo","kuinfo")

   //cFilter := "Turnover+Turnoverol > 0 .AND. ! Empty(Branch) .AND. Val(Left(branch,2)) > 0"
   cFilter := "Turnover+Turnoverol > 0 .AND. Empty(Branch)"
   //cFilter := "! Empty(Branch) .AND. Val(Left(branch,2)) > 0"

   ku->(dbSetOrder( 2 ))
   ku->(dbSetFilter({|| ku->(&(cFilter)) },cFilter))
   //ku->(dbGoTop())
   ku->(dbSeek( "K"+Pad("SELF",8) ))
   ? ku->Turnover,ku->Turnoverol,ku->Branch,ku->Group
   //DO WHILE ! ku->(EOF()) .AND. ku->Group == "K"
      nRec := ku->(Recno())
      ku->(dbSkip())
      nNextRec := ku->(Recno())
      ku->(dbGoto(nRec))

      IF ! kuinfo->(dbSeek( Str(ku->Nummer,6) )) .OR. Empty(kuinfo->Info)
         nCount ++
         ? ku->Kunde,ku->Name1,ku->Branch
         IF UpdateBrancheWithAI()
            ?? "Neue Branche: ",ku->Branch,br->Name
            ? "Beschreibung:"
            ? kuinfo->Info
            nSuccess++
         ELSE
            //add a blank record to avoid a second run, for the time being
            /*kuinfo->(Add_rec())
            kuinfo->Kunde := ku->Nummer
            kuinfo->(dbUnLock())*/
         ENDIF 
         /*? "Beliebige Taste drcken um fortzufahren"
         IF LastKey() == 27 .OR. Sinkey(0) == 27
            EXIT
         ENDIF*/
      ENDIF
      //ku->(dbSkip())
      ku->(dbGoto(nNextRec))
   //ENDDO

   Sinkey(0)
         
   /*DO WHILE .T.
      
      @ 01,00 SAY "Kunde" GET cKunde PICTURE "@!"
      READ
      IF LastKey() == 27
         RETURN
      ENDIF

      IF ! ku->(dbSeek( cKunde+"K" ))
         LOOP
      ENDIF
      CLS
      IF UpdateBrancheWithAI()
         ? Replicate(Chr(196),100)
         ? "Neue Branche: ",ku->Branch,br->Name
         ? "Beschreibung:"
         ? kuinfo->Info
      ELSE
         ? "Aktualisierung fehlgeschlagen"
      ENDIF
      Sinkey(0)
   ENDDO*/
RETURN

FUNC UpdateBrancheWithAI(cError)
   LOCAL cUrl := "https://api.perplexity.ai/chat/completions"
  
   LOCAL oRest := RestAPI():New()
   LOCAL hData := {=>},aHeader,hAnswer,cAnswer
   LOCAL cContent,hContent,cPrompt
   LOCAL cBranchen := "",oExtra,lSuccess

   cError := ""
//Alert("Starting UpdateBrancheWithAI")
   NetUse("branch","br")

   oRest:cBaseUrl := cUrl
   oRest:cApiKeyName := "PERPLEXITY"

   aHeader := {"Authorization: Bearer $APIKEY$","Content-Type: application/json"}

   hData["model"] := "sonar-pro"

   br->(dbGotop())
   DO WHILE ! br->(EOF())
      IF ! HB_RegexMatch("[0-9]",br->Branch)
         IF ! Empty(cBranchen)
            cBranchen += "; "
         ENDIF
         cBranchen += Trim(br->Name)
      ENDIF
      br->(dbSkip())
   ENDDO
   //Alert(cBranchen)
   cPrompt := "Wir haben aktuell folgende Branchen (getrennt mit ;):"+cBranchen+"."
   cPrompt += "Suche die Website der Firma "+Trim(Trim(ku->Name1)+" "+ku->Name2)+" aus "+Trim(ku->Town)+IF(!Empty(ku->Email)," (Email: "+Trim(ku->Email)+")","")+". "
   cPrompt += "Analysiere diese auf die Branche der Firma und verwende ***nur strikt dievon mir genannten Branchen***. Erstelle keine neuen Branchen und gib nur eine einzige Branche an."
   cPrompt += "Zus„tzlich gib eine Beschreibung des T„tigkeitsfelds an. "
   cPrompt += "Gib deine Antwort als ***striktes JSON*** mit den folgenden Feldnamen: company_name, industry, description,website,error zurck. "
   cPrompt += "Fge keine Erkl„rungen, Notizen oder Markdown hinzu. "
   cPrompt += "Verwende Deutsch fr die Werte der Felder."
   hData["messages"] := {;
      {"role"=>"user","content"=>hb_strToUtf8(cPrompt)};
   }

   gtSetClipboard(cPrompt)

   cAnswer := oRest:Execute("","POST",hData,aHeader,.T.)
   //cAnswer := '{"id": "fd16e43c-b2c0-4ac2-b0c2-4e0b3628169d", "model": "sonar", "created": 1745175999, "usage": {"prompt_tokens": 262, "completion_tokens": 165, "total_tokens": 427, "search_context_size": "low"}, "citations": ["https://www.miesen.de/go.to/modix/now/startseite.html", "https://www.miesen.de/go.to/modix/now/unternehmen.html", "https://de.wikipedia.org/wiki/Miesen_(Karosseriehersteller)", "http://cmiesen.com/go.to/modix/now/startseite.html", "https://bbs.fobshanghai.com/company/fr153n62j500o53.html"], "object": "chat.completion", "choices": [{"index": 0, "finish_reason": "stop", "message": {"role": "assistant", "content": "```json\n{\n  \"company_name\": \"C. Miesen GmbH & CO. KG\",\n  \"industry\": \"Automotive/Transport\",\n  \"suggested_industry\": null,\n  \"description\": \"Die C. Miesen GmbH & Co. KG ist spezialisiert auf den Auf- und Ausbau von medizinischen Spezialfahrzeugen wie Krankentransportwagen, Rettungswagen, Notarzteinsatzfahrzeugen und weiteren Sonderfahrzeugen im Bereich Medizintechnik auf Fahrzeugbasis. Damit ist das Unternehmen eindeutig in der Branche Automotive/Transport einzuordnen, da es Fahrzeugaufbauten und Spezialfahrzeuge herstellt und ausbaut.\"\n}\n```"}, "delta": {"role": "assistant", "content": ""}}]}'
   
   hAnswer := hb_JsonDecode(cAnswer)
   //? "Rohdaten:"
   //? ValToPrg(hAnswer)
   IF HHasKey(hAnswer,"choices")
      cContent :=  StrTran(hAnswer["choices"][1]["message"]["content"],"```json","")
      cContent :=  StrTran(cContent,"```","")

      hContent := hb_JsonDecode(cContent)
      //? ValToPrg(hContent)

      IF ValType(hContent) != "H" .OR. ! HHasKey(hContent,"industry")
         IF ValType(cContent) == "H" .AND. HHasKey(hContent,"error")
            cError := hContent["error"]
         ELSE
            cError := "Keine Daten erhalten"
         ENDIF
         //Alert(ValToPrg(hContent))
         RETURN .F.
      ENDIF

      br->(dbSetFilter({|| Trim(ku->Name) == hContent["industry"]},'Trim(Name) == "'+hContent["industry"]+'"'))
      br->(dbGotop())
      IF br->(EOF()) .OR. br->(BOF())
         /*aMsg := {}

         nW := MaxCol()-2
         FOR nX := 1 TO MlCount(hContent["description"],nW)
            Aadd(aMsg, MemoLine(hContent["description"],nW,nX) )            
         NEXT
         
         IF HHasKey(hContent,"suggested_industry") .AND. ! Empty(hContent["suggested_industry"])
            Aadd(aMsg,"Vorgeschlagene Branche: "+hContent["suggested_industry"])
         ENDIF

         IF Tr_MsgBox(aMsg,"Branche nicht gefunden",{"n„chster","zu Sonstige hinzufgen"}) == 2
            //hContent["industry"] := "Sonstige"
            br->(dbClearFilter())
            br->(dbSeek("SONSTIG"))
            Alert(br->Branch)
         ENDIF*/
         
         //Sinkey(0)
         //RETURN .F.
         //? "Branche nicht gefunden: ",hContent["industry"]
         //? ValToPrg(hContent)
         cError := "Fehlerhafte Branche wurde zurckgegeben."
         lSuccess := .F.
      ELSE
         //? br->Branch
         ku->(Rec_Lock())
         ku->Branch := br->Branch
         ku->(dbUnlock())
         lSuccess := .T.
      ENDIF
      

      br->(dbClearFilter())

      NetUse("kuinfo","kuinfo")
      IF kuinfo->(dbSeek( Str(ku->Nummer,6) ))
         kuinfo->(REc_Lock())
      ELSE
         kuinfo->(Add_rec())
         kuinfo->Kunde := ku->Nummer
      ENDIF
      kuinfo->Info := hContent["description"]
      kuinfo->(dbUnLock())

      oExtra := ku->(ExtraData():New(ku->Nummer))
      oExtra:Website := hContent["website"]
      oExtra:Save()
      
      RETURN lSuccess
   ENDIF

RETURN .F.