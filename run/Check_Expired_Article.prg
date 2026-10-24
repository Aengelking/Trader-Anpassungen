PROC Check_Expired_Article
   LOCAL cExpToken := "[EXP:"
   LOCAL cList := ""
   LOCAL cMessage
   
   NetUse("artikel","art")
   NetUse("lager","lag")

   lag->(dbSetOrder( 5 )) //batch+str(artikelnnr))

   lag->(dbSeek(cExpToken,.T.))

   art->(dbSetOrder( 2 ))

   DO WHILE Left(lag->Batch,Len(cExpToken)) == cExpToken

      IF StoD(SubStr(lag->Batch,Len(cExpToken)+1,8)) < Date() //abgelaufen
         IF ! Empty(cList)
            cList +=  "<br>"
         ENDIF
         art->(dbSeek( Str(lag->Artikelnr,6) ))            
         cList += art->Matchcode+" "+Pad(DToC(StoD(SubStr(lag->Batch,Len(cExpToken)+1,8))),13)+" "+lag->Lagerort+" "+Transform(lag->Lagermenge,Me(art->Me))         
      ENDIF
         
      lag->(dbSkip())
   ENDDO

   IF ! Empty(cList)
      cMessage := "Folgende Artikel sind verstrichen:<br>"
      cMessage += "<pre>"+Pad("Artikel",25)+" "+Pad("Verfallsdatum",13)+" "+Pad("Lagerort",12)+" "+"Lagerbestand"+"<br>"
      cMessage += cList
      cMessage += "</pre>"

      cMessage += "<br>Bitte diese Artikel vernichten!"

      SendMessage("LAGER | Artikel mit verstrichenem Verfallsdatum","Artikel mit verstrichenem Verfallsdatum vernichten",cMessage)
   ENDIF