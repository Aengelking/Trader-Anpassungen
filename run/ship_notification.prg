
FUNCTION RUN_SHIP_NOTIFICATION( nRechnr )

LOCAL oExtra,oArtExtra

LOCAL cEmail,aEnv := SaveEnv()
LOCAL nCount,cNumbers
LOCAL aFiles
LOCAL nWeight
LOCAL aAttach
LOCAL hContact
LOCAL hCoc := {=>},aBatches,cBatch
LOCAL lAttach := .F.
LOCAL aTo := {}
LOCAL aAbs := {},aContacts := {}
LOCAL cAnrede,lHasContact := .F.
LOCAL nVersandart := 0,cForwarder
LOCAL lIsUPS := .F.,cTrackLink

NetUse("paknum","pnum")
NetUse("ups","ups")
NetUse("englsre","re")
NetUse("engkund","ku")
NetUSe("artikel","art")
NetUse("auftrag","ab")

IF Tr_Getini(28) == 9 .AND. Tr_MsgBox("Versandbenachrichtigung wirklich senden?",,{"Nein","Ja"}) != 2
   RestEnv(aEnv,.F.)
   RETURN .F.
ENDIF

re->(dbSetOrder( 12 ))
IF ! re->(dbSeek( Str(nRechnr,6)+Str(0,3) ))  .OR. re->PosWt <= 0
   RestEnv(aEnv,.F.)
   RETURN NIL
ENDIF

ups->(dbSetOrder( 3 ))
IF ups->(dbSeek( Str(nRechnr,10) )) 
   nVersandart :=  ups->Versandart
ENDIF

IF nVersandart == 21 //Kein Warenversand
   RestEnv(aEnv,.F.)
   RETURN NIL
ENDIF

ku->(dbSetOrder( 1 ))
ku->(dbSeek( re->Kunde+"K" ))

oExtra := ku->(ExtraData():New( ku->Nummer ))

cAnrede := ""
IF oExtra:ShpNtfyTo != 0
   hContact := GetContact(oExtra:ShpNtfyTo)
   IF ! Empty(hContact["email"])
      lHasContact := .T.
      cAnrede := hContact["anrede"]+","
      Aadd(aTo,{hContact["email"],hContact["name"]})
   ENDIF  
ENDIF

cEmail := ""
cEmail += "<p>"
IF nVersandart $ {2,19,34,43,46,56}
   cForwarder := "UPS"
   lIsUPS := .T.
ELSEIF nVersandart == 40
   cForwarder := "Emons"
ELSEIF nVersandart == 58
   cForwarder := "DB Schenker"
ELSE
   cForwarder := ""
ENDIF
IF ku->Language == "D"
   IF nVersandart == 10 //Abholung
      cEmail += "soeben wurde eine Sendung von Ihrem Dienstleister abgeholt.</p>"
   ELSE      
      cEmail += "soeben wurde eine Lieferung f&uuml;r Sie zum Versand"
      IF ! Empty(cForwarder)
         cEmail += " mit "+cForwarder
      ENDIF
      cEmail += " angemeldet.</p>"
   ENDIF
   cEmail += "<p>Folgende Produkte/Bestellungen sind darin enthalten:<br />"
   cEmail += '<table border="1"><tr><th align="left">Bestellung</th><th align="left">AB</th><th align="left">Artikel</th><th align="left">Menge</th></tr>'
ELSE
   IF nVersandart == 10
      cEmail += "A shipment has been collected by your forwarder.</p>"
   ELSE
      
      cEmail += "A shipment has been registered with "
      IF ! Empty(cForwarder)
         cEmail += cForwarder         
      ELSE
         cEmail += "the forwarder"
      ENDIF
      cEmail += ".</p>"
   ENDIF
   cEmail += "<p>It contains the following products and pruchase orders:<br />"
   cEmail += '<table border="1"><tr><th align="left">PO</th><th align="left">OC</th><th align="left">Part</th><th align="left">Quantity</th></tr>'
ENDIF

