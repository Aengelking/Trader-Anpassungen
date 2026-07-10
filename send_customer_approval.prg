FUNCTION Send_Customer_approval_Interface
   LOCAL oAuftrag := Auftrag():New()
   LOCAL nAbnr := 0,oExtra
   LOCAL getlist := {}

   Head("Preisfreigabe an Kunden senden")

   @ 01,00 SAY "AB Nr." GET nAbnr PICTURE "999999" VALID {||
      IF nAbnr <= 0
         RETURN .F.
      ENDIF      
      IF ! oAuftrag:Load(nAbNr)
         RETURN .F.
      ENDIF
      oExtra := auf->(ExtraData():New(nAbnr))
      IF ! oExtra:CUST_APR
         Tr_MsgBox("Keine Freigabe erforderlich")
         RETURN .F.
      ENDIF
      RETURN .T.
   }

   READ

   IF LastKey() == 27
      RETURN .F.
   ENDIF

   IF tr_MsgBox("Mitteilung zur Preis„nderung wirklich senden?",,{"Nein","Ja"}) != 2
      RETURN .F.
   ENDIF

   Run_Send_Customer_approval(oAuftrag)

RETURN .T.



FUNCTION Run_Send_Customer_approval(oAuftrag)
   LOCAL hContact := NIL
   LOCAL aTo := {}
   LOCAL cSubject := ""
   LOCAL cHtml := ""
   LOCAL hData := {=>}
   LOCAL hRetData := {=>}
   LOCAL cRows := ""
   LOCAL cPortalLink   
   LOCAL cDelDate,cReqDate,cReqPrice,cNewPrice,cCustArt,cArtNo,cQuantity
   LOCAL cLang
   LOCAL cServiceEmail
   LOCAL cRowsInfo := ""
   LOCAL oNote

   NetUse("artkund","aku")

   oAuftrag:Kunde:gotoRec()
   IF oAuftrag:Person == 0
      Tr_MsgBox("Kein Ansprechpartner hinterlegt")
      RETURN .F.
   ENDIF
   hContact := GetContact(oAuftrag:Person)   

   IF hContact != NIL .AND. ! Empty(Trim(hContact["email"]))
      Aadd(aTo,{Trim(hContact["email"]),hContact["name"]})
   ELSEIF ! Empty(Trim(oAuftrag:Kunde:Email))
      Aadd(aTo,{Trim(oAuftrag:Kunde:Email),Trim(oAuftrag:Kunde:Name1+" "+oAuftrag:Kunde:Name2)})
   ENDIF

   //Aadd(aTo,{"amos.engelking@engelking.de","Amos Engelking"})

   IF Len(aTo) == 0
      RETURN .F.
   ENDIF

   oAuftrag:Positions:Each({|oPos|
      IF oPos:ReqPr != 0 .AND. oPos:ReqPr != oPos:VkPr
         cArtNo := Trim(oPos:Matchcode) //LTrim(Str(oPos:Artikel:Artikelnr,6))
         cQuantity := LTrim(TransForm(oPos:VkQty,oPos:Artikel:cPicture))+" "+Trim(oPos:Artikel:Me)
         cCustArt := ""
         IF aku->(dbSeek(oAuftrag:Kundma+Str(oPos:Artikel:Artikelnr,6))) .AND. ! Empty(aku->Artlief)
         //IF Empty(cCustArt)
            //cCustArt := Trim(oPos:Artikel:Matchcode)
            cCustArt := Trim(aku->artlief)
         ENDIF
         cReqPrice := LTrim(Str(oPos:ReqPr/oPos:Pe,12,2))+" &euro;/St."
         cNewPrice := LTrim(Str(oPos:VkPr/oPos:Pe,12,2))+" &euro;/St."
         cReqDate := DToc(oPos:WDatum)
         cDelDate := IF(oAuftrag:Kunde:JustInTime,DToC(oPos:BDatum),NiceWeek(oPos:DTerm))
         //cShipWeek := NiceWeek(oPos:WTerm)

         cRows += "<tr>"
         cRows += "<td>"+cArtNo+"</td>"
         cRows += "<td>"+cCustArt+"</td>"
         cRows += "<td>"+cQuantity+"</td>"
         cRows += "<td>"+cReqPrice+"</td>"
         cRows += "<td>"+cNewPrice+"</td>"
         cRows += "<td>"+cReqDate+"</td>"
         cRows += "<td>"+cDelDate+"</td>"
         cRows += "</tr>"
         
         cRowsInfo += cCustArt+" "
         cRowsInfo += StrTran(cReqPrice,"&euro;","EUR")+"=>"
         cRowsInfo += StrTran(cNewPrice,"&euro;","EUR")+" "+Chr(13)+Chr(10)
      ENDIF
      RETURN NIL
   })

   IF Empty(cRows)
      RETURN .F.
   ENDIF

   cPortalLink := "https://portal.engelking.com/en/orders/"+LTrim(Str(oAuftrag:AbNr,6))
   IF Empty(cPortalLink)
      cPortalLink := "#"
   ENDIF

   cServiceEmail := GetConfigValue("EMAIL-FROM_SALESORDER")
   IF Empty(cServiceEmail)
      cServiceEmail := GetUserEmail(oAuftrag:Buyer)
   ENDIF

   cLang := IF(Empty(oAuftrag:Kunde:Language),"D",oAuftrag:Kunde:Language)

   hData["nr"] := LTrim(Str(oAuftrag:AbNr,6))
   hData["kunr"] := Trim(oAuftrag:Aufnr)
   hData["rows"] := cRows
   hData["portal_link"] := cPortalLink
   hData["service_email"] := cServiceEmail

   LoadEmailTemplate("cust_apr",cLang,@cSubject,@cHtml,hContact,hData,@hRetData,"UTF-8")
   IF Empty(cSubject)
      cSubject := "Mitteilung zur Preis„nderung"
   ENDIF
   IF Empty(cHtml)
      RETURN .F.
   ENDIF
   
   cHtml := LoadEmailConfigFile("header")+cHtml+LoadEmailConfigFile("footer")

   SendMail(aTo,cSubject,cHtml,{ },.F.,0,.T.,cServiceEmail,.F.,.F.)

   oNote := nts->(Record():New(.T.))
   oNote:SetId("ID",4)
   oNote:Nummer := oAuftrag:AbNr
   oNote:Betreff := "AUF"
   oNote:Date := Date()
   oNote:Time := Left(Time(),5)
   oNote:Type := "NOTE"
   oNote:Person := oAuftrag:Person
   oNote:Buyer := SystemUser():Id
   oNote:Note := "Preis„nderungen an Kunden versendet"+Chr(13)+Chr(10)+cRowsInfo
   oNote:Save()

   AddWiedervorlage(AddWorkingDays(Date(),2,GetConfigValue("STATE")),"Wiedervorlage Preis„nderung AB "+LTrim(Str(oAuftrag:AbNr)),cRows,"")


RETURN .T.
