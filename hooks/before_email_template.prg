FUNCTION HOOK_before_email_template(cTemplateFile,hTemplateData,oObject,cLang,oPrinter)
   LOCAL nAngnr := 0

   // Kundenbewertung: Link vom CRM holen fuer %bewertung% in ab_*.html / ang_*.html.
   // Der Hook laeuft erst, wenn feststeht, dass eine Mail rausgeht (Drucker gewaehlt),
   // und bevor die Platzhalter ersetzt werden. Vorschau/Papier pruefen CRM_FeedbackHtml.
   // Ein Fehler darf den Versand nicht abbrechen.
   IF ValType(hTemplateData) != "H" .OR. ValType(cTemplateFile) != "C"
      RETURN NIL
   ENDIF
   hTemplateData["bewertung"] := ""

   BEGIN SEQUENCE
      IF Lower(cTemplateFile) == "ab" .AND. ValType(oObject) == "O"
         // Angebotsnummer: erste Position, die aus einem Angebot entstanden ist
         // (Opportunity im CRM), sonst ohne.
         oObject:Positions:Each({|oPos|
            IF ! Empty(oPos:Angnr)
               nAngnr := oPos:Angnr
               RETURN .F.
            ENDIF
            RETURN .T.
         })
         LoadPrg(Path("run\crm_email.prg"))
         hTemplateData["bewertung"] := HB_ExecFromArray({"CRM_FeedbackHtml", "AB", LTrim(Str(oObject:AbNr)), oObject:Kundma, oObject:Person, ;
            IF(nAngnr != 0, LTrim(Str(nAngnr)), "")})
      ELSEIF Left(Lower(cTemplateFile),3) == "ang" .AND. HB_HHasKey(hTemplateData,"nr") .AND. Select("ku") != 0
         LoadPrg(Path("run\crm_email.prg"))
         hTemplateData["bewertung"] := HB_ExecFromArray({"CRM_FeedbackHtml", "Angebot", hTemplateData["nr"], ku->Kunde})
      ENDIF
   RECOVER
      //nicht fatal
   END SEQUENCE
RETURN NIL