re->(dbSkip())
DO WHILE re->Rechnr == nRechnr
   IF re->AoQty > 0 .AND. ! re->Folge
      IF ! lHasContact .AND. ! re->Abnr $ aAbs
         Aadd(aAbs,re->Abnr)
         IF ab->(dbSeek( Str(re->Abnr,6) )) .AND. ! ab->Person $ aContacts .AND. ab->Person != 0
            Aadd(aContacts,ab->Person)
            hContact := GetContact(ab->Person)
            ? hContact["name"]
            IF ! Empty(hContact["email"])
               IF Len(aContacts) > 1
                  cAnrede += "<br>"
               ENDIF
               cAnrede += hContact["anrede"]+","
            
               Aadd(aTo,{hContact["email"],hContact["name"]})
               
            ENDIF
         ENDIF
      ENDIF
      oArtExtra := art->(ExtraData():New(re->Artikelnr))
      cEmail += "<tr><td>"+Trim(re->Aufnr)+"</td><td>"+LTrim(Str(re->Abnr))+"</td><td>"+Trim(re->Matchcode)+"</td><td>"+Transform(re->AoQty,Me(re->Me))+" "+Trim(re->Me)+"</td></tr>"      
      IF GetConfigValue("FIRMNO") == 1 .AND. oArtExtra:CoC
         IF ! re->Artikelnr $ hCoc
            hCoc[re->Artikelnr] := {}
         ENDIF
         NetUse("lagrech","lagr",.F.,0)
         lagr->(dbSeek(STR(re->Rechnr,6)+STR(re->rePosNr,3)+STR(re->AbNr,6)))
         DO WHILE lagr->RechNr == re->Rechnr .AND. lagr->RePosNr == re->RePosNr.AND. lagr->ABNR == re->AbNr         
            IF ! Trim(lagr->Batch) $ hCoc[re->Artikelnr] .AND. ! Empty(lagr->Batch)
               Aadd(hCoc[re->Artikelnr],Trim(lagr->Batch))
            ENDIF
            lagr->(DBSKIP())
         ENDDO
      ENDIF
   ENDIF
   re->(dbSkip())
ENDDO

cEmail += "</table></p>"

IF Len(aTo) == 0
   cAnrede := GetContactAnrede(0)+","
   IF ! Empty(ku->Email)
      Aadd(aTo,{Trim(ku->Email),""})
   ENDIF
ENDIF

cEmail := cAnrede+cEmail

re->(dbSeek( Str(nRechnr,6)+Str(0,3) ))

IF nVersandart $ {2,19,34,40,43,46,56,58}
   pnum->(dbSetOrder( 1 ))
   pnum->(dbSeek( ups->Nr ))
   nCount := 0
   cNumbers := ""
   
   cTrackLink := "https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums="
   
   nWeight := 0
   DO WHILE pnum->Nr == ups->Nr
      nCount ++
      IF nCount > 1
         cNumbers += ","
         cTrackLink += "%20"
      ENDIF
      cNumbers += Trim(pnum->Nummer)
      cTrackLink += Trim(pnum->Nummer)
      nWeight += pnum->Weight
      pnum->(dbSkip())
   ENDDO
   
   IF ku->Language == "D"
      cEmail += t("<p>Die Sendung besteht aus "+LTrim(Str(nCount))+" Packst¸ck"+IF(nCount>1,"en","")+" mit de"+IF(nCount>1,"n","r")+" folgenden Trackingnummer"+IF(nCount>1,"n","")+": ")
      IF lIsUPS
         cEmail += '<a href="'+cTrackLink+'">'
      ENDIF
      cEmail += cNumbers
      IF lIsUPS
         cEmail += '</a>'
      ENDIF
      cEmail += "<br>"
      cEmail += t("Die Sendungungsverfolgung wird nach Abholung Ihrer Sendung verfÅgbar sein.</p>")      
      cEmail += t("<p>Das Gesamtgewicht der Sendung betr‰gt "+LTrim(Str(nWeight))+"kg</p>")
   ELSE
      cEmail += t("<p>The shipment consists of "+LTrim(Str(nCount))+" package"+IF(nCount>1,"s","")+" with the following tracking number"+IF(nCount>1,"s","")+": ")
      IF lIsUPS
         cEmail += '<a href="'+cTrackLink+'">'
      ENDIF
      cEmail += cNumbers
      IF lIsUPS
         cEmail += '</a>'
      ENDIF
      cEmail += "<br>"
      cEmail += t("<p>The total weight of the shipment is "+LTrim(Str(nWeight))+"kg</p>")
   ENDIF
