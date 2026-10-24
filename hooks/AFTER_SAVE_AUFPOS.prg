#define CRLF Chr(13)+Chr(10)

FUNC HOOK_AFTER_SAVE_AUFPOS(oAufPos,lNew)
   LOCAL cText
   LOCAL oFields := oAufPos:FieldsUpdatedLastSave()
   IF lNew .OR. (oAufPos:FieldUpdatedLastSave("Matchcode") .AND. oFields:Matchcode:Before != oFields:Matchcode:After)
      NetUse("projart","pjart")
      NetUse("projekte","proj")
      pjart->(dbSetOrder( 2 ))
      IF pjart->(dbSeek( Str(oAufpos:Artikel:Artikelnr,6) )) .AND. proj->(dbSeek( Str(pjart->Nummer,6) )) .AND. proj->Status == 0
         cText := "Auftrag: "+Ltrim(Str(oAufPos:Auftrag:AbNr,6))+CRLF
         cText += "Position: "+Ltrim(Str(oAufpos:Itmnr))+CRLF
         cText += "Artikel: "+Trim(oAufPos:Artikel:Matchcode)+CRLF
         cText += "Stckzahl: "+LTrim(Transform(oAufPos:VkQty,Me(oAufpos:Artikel:Me)))+CRLF         
         //SendMail({{"chris.chertes@engelking.de","Chris"}},"Auftrag fr Projekt "+LTrim(Str(proj->Nummer)),cText)      
      ENDIF
   ENDIF