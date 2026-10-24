LOCAL cCharge := ""
LOCAL cDev := Set(20,"SCREEN")

DO WHILE Empty(cCharge) .OR. Tr_MsgBox({cCharge,"OK?"},,{"Nein","Ja"}) != 2
   cCharge := GetBox(Space(25),"Chargennummer "+Trim(art->matchcode)+" von der Verpackung")
   IF Empty(cCharge)
      Tr_Msgbox({"Chargennummer darf nicht leer sein!","Falls nicht vorhanden bei Sammy oder Amos nachfragen"})
   ENDIF
ENDDO

Set(20,cDev)

RETURN cCharge