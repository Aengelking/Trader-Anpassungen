
#include 'hbclass.ch'

FUNCTION SNAPADDY_Test
   LOCAL oSnap := SnapAddy():New()
   LOCAL aEvents := oSnap:Execute("questionnaires/all","GET")["questionnaires"]

   NetUse("contacts","conts",.F.,0)
   NetUse("engkund","ku",.F.,0)

   ku->(dbSetOrder( 8 ))

   Alert(aEvents[3]["titles"]["de"])
   aParticipants := oSnap:Execute("questionnaires/"+Ltrim(aEvents[3]["id"])+"/participants/all","GET")["participants"]
   //Alert(ValToPrg(aParticipants[1]))
   //organization": "NINGBO DEGSON ELECTRICAL CO., LTD.",
   //"email": "scampbell@degson.com"
   FOR nX := 1 TO Len(aParticipants)
      ? aParticipants[nX]["email"]
      conts->(dbGoTop())
      dbSelectArea("conts")
      LOCATE FOR At(Lower(aParticipants[nX]["email"]),Lower(conts->Email)) != 0
      IF conts->(Found())
         ? conts->Address
         ku->(dbSeek( Str(conts->Address,6) ))
         ?? "",ku->Kunde,ku->Name1,Pad(conts->Name,30)
      ELSE
         conts->(dbSetFilter( {|| At(Lower(SubStr(aParticipants[nX]["email"],AT("@",aParticipants[nX]["email"]))),Lower(conts->Email)) > 0 },'At("'+Lower(SubStr(aParticipants[nX]["email"],AT("@",aParticipants[nX]["email"])))+'",Lower(Email))>0'))
         conts->(dbGoTop()) 
         //LOCATE FOR At(Lower(SubStr(aParticipants[nX]["email"],AT("@",aParticipants[nX]["email"]))),Lower(conts->Email)) != 0
         IF ! conts->(BOF()) .AND. ! conts->(EOF()) //conts->(Found())            
            ? conts->Address
            ku->(dbSeek( Str(conts->Address,6) ))
            DO WHILE conts->Address == ku->Nummer .AND. ! conts->(EOF())
               conts->(dbSkip())
            ENDDO         
            IF conts->(EOF()) //there is only one address
               ?? "",ku->Kunde,ku->Name1,"Neuer Kontakt"
            ELSE
               ? conts->Address
            ENDIF
         ENDIF
         conts->(dbClearFilter())
      ENDIF
      IF Inkey() == 27
         EXIT
      ENDIF
   NEXT

RETURN NIL


CLASS SnapAddy FROM RestApi
   METHOD Execute
   METHOD New
ENDCLASS

METHOD New
   ::cKeyName := "SNAPADDY"
   ::cBaseUrl := "https://api.snapaddy.com/visitreport/v1/backend/" //GetValue("SNAPADDY_URL","https://engelking.nocrm.io/api/v2/","URL of the noCRM instance")
RETURN ::Super:New()


METHOD Execute(cUrl,cMethod,hData,lJson,lAsUsr)
   LOCAL cData //,cItem
   LOCAL aReturn
   LOCAL oErr
   LOCAL aHeader
   LOCAL nResponse,cResponse

   Default(@cMethod,"GET")
   Default(@lJson,.T.)
   Default(@lAsUsr,.F.)

   aHeader := {"X-API-TOKEN: 1om0dHxjBCIEGDCCDk01AOsR3rW1zBzbczzBfpdZ"} //+IF(lAsUsr .AND. ! Empty(::cUsrToken),::cUsrToken,"$PASSWORD$")} 
   Aadd( aHeader, "Content-Type: application/json" ) 
   
   cData := ::Super:Execute(cUrl,cMethod,hData,aHeader,.T.,@nResponse,@cResponse)

   IF ! lJson
      RETURN cData
   ENDIF

   aReturn := HB_JSonDecode(cData)      
   
   IF ! Valtype(aReturn) $ "AH"
      oErr := ErrorNew()
      oErr:SubSystem   := "SNAPADDY-API"
      oErr:Description := "Error executing command. "+cData+"("+LTrim(Str(nResponse))+" "+cResponse+")"
      oErr:Args        := {cUrl,cData}
      Throw(oErr)   
   ELSEIF ValType(aReturn) == "H" .AND. HHasKey(aReturn,"error")
      ::cErrorText := aReturn["message"]
      ::nError := aReturn["error"]
      ::cErrorType := aReturn["type"]
      RETURN NIL
   ENDIF
RETURN aReturn