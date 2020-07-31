
FUNCTION HOOK_ON_AUF_READY( nAbNr,lWish )
   LOCAL cText
   LOCAL oExtra := ku->(ExtraData():New(ku->Nummer))
//LOCAL cScr

/*IF ! GetConfigValue("BATCHMODE")
   cScr := SaveScreen()
   //Alert("Auftrag "+LTrim(Str(nAbNr))+" bereit")
   IF lWish
      Alert("Wunschtermin")
   ELSEIF ku->KSperren == "Y"
      Alert("Kunde "+ku->Kunde+" gesperrt")
      RETURN .F.
   ENDIF
   __KeyBoard(Chr(K_ENTER)+Chr(K_PGDN))
   
   engreab(nAbnr)
   
   RestScreen(,,,,cScr)
   
   RETURN .F.  //return .T. still sends email
ENDIF*/
IF lWish .AND. oExtra:NoWish //diese Kunden m”chten keine direkte Lieferung zum Wunschterm sondern es muss zun„chst einer Termin„nderung erfolgen
   
   cText := "Bei diesem Auftrag k”nnten Positionen ausgeliefert werden (Wunschtermin),<br>"
   cText += "jedoch m”chte dieser Kunde informiert werden wenn wir die Lieferung vorziehen (best„tigter Termin).<br>"
   cText += "Bitte genau prfen wie dies zu erfolgen hat (Lieferantenportal/Termin„nderung) oder ob es evtl. vom<br>"
   cText += "Kunden best„tigt werden muss."
   
   SendMail({{"samuel.engelking@engelking.de",""}},"Termin bei AB "+LTrim(Str(nAbNr))+" kann vorgezogen werden.",cText)   
   RETURN .F.
ENDIF

RETURN .T.