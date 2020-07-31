PROCEDURE WunschterminList
   LOCAL cKunde 
   LOCAL nKunde := 25778 //FP
   LOCAL cFilter
   LOCAL cText
   LOCAL cBL,oArt

   NetUse("engauf","auf")
   NetUse( "plzbl"   , "plzbl", .F., 0 )
   NetUse( "bundesl" , "bl", .F., 0 )
   NetUse( "engkund", "ku")
   ku->(dbSetOrder( 8 ))
   ku->(dbSeek( Str(nKunde,6) ))
   cKunde := ku->Kunde

   IF plzbl->( dbSeek( StrZero( Val( StrTran( ku->PLZ, "D-" ) ), 5 ) ) ) .AND. bl->( dbSeek( plzbl->BL ) )
      cBL := bl->Short
   ELSE
      cBL := GetConfigValue("STATE")
   ENDIF

   cFilter := 'bestat <= 2 .AND. vkqty-gelqty > 0 .AND. Right(Str(dterm,4),2)!="99" .AND. wdatum != bdatum'
   auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter))

   auf->(dbSetOrder( 2 ))
   auf->(dbSeek( cKunde, .T. ))   
   CLS

   cText := "Hallo,<br>bei folgenden Auftragspositionen weicht der best„tigte Termin vom Wunschtermin ab:<pre>"
   cText += "AB-Nr  Pos "+Pad("Matchcode",25)+" "+PadL("Menge",12)+" "+"Wunsch  "+" "+"Best„tigt"+Chr(13)+Chr(10)

   DO WHILE auf->Kundma == cKunde .AND. ! auf->(EOF())
      IF auf->BDatum > auf->WDatum .OR. auf->BDatum < AddWorkingDays(auf->WDatum,-1,cBL)
         oArt := Artikel():New()
         oArt:Load(auf->Artikelnr)
         cText += Str(auf->Abnr,6)+" "+Str(auf->Itmnr,3)+" "+auf->Matchcode+" "+PadL(Transform(auf->VkQty-auf->GelQty,oArt:cPicture),12)+" "+DtoC(auf->wdatum)+" "+DtoC(auf->bdatum)+Chr(13)+Chr(10)
      ENDIF
      auf->(dbSkip())
   ENDDO
   cText += "</pre>"

   SendMail({{"sabid.pehlic@engelking.de","Sabid"},{"amos.engelking@engelking.de","Amos","CC"}},"Abweichende Wunschtermine",cText,,,,.T.)
RETURN