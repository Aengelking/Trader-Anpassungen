PROCEDURE RUN_CHECK_MUSTER
   LOCAL dStart,dVeryOld
   LOCAL hUsers := {=>},hUser,cText,oUsr
   LOCAL nRec,oArt

   Netuse("muster","mus")
   mus->(dbSetOrder( 6 ))
   mus->(dbGoTop())

   dStart := AddMonth(Date(),-1)
   dVeryOld := AddMonth(Date(),-12)

   CLS

  

   DO WHILE ! mus->(EOF()) .AND. mus->Status <= 2
      IF mus->Datum <= dVeryOld
         ? mus->Nummer,mus->Matchcode
         mus->(dbSkip())
         nRec := mus->(Recno())
         mus->(dbSkip(-1))
         mus->(Rec_Lock(0))
         //mus->Status := 3
         mus->(dbUnLock())
         mus->(dbGoto( nRec ))
      ELSEIF mus->Datum <= dStart .AND. Trim(mus->Kunde) != "SELF"
         IF ! HHasKey(hUsers,mus->Buyer)
            hUsers[mus->Buyer] := ""
         ENDIF
         oArt := Artikel():New()
         oArt:Load(mus->Artikelnr)
         hUsers[mus->Buyer] += DToC(mus->Datum)+" "+Str(mus->Nummer)+" "+mus->Kunde+" "+mus->Matchcode+" "+Transform(mus->Menge,oArt:cPicture)+" "+GetFormatedBestand()+"<br/>"
      ENDIF
      mus->(dbSkip())
   ENDDO

   FOR EACH hUser IN hUsers
      oUsr := User():New()
      oUsr:Load(hUser:__eNumKey())

      cText := "Hallo "+Trim(SubStr(oUsr:Buyer,1,AT(" ",oUsr:Buyer)))+",<br><br>"
      cText += t("folgende Musteraufträge konnten nicht versandt werden:")+" <br /><pre>"+Pad("Datum",8)+" "+Pad("Nummer",6)+" "+Pad("Kunde",8)+" "+Pad("Artikel",25)+" "+Pad("Menge",12)+" "+Pad("Bestand",12)+"<br/>"
      cText += hUser
      cText += "</pre>"
   

      SendMail({{oUsr:Email,oUsr:Buyer}},t("Offene Musteraufträge"),cText,,,,.T.)
   NEXT
//SInkey(0)