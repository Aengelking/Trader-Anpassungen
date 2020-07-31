#command @ <row>,<col> GET <var> CONTACTLIST;
      [VALID <valid>];
      [WHEN <when>];
      [COLOR <color>];
      [<noblank:NOBLANK>];
;
=> GET_Contact(getlist,<row>,<col>,{|v| If(v==NIL,<var>,<var>:=v)},<.noblank.>,<{valid}>, <{when}>,<color>)

PROC RUN_SEND_GB

LOCAL cKunde := Space(8)
LOCAL nJahr := Year(Date())
LOCAL dStart,dEnd,cQuartal := "1",nQuartal
LOCAL getlist := {}
LOCAL cFilter
LOCAL oArt
LOCAL aMonate
LOCAL nRecYear,nRecMonth,dRecDate,nPerson := 1
LOCAL cList := "",cText,hContact
LOCAL oRech
LOCAL cLang

NetUse("engkund","ku")
NetUse("englsre","re")
NetUse("artikel","art")
NetUse("artkund","aku")
NetUse("ups","ups")

Head(t("Gelangensbest‰tigung Monat versenden"))

DO WHILE .T.
   
   @ 01,00 SAY "Kunde"
   @ 01,10 GET cKunde PICTURE "@!" VALID FINDAD(cKunde,"K",01,40)
   @ 02,00 SAY "Quartal" 
   @ 02,10,08,13 GET cQuartal LISTBOX {"1","2","3","4"} DROPDOWN
   @ 03,00 SAY t("Person")
   @ 03,10 GET nPerson CONTACTLIST

   READ
   IF LastKey() == 27
      EXIT
   ENDIF

   hContact := GetContact(nPerson) //do this before the loop, otherwise we might have the wrong address
   cLang    := ku->Language

   IF cLang == "E"
      aMonate := {"January","February","March","April","May","June","July","August","September","October","November","December"}
   ELSE
      aMonate := {"Januar","Februar","MÑrz","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"}
   ENDIF

   nQuartal := Val(cQuartal)

   dStart := AddMonth(StoD(Str(nJahr,4)+"0101"),(nQuartal-1)*3)
   dEnd   := EoM(AddMonth(dStart,2))

   re->(dbSetOrder( 1 ))
   
   cFilter := "Reposnr != 0 .AND. rechdat >= StoD('"+DtoS(dStart)+"') .AND. rechdat <= Stod('"+DtoS(dEnd)+"') .AND. Preis*AoQty > 0 .AND. TaxCode == 3"
   re->(dbSetFilter({|| re->(&(cFilter)) },cFilter))
   re->(dbSeek(cKunde,.T.))   
   
   SetPos(3,0)
   cList := "<style>"
   cList +=  "table, th, td {"
   cList +=  " border: 1px solid black;"
   cList += "padding: 5px;"
   cList +=  "}"
   cList += "</style>"
   cList += "<table style='border-collapse: collapse;' border='1'><tr>"
   IF cLang == "E"
      cList += "<th>Invoice</th><th>Your order</th><th>Part</th><th>Qty</th><th>Received in</th><th>Place</th>"
   ELSE
      cList += "<th>Rechnung</th><th>Ihr Auftrag</th><th>Artikel</th><th>Menge</th><th>Erhalten im</th><th>Ort</th>"
   ENDIF
   cList += "</tr>"
   DO WHILE re->Kunde == cKunde
      oArt := Artikel():New()
      oArt:Load(re->Artikelnr)
      IF oArt:Lagerart
         oRech := Rechnung():New()
         oRech:Load(re->Rechnr)
         ups->(dbSetOrder(3))
         IF re->Packed .AND. ups->(dbSeek( Str(re->Rechnr,10) ))
            dRecDate := ups->Datum
         ELSE
            dRecDate := re->Rechdat
         ENDIF
         nRecYear := Year(re->Rechdat)
         IF Eom(dRecDate)-dRecDate > 2
            nRecMonth := Month(re->Rechdat)         
         ELSE
            nRecMonth := Month(AddMonth(re->Rechdat,1))
            IF nRecMonth == 1  //in diesem Fall kann es nur Januar bei Jahreswechsel sein!
               nRecYear++
            ENDIF
         ENDIF
         GotoRechnungsTaxCustomer(re->Kunde,re->Abnr,re->DelAd)
         
         ? re->Rechnr,re->Matchcode,Transform(re->AoQty,oArt:cPicture),oArt:Me,aMonate[nRecMonth]+" "+Str(nRecYear,4),IF(ku->CountryIso!="DE",ku->Town,"bitte einfÅllen")

         cList += "<tr>"
         cList += "<td>"+LTrim(Str(re->Rechnr))+"</td>"
         cList += "<td>"+Trim(re->Aufnr)+"</td>"
         cList += "<td>"+Trim(IF(oArt:PrMatch,re->Matchcode,IF(LEFT(re->matchcode,1) = "@",Pad(tx->(DispText(re->Textnr,0,0,80,1)),35),re->artikel) ))
         IF aku->(dbSeek( re->kunde+STR( re->artikelnr,6 )))
            cList += "<br>("
            IF cLang == "E"
               cList += "Your part"
            ELSE
               cList += "Ihr Artikel"
            ENDIF
            cList += ": "+Trim(aku->Artlief)+")"
         ENDIF
         cList += "</td>"         
         cList += "<td>"+Transform(re->AoQty,oArt:cPicture)+" "+IF(cLang=="E" .AND. oArt:Me == "STCK","pcs",oArt:Me)+"</td>"
         cList += "<td>"+aMonate[nRecMonth]+" "+Str(nRecYear,4)+"</td>"
         cList += "<td>"+IF(ku->CountryIso!="DE",Trim(ku->Town)+", "+GetCountryName(ku->CountryIso),"bitte einfÅllen")+"</td>"
         cList += "</tr>"
      ENDIF
      re->(dbSkip())
   ENDDO
   cList += "</table>"
   re->(dbClearFilter())   

   cText := hContact["anrede"] + ",<br/><br/>"
   IF cLang == "E"
      cText += "please confirm, by answering to this email, that you have received the deliveries according to the following list.<br><br/>"
      cText += cList+"<br><br>"
      cText += "Thank you for supporting us with this matter.<br><br>"
      
      cText += "Best Regards<br>"
   ELSE
      cText += "bitte bestÑtigen Sie uns, indem Sie auf diese Email antworten, dass Sie die unten stehenden Lieferungen entsprechend erhalten haben.<br><br/>"
      cText += cList+"<br><br>"
      cText += "Wir bedanken uns im Voraus fÅr Ihre UnterstÅtzung.<br><br>"
      
      cText += "Mit freundlichen GrÅ·en<br>"
   ENDIF
   cText += Buy(Tr_Getini(28),.T.)+"<br><br>"

   cText += "Engelking Elektronik GmbH<br>"
   cText += "Albstrasse 16<br>"
   cText += "D-78609 Tuningen<br>"
   cText += "Germany<br><br>"
   cText += "http://www.engelking.de<br><br>"
   cText += "eMail: info@engelking.de<br><br>"
   cText += "Tel: +49-(0)7464-9865-0<br>"
   cText += "Fax: +49-(0)7464-9865-71<br><br>"
   cText += "Amtsgericht Freiburg (HRB 602241)<br>"
   cText += "GeschÑftsfÅhrer: Amos Engelking, Hans-Peter Schwei·"

   OpenMailClient({{hContact["email"],hContact["name"]}},If(cLang=="E","Confirmation of delivery quarter ","GelangensbestÑtigung Quartal ")+Str(nQuartal,1)+"/"+Str(nJahr,4),cText,{})
ENDDO