ENDIF

IF oExtra:ShpNtfyCst
   IF ku->Language == "D"
      cEmail += "<p>Es werden Fracht- und Verpackungskosten von "+Currate(re->Money,"X")+" "+Trim(Str(re->OfQty,8,2))+" in Rechnung gestellt.</p>"
   ELSE
      cEmail += "<p>"+Currate(re->Money,"X")+" "+Trim(Str(re->OfQty,8,2))+" of freight and packaging costs have been charged.</p>"
   ENDIF
ENDIF

aAttach := {}
aFiles := GetArchiveFiles( {"LS"=>nRechnr} )
IF Len(aFiles) > 0
   lAttach := .T.
   IF ku->Language == "D"
      cEmail += "<p>Im Anhang finden Sie eine Kopie des Lieferscheins"
   ELSE
      cEmail += "<p>You will find the delivery note attached."
   ENDIF

   Aadd(aAttach,ATail(aFiles)[6])

   IF ku->TaxCode == 0 //nicht EG
      aFiles := GetArchiveFiles( {"RE"=>nRechnr} )
      IF Len(aFiles) > 0
         cEmail += " sowie der Rechnung"
         Aadd(aAttach,ATail(aFiles)[6])
      ENDIF
   ENDIF
   
ENDIF

IF Len(hCoC) > 0
   IF lAttach
      IF ku->Language == "D"
         cEmail += " und die dazu "
      ELSE
         cEmail += " and "
      ENDIF
   ELSE    
      IF ku->Language == "D"     
         cEmail += "<p>Im Anhang finden Sie die zu dieser Lieferung "
      ELSE
         cEmail += "<p>Attached you will find "
      ENDIF
   ENDIF
   IF ku->Language == "D"
      cEmail += "gehîrige(n) Werksbescheinigung(en)"
   ELSE
      cEmail += " the corresponding Certificate(s) of Conformity"
   ENDIF

   FOR EACH aBatches IN hCoC
      FOR EACH cBatch IN aBatches
         aFiles := GetArchiveFiles( {"COC"=>cBatch} )
         IF Len(aFiles) > 0
            Aadd(aAttach,ATail(aFiles)[6])
         ELSE
            //cEmail += cBatch+" fehlt<br>"
         ENDIF
      NEXT
   NEXT
ENDIF

IF lAttach
   cEmail += ".</p>"
ENDIF

IF ku->Language == "D"
   cEmail += "<p>Mit freundlichen Gr&uuml;&szlig;en<br /></p>"
ELSE
   cEmail += "<p>Best Regards<br /></p>"
ENDIF
//cEmail += "<p><b>Engelking Elektronik GmbH</b><br />Albstrasse 16<br />78609 Tuningen<br />Deutschland<br />Tel: 07464-9865-0<br />Fax: 07464-9865-71"
//cEmail += "<br />Email: info@engelking.de<br />Amtsgericht Freiburg (HRB 602241)<br />Gesch&auml;ftsf&uuml;hrer: Amos Engelking, Hans-Peter Schwei&szlig;</p>"

cEmail := LoadEmailConfigFile("header")+cEmail+LoadEmailConfigFile("footer")

IF Len(aTo) == 0
   Aadd(aTo,{"amos.engelking@engelking.de","Amos Engelking","TO"})
ENDIF
//Aadd(aTo,{"amos.engelking@engelking.de","Amos Engelking","BCC"})


SendMail(aTo,IF(ku->Language=="D","Versandbenachrichtigung Lieferschein ","Advance Shipment Notification ")+LTrim(Str(nRechnr)),cEmail,aAttach,.F.,NIL,.T.,"info@engelking.de")

RestEnv(aEnv,.F.)