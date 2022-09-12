FUNC HOOK_VALIDATE_CREDITLIMIT(nCredLimit,cKunde)
LOCAL cScreen := SaveScreen()
LOCAL cCol := SetColor()
LOCAL cComments := ""
LOCAL cMessage,nLimit
LOCAL aTo,oExtra,oReport
LOCAL nError
MEMVAR c_five
#define CL "<br/>"
//Chr(13)+Chr(10)

IF Date() <= StoD("20210924")
   aTo := {"celina.engelking@engelking.de","Celina"}
ELSE
   aTo := {"sigrid.reichmann@engelking.de","Sigrid"}
ENDIF

nLimit := Hook("get_customercreditlimit",{ku->Nummer,cKunde,nCredLimit,@nError})

If Round(nLimit,0) < Round(nCredLimit,0)
   NetUse("engkund","ku")
   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( cKunde+"K" ))   
   
   IF ku->CountryIso == "DE" .AND. nCredLimit <= 20000 
      IF Tr_Getini(28) == 9 .AND. nError $ {101,102} .AND. Trim(ku->CompForm) $ {"GMBH","AG","EK","KG","KGaA","OHG","SE","UG"} .AND. Tr_MsgBox("Kein Eintrag bei Creditsafe gefunden. Nummer hinterlegen?",,{"Ja","Nein"}) != 2
         EditCSNumber()
         nLimit := Hook("get_customercreditlimit",{ku->Nummer,cKunde,nCredLimit,@nError},0)
         IF nLimit >= nCreditLimit
            RETURN .T.
         ENDIF
      ENDIF

      IF GetAccountsContact(ku->Nummer) == NIL
         Tr_MsgBox("Bitte Buchhaltungskontakt erfragen und hinterlegen")
         RETURN .F.
      ENDIF      
      oExtra := ku->(ExtraData():New(ku->Nummer))
      IF ! oExtra:AutoMahn  //autom. Mahnung wurde noch nicht aktiviert, dann holen wir das Rating und sehen ob es schlechter als 3.0 ist und aktivieren dann autom. Mahnung und prfen das Limit erneut
         oReport := CS_GetCompanyReportFromArchive(ku->Nummer)
         IF oReport != NIL .AND. oReport:oRoot != NIL
            oIter := TXmlIteratorScan():New(oReport:oRoot)
            oNode := oIter:Find("DECurrentRating")
            IF oNode == NIL .OR. Val(oNode:cData) > 3.0
               oExtra:AutoMahn := .T.
               oExtra:Save()
               nLimit := Hook("get_customercreditlimit",{ku->Nummer,cKunde,nCredLimit,@nError})
               If Round(nLimit,0) >= Round(nCredLimit,0)
                  RETURN .T.
               ENDIF
            ENDIF
         ENDIF
      ENDIF     

      IF Tr_MsgBox({"Kreditlimit kann nicht erteilt werden. Maximal: "+LTrim(str(nLimit)),HB_AnsiToOem("Soll eine manuelle Einzelprüfung Kreditanfrage an Amos versendet werden?")},,{"Nein","Ja"}) == 2
         SetColor(c_five)
         @ 10,10 CLEAR TO 20,40
         @ 10,10 TO 20,40
         @ 10,11 SAY "[Kommentare]"
         @ 20,11 SAY "[Beenden mit STRG-W oder ESC]"
         cComments := MemoEdit(cComments,11,11,19,39)

         cMessage := "Hallo Amos,"+CL+CL
         cMessage += HB_AnsiToOem("bitte prüfe ob ein Kreditlimit für ")+CL
         Cmessage += "Matchcode: "+cKunde+CL
         cMessage += Trim(ku->Name1+" "+Trim(ku->Name2))+CL
         cMessage += ku->Street+CL
         cMessage += ku->PLZ+" "+ku->Town+CL
         cMessage += GetCountryName(ku->CountryIso)+CL+CL
         cMessage += HB_AnsiToOem("in Höhe von "+LTrim(Str(nCredLimit,12))+" EUR möglich ist")+CL+CL
         cMessage += "Kommentare:"+CL
         cMessage += cComments+CL+CL
         IF nError $ {101,102} //bei fehler 101 und 102 muss ein manueller Eintrag der CS ID erolgen
            cMessage += "Kein Creditsafe Eintrag"+CL+CL
         ENDIF
         cMessage += "Vielen Dank"+CL
         cMessage += Buy(TR_getini(28),.T.,0)
         SendMail({{"amos.engelking@engelking.de","Amos Engelking"}},"Kreditanfrage "+cKunde,cMessage,,,,.T.)
         RestScreen(,,,,cScreen)
         SetColor(cCol)
      ENDIF
      RETURN .T. //allows it to be saved
      //Tr_MsgBox("Kreditlimit kann nicht erteilt werden. Maximal: "+LTrim(str(nLimit)))
   ELSEIF Tr_MsgBox("Soll eine Kreditanfrage an "+aTo[2]+" versendet werden?",,{"Nein","Ja"}) == 2
      cMessage := "Hallo "+aTo[2]+","+CL+CL
      cMessage += HB_AnsiToOem("bitte beantrage ein Kreditlimit für ")+CL
      Cmessage += "Matchcode: "+cKunde+CL
      cMessage += Trim(ku->Name1+" "+Trim(ku->Name2))+CL
      cMessage += ku->Street+CL
      cMessage += ku->PLZ+" "+ku->Town+CL
      cMessage += GetCountryName(ku->CountryIso)+CL+CL
      cMessage += HB_AnsiToOem("in Höhe von mind. "+LTrim(Str(nCredLimit,12))+" EUR")+CL+CL
      cMessage += "Vielen Dank"+CL
      cMessage += Buy(TR_getini(28),.T.,0)
      SendMail({aTo},"Kreditanfrage "+cKunde,cMessage)
//      SendMail({{"sigrid.reichmann@engelking.de","Sigrid Reichmann"}},"Kreditanfrage "+cKunde,cMessage,,,,.T.)
      Return .T.
   Endif
Else
   Return .T.
Endif

/*If nCredLimit<=5000 .OR. Tr_MsgBox("Bist Du sicher?","Hoher Kreditlimit",{"Nein","Ja"})==2
	Return .T.
Endif*/

Return .F.

#include 'X:\run\creditsafe.prg'