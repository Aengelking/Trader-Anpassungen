#define CRLF "<br />"
PROC RUN_PSZ_CHECK
LOCAL nGrad,hContact
LOCAL oExtra,cText
LOCAL cCustomer
LOCAL nFrQty, nRahmenQty
LOCAL nCheckYears := 4
LOCAL cFilter,cFilter2,nRec
LOCAL aTo,oUser,aToTeam
LOCAL nCount := 0
LOCAL nIndex,cSubject

LOCAL lNeuerRahmen, cNewText

NetUse("engauf","auf")
NetUse("engkund","ku")
NetUse("fremdab","frab")
NetUse("erschoepf","er")
NetUse("artikel","art")


auf->(dbSetOrder( 2 ))

cFilter := 'Right(Str(DTerm,4),2) == "99" .AND. Besda >= StoD("'+DtoS(Date()-365*nCheckYears)+'")'
auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter))
auf->(dbGoTop())

DO WHILE ! auf->(EOF())
   CLS

   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( auf->Kundma+"K" ))
   oExtra := ku->(ExtraData():New(ku->Nummer))
   //cCustomer := Trim(ku->Kunde) //hCustomer["MATCH"]
   cCustomer := Trim(auf->Kundma)
   nGrad     := oExtra:AufGrad //hCustomer["GRAD"]
   ku->(dbSetOrder( 1 ))
   ? cCustomer
   IF oExtra:AufGrad != 0 //Wenn der Grad wirklich gesetzt ist, dieser kann auch kleiner als 0 fÅr SonderfÑlle sein
      ? auf->Abnr,auf->Besda
      IF ! er->(dbSeek( Str(auf->Abnr,6) ))
         IF auf->Besda >= Date()-365*nCheckYears .AND. auf->Besda >= oExtra:AufErAb
            IF oExtra:AufGrad == -1 //Grad wird anhand der Lieferzeit des Artikels berechnet
               art->(dbSetOrder( 2 ))
               art->(dbSeek( Str(auf->Artikelnr,6) ))
               nGrad := (1-((art->lz+1)*1.5)/52)*100  //50% auf die Lieferzeit, dann durch 52 Wochen geteilt
            ENDIF
            ? auf->Abnr
            nFrQty := 0
            IF frab->(dbSeek( Str(auf->AbNr,6)+Str(auf->Itmnr,3) ))
               nFrQty := frab->Qty
            ENDIF
            nRahmenQty := auf->ContrQty + nFrQty
            ?? auf->VkQty,auf->GelQty,nFrQty,auf->VkQty-auf->GelQty-nFrQty , (nRahmenQty)*(1-nGrad/100)
            IF  nRahmenQty > 0 .AND. auf->VkQty-auf->GelQty <= nRahmenQty*(1-nGrad/100)  //ohne Rahmenmenge lÑsst sich kein Erschîpfungsgrad berechnen (Division durch 0)
               //Check to see if there is a newer frame contract for this part

               nRec := auf->(Recno())
               cFilter2 := cFilter+" .AND. Besda > StoD('"+DtoS(auf->Besda)+"')"
               auf->(dbSetOrder( 6 ))
               auf->(dbSetFilter( {|| auf->(&(cFilter2)) },cFilter2))
               IF auf->(dbSeek( Pad(cCustomer,8)+auf->Matchcode ))
                  //cText += cFilter2+"<br/>"
                  cNewText := "Es wurde bereits ein neuer Rahmen Åber "+Transform(auf->ContrQty,Me(art->Me))+" "+Trim(art->Me)+" (AB "+LTrim(Str(auf->Abnr))+") am "+DtoC(auf->Besda)+" angelegt.<br/><br/>"
                  lNeuerRahmen := .T.                        
               ELSE                               
                  lNeuerRahmen := .F.
               ENDIF
               auf->(dbSetOrder( 2 ))
               auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter))
               auf->(dbGoto(nRec))                 


               IF ! lNeuerRahmen 
                  IF oExtra:AufErschoE != 0 //EmpfÑnger ist gesetzt
                     hContact  := GetContact(oExtra:AufErschoe)
                     art->(dbSetOrder( 2 ))
                     art->(dbSeek( Str(auf->Artikelnr,6) ))
                     
                     cText := hContact["anrede"]+",<br/><br/>"
                     cText += "Ihr o.g. Auftrag ist zu "+LTrim(Str( (1-(auf->VkQty-auf->GelQty)/(nRahmenQty))*100,3,0))+"% erschîpft."
                     cText += " Es wurden "+Transform(auf->ContrQty-auf->VkQty+nFrQty+auf->GelQty,Me(art->Me))+" der "+Transform(nRahmenQty,Me(art->Me))+" "+Trim(art->Me)+" abgerufen.<br/><br/>"

                     cText += "Bitte prÅfen Sie ob ein neuer Rahmen notwendig ist.<br/><br/>"

                     cText += "Mit freundlichen GrÅ·en<br/><br/>"
                     cText += "<b>Engelking Elektronik GmbH</b><br/>"
                     cText += "Albstrasse 16<br/>"
                     cText += "78609 Tuningen<br/>"
                     cText += "Germany<br/>"
                     cText += "http://www.engelking.de<br/>"
                     cText += "eMail: info@engelking.de<br/>"
                     cText += "Tel: +49-(0)7464-9865-0<br/>"
                     cText += "Fax: +49-(0)7464-9865-71<br/><br/>"
                     cText += "Amtsgericht Freiburg (HRB 602241)<br/>"
                     cText += "GeschÑftsfÅhrer: Amos Engelking<br/>"

                     
                     aTo := {{hContact["email"],hContact["name"]}}

                     
                     cSubject := "Ihr Auftrag "+Trim(auf->Aufnr)+" (AB "+LTrim(Str(auf->Abnr))+"/"+LTrim(Str(auf->Itmnr))+")"

                     
                  ELSE
                     //Reine interne Mitteilung 
                     cText := "Der Auftrag "+Trim(auf->Aufnr)+" von Kunde "+Trim(ku->Kunde)+" ist zu "+LTrim(Str( (1-(auf->VkQty-auf->GelQty)/(nRahmenQty))*100,3,0))+"% erschîpft.<br/><br/>"
                     cText += "AB: "+LTrim(Str(auf->Abnr))+"/"+LTrim(Str(auf->Itmnr))+"<br/>"
                     cText += "Datum: "+DtoC(auf->Besda)+"<br/>"
                     cText += "Artikel: "+auf->Matchcode+"<br/>"
                     cText += "Menge: "+Transform(auf->ContrQty-auf->VkQty+nFrQty+auf->GelQty,Me(art->Me))+" von "+Transform(nRahmenQty,Me(art->Me))+" "+Trim(art->Me)+" abgerufen<br/><br/>"
                     cText += "Laufzeit: "+DtoC(auf->SDatum)+" - "+DToC(CalWD(auf->WTerm)+4)+"<br/><br/>"

                     IF lNeuerRahmen
                        cText += cNewText
                     ENDIF

                     cText += " Bitte prÅfe ob ein neuer Rahmen notwendig ist."                  
                     
                     

                     cSubject := "Erschîpfungsgrad von Auftrag "+Trim(auf->Aufnr)+" (AB "+LTrim(Str(auf->Abnr))+"/"+LTrim(Str(auf->Itmnr))+")"
                     aTo := {}
                  ENDIF

                  oUser := User():New()
                  oUser:Load(auf->Buyer)

                  //User hinzufÅgen, als CC falls an Kunden
                  Aadd(aTo,{Trim(oUser:Email),Trim(oUser:Name),IF(Len(aTo)>0,"CC","TO")})         

                  IF ku->Team != 0
                     aToTeam := GetTeamEmails(ku->Team)
                  ELSE
                     aToTeam := {}
                  ENDIF
                        
                  //Team als CC hinzufÅgen
                  FOR nIndex := 1 TO Len(aToTeam)
                     IF Trim(aToTeam[nIndex,1]) != Trim(oUser:Email)
                        Aadd(aTo,{aToTeam[nIndex,1],aToTeam[nIndex,2], "CC"})                          
                     ENDIF
                  NEXT                     
                  IF oExtra:AufErschoE != 0      //bei externen mich in BCC, bei internen Mitteilungen nicht, damit ich das Åberwachen kann
                     Aadd(aTo,{"amos.engelking@engelking.de","Amos","BCC"})
                  ENDIF
                  IF ku->Rep != 0
                     Aadd(aTo,{RepGetEmail(ku->Rep),RepGetName(ku->Rep),"CC"})
                  ENDIF

                  SendMail(aTo,cSubject,cText,,,,.T.,"info@engelking.de")
                  nCount++

               ENDIF

               


               er->(Add_Rec())
               er->Aufnr := auf->Abnr
               er->Date := Date()
               er->(dbUnLock())
               
            ENDIF
         ENDIF
      ENDIF         
   ENDIF
   auf->(dbSkip())
   IF nCount == 5  //for testing purposes only send one email
      EXIT
   ENDIF
//NEXT
ENDDO

auf->(dbClearFilter())
IF ! getConfigValue("BATCHMODE")
   SInkey(0)
ENDIF
/*IF ! MemoWrit(Trim(Tr_getini(1))+"\run\erschoepf.ch",ValToPrg(aExclude))
   Throw(Error(,,,,"Could not save erschoepf.ch"))
ENDIF */