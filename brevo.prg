#include 'hbclass.ch'
//#include 'y:\harbour\trader\source\include\trget.ch'
#include 'inkey.ch'

PROC TestBrevo
   LOCAL oBrevo := Brevo():New()
   LOCAL hResponse,hTemplate,cParam
   LOCAL hTemplates := {=>},nX
   LOCAL nTemplate := 1
   LOCAL aParams := {}
   LOCAL hParams := {=>}
   LOCAL getlist := {}
   LOCAL hManu := GetManufacturerHash()
   LOCAL nRow

   Head("Produktmailing")

   hResponse := oBrevo:Execute("smtp/templates","GET")

   IF ValType(hResponse) != "H"
      Tr_MsgBox("Fehler","Fehler beim Abruf der Vorlagen")
      RETURN 
   ENDIF
   FOR nX := 1 TO Len(hResponse["templates"])
      hTemplate := hResponse["templates"][nX]
      IF AT("{{product.",hTemplate["htmlContent"]) > 0
         //? hTemplate["id"],hb_utf8tostr(hTemplate["name"])     
         hTemplates[nX] := hb_utf8tostr(hTemplate["name"])
      ENDIF
   NEXT
   IF Len(hTemplates) == 0
      Tr_MsgBox("Fehler","Keine Vorlagen fr Produktmailings gefunden")
      RETURN
   ENDIF
   @ 01,00 SAY "Vorlage"
   @ 01,15,20,40 GET nTemplate LISTBOX hTemplates ASSOCIATIVE
   READ
   IF LastKey() == K_ESC .OR. nTemplate == 0
      RETURN
   ENDIF
   @ 02,00 SAY Replicate(Chr(196),05)+" FELDER "+Replicate(Chr(196),28)
   nRow := 03
   FOR EACH cParam IN HB_ATokens(hResponse["templates"][1]["htmlContent"],"{{")
      cParam := SubStr(cParam,1,AT("}}",cParam)-1)
      IF Left(cParam,7) == "params." .AND. ! cParam $ aParams         
         Aadd(aParams,cParam)
         IF cParam == "params.manufacturer"
            hParams[cParam] := 1
            @ nRow,00 SAY "Hersteller"
            @ nRow,15,22,40 GET hParams["params.manufacturer"] LISTBOX hManu ASSOCIATIVE
         ELSEIF cParam == "params.increase"            
            hParams[cParam] := 0
            @ nRow,00 SAY "Preiserh”hung"
            @ nRow,15 GET hPArams["params.increase"] PICTURE "99.99"
            @ nRow,21 SAY "%"
         ELSE
            hParams[cParam] := Space(255)
            @ nRow,00 SAY cParam
            @ nRow,15 GET hParams[cParam] PICTURE "@S25"
         ENDIF
         nRow++
      ENDIF
   NEXT
   @ nRow,00 SAY Replicate(Chr(196),05)+" PRODUKT/KUNDEN AUSWAHL "+Replicate(Chr(196),12)
   IF Len(hParams) != 0
      READ
      IF LastKey() == K_ESC
         RETURN
      ENDIF
   ENDIF
   Sinkey(0)
   Alert(ValToPrg(hResponse))
RETURN

CLASS Brevo FROM RestApi
   METHOD New
   METHOD Execute
ENDCLASS

METHOD New()
   ::cBaseUrl := "https://api.brevo.com/v3/"
   ::cApiKeyName := "BREVO-API"
RETURN SELF

METHOD Execute(cPath,cMethod,hData)
   LOCAL hResponse
   LOCAL aHeader

   aHeader := {"accept: application/json","content-type: application/json"}
   Aadd(aHeader,"api-key: $APIKEY$")

   hResponse := HB_JsonDecode(::Super:Execute(cPath,cMethod,hData,aHeader,.T.))

RETURN hResponse

/*
FUNCTION SendMailTemplate(aTo,nTemplate,hParams,hResponse)
   LOCAL oBrevo := RestApi():New()
   LOCAL hData,aHeader

   oBrevo:cBaseUrl := "https://api.brevo.com/v3/smtp/"   

   hData := {=>}
   hData["to"] := {aTo}   
   hData["bcc"] := {{"email"=>"amos.engelking@engelking.de","name"=>"Amos Engelking"}}   
   hData["templateId"] := nTemplate
   hData["params"] := hParams
   aHeader := {"accept: application/json","content-type: application/json"}
   Aadd(aHeader,"api-key: ")

   hResponse := HB_JsonDecode(oBrevo:Execute("email","POST",hData,aHeader,.T.))

RETURN ValType(hResponse) == "H" .AND.HHasKey(hResponse,"messageId")
*/