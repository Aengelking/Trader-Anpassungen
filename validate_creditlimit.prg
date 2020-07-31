PARAMETERS nCredLimit,cKunde
LOCAL cScreen := SaveScreen()
LOCAL cCol := SetColor()
LOCAL cComments := ""
#define CL "<br/>"
//Chr(13)+Chr(10)

nLimit := Hook("get_customercreditlimit",{ku->Nummer,cKunde,nCredLimit})

If Round(nLimit,0) < Round(nCredLimit,0)
   NetUse("engkund","ku")
   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( cKunde+"K" ))

   IF ku->CountryIso == "DE" .AND. nCredLimit <= 20000
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
         cMessage += "Vielen Dank"+CL
         cMessage += Buy(TR_getini(28),.T.,0)
         SendMail({{"amos.engelking@engelking.de","Amos Engelking"}},"Kreditanfrage "+cKunde,cMessage,,,,.T.)
         RestScreen(,,,,cScreen)
         SetColor(cCol)
      ENDIF
      //Tr_MsgBox("Kreditlimit kann nicht erteilt werden. Maximal: "+LTrim(str(nLimit)))
   ELSEIF Tr_MsgBox("Soll eine Kreditanfrage an Sigrid versendet werden?",,{"Nein","Ja"}) == 2
      cMessage := "Hallo Sigi,"+CL+CL
      cMessage += HB_AnsiToOem("bitte beantrage ein Kreditlimit für ")+CL
      Cmessage += "Matchcode: "+cKunde+CL
      cMessage += Trim(ku->Name1+" "+Trim(ku->Name2))+CL
      cMessage += ku->Street+CL
      cMessage += ku->PLZ+" "+ku->Town+CL
      cMessage += GetCountryName(ku->CountryIso)+CL+CL
      cMessage += HB_AnsiToOem("in Höhe von mind. "+LTrim(Str(nCredLimit,12))+" EUR")+CL+CL
      cMessage += "Vielen Dank"+CL
      cMessage += Buy(TR_getini(28),.T.,0)
//      SendMail({{"amos.engelking@engelking.de","Sigrid Reichmann"}},"Kreditanfrage "+cKunde,cMessage)
      SendMail({{"sigrid.reichmann@engelking.de","Sigrid Reichmann"}},"Kreditanfrage "+cKunde,cMessage,,,,.T.)
      Return .T.
   Endif
Else
   Return .T.
Endif

/*If nCredLimit<=5000 .OR. Tr_MsgBox("Bist Du sicher?","Hoher Kreditlimit",{"Nein","Ja"})==2
	Return .T.
Endif*/

Return .F.