
FUNCTION RUN_SHIP_NOTIFICATION( nRechnr )

LOCAL oExtra,oArtExtra,aTo

LOCAL cEmail,aEnv := SaveEnv()
LOCAL nCount,cNumbers
LOCAL aFiles
LOCAL nWeight
LOCAL aAttach
LOCAL hContact
LOCAL hCoc := {=>},aBatches,cBatch
LOCAL lAttach := .F.

NetUse("paknum","pnum")
NetUse("ups","ups")
NetUse("englsre","re")
NetUse("engkund","ku")
NetUSe("artikel","art")

re->(dbSetOrder( 12 ))
IF ! re->(dbSeek( Str(nRechnr,6)+Str(0,3) ))  .OR. re->PosWt <= 0
   RestEnv(aEnv,.F.)
   RETURN NIL
ENDIF

ku->(dbSetOrder( 1 ))
ku->(dbSeek( re->Kunde+"K" ))

oExtra := ku->(ExtraData():New( ku->Nummer ))

IF oExtra:ShpNtfyTo != 0
   hContact := GetContact(oExtra:ShpNtfyTo)
ELSE
   hContact := {"anrede"=>GetContactAnrede(0),"email"=>Trim(ku->Email),"name"=>""}
ENDIF

cEmail := hContact["anrede"]+","
cEmail += "<p>"
IF ku->Language == "D"
   cEmail += "soeben wurde eine Lieferung f&uuml;r Sie zum Versand angemeldet.</p>"
   cEmail += "<p>Folgende Produkte/Bestellungen sind darin enthalten:<br />"
   cEmail += '<table border="1"><tr><th align="left">Bestellung</th><th align="left">AB</th><th align="left">Artikel</th><th align="left">Menge</th></tr>'
ELSE
   cEmail += "A shipment has been registered with the forwarder.</p>"
   cEmail += "<p>FIt contains the following products and pruchase orders:<br />"
   cEmail += '<table border="1"><tr><th align="left">PO</th><th align="left">OC</th><th align="left">Part</th><th align="left">Quantity</th></tr>'
ENDIF

re->(dbSkip())
DO WHILE re->Rechnr == nRechnr
   IF re->AoQty > 0 .AND. ! re->Folge
      oArtExtra := art->(ExtraData():New(re->Artikelnr))
      cEmail += "<tr><td>"+Trim(re->Aufnr)+"</td><td>"+LTrim(Str(re->Abnr))+"</td><td>"+Trim(re->Matchcode)+"</td><td>"+Transform(re->AoQty,Me(re->Me))+" "+Trim(re->Me)+"</td></tr>"      
      IF oArtExtra:CoC
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

re->(dbSeek( Str(nRechnr,6)+Str(0,3) ))

ups->(dbSetOrder( 3 ))
IF ups->(dbSeek( Str(nRechnr,10) )) .AND. ups->Versandart $ {2,19,34,40,43,46,56,58}
   pnum->(dbSetOrder( 1 ))
   pnum->(dbSeek( ups->Nr ))
   nCount := 0
   cNumbers := ""
   nWeight := 0
   DO WHILE pnum->Nr == ups->Nr
      nCount ++
      IF nCount > 1
         cNumbers += ","
      ENDIF
      cNumbers += Trim(pnum->Nummer)
      nWeight += pnum->Weight
      pnum->(dbSkip())
   ENDDO
   IF ku->Langauge == "D"
      cEmail += t("<p>Die Sendung besteht aus "+LTrim(Str(nCount))+" Packstück"+IF(nCount>1,"en","")+" mit de"+IF(nCount>1,"n","r")+" folgenden Trackingnummer"+IF(nCount>1,"n","")+": "+cNumbers+"</p>")
      cEmail += t("<p>Das Gesamtgewicht der Sendung beträgt "+LTrim(Str(nWeight))+"kg</p>")
   ELSE
      cEmail += t("<p>The shipment consists of "+LTrim(Str(nCount))+" packages"+IF(nCount>1,"en","")+" with the following tracking number"+IF(nCount>1,"s","")+": "+cNumbers+"</p>")
      cEmail += t("<p>The total weight of the shipment is "+LTrim(Str(nWeight))+"kg</p>")
   ENDIF
ENDIF

IF oExtra:ShpNtfyCst
   IF ku->Langauge == "D"
      cEmail += "<p>Es werden Fracht- und Verpackungskosten von "+Currate(re->Money,"X")+" "+Trim(Str(re->OfQty,8,2))+" in Rechnung gestellt.</p>"
   ELSE
      cEmail += "<p>"+Currate(re->Money,"X")+" "+Trim(Str(re->OfQty,8,2))+" of freight and packaging costs have been charged.</p>"
   ENDIF
ENDIF

aAttach := {}
aFiles := GetArchiveFiles( {"LS"=>nRechnr} )
IF Len(aFiles) > 0
   lAttach := .T.
   IF ku->Langauge == "D"
      cEmail += "<p>Im Anhang finden Sie eine Kopie des Lieferscheins"
   ELSE
      cEmail += "<p>Attached you will find the delivery note"
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
      IF ku->Langauge == "D"
         cEmail += " und die dazu "
      ELSE
         cEmail += " and "
      ENDIF
   ELSE    
      IF ku->Langauge == "D"     
         cEmail += "<p>Im Anhang finden Sie die zu dieser Lieferung "
      ELSE
         cEmail += "<p>Attached you will find "
      ENDIF
   ENDIF
   IF ku->Langauge == "D"
      cEmail += "geh”rige(n) Werksbescheinigung(en)"
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

IF ku->Langauge == "D"
   cEmail += "<p>Mit freundlichen Gr&uuml;&szlig;en<br /></p>"
ELSE
   cEmail += "<p>Best Regards<br /></p>"
ENDIF
cEmail += "<p><b>Engelking Elektronik GmbH</b><br />Albstrasse 16<br />78609 Tuningen<br />Deutschland<br />Tel: 07464-9865-0<br />Fax: 07464-9865-71"
cEmail += "<br />Email: info@engelking.de<br />Amtsgericht Freiburg (HRB 602241)<br />Gesch&auml;ftsf&uuml;hrer: Amos Engelking, Hans-Peter Schwei&szlig;</p>"

//cEmail := "To: "+hContact["email"]+"<br>"+cEmail
aTo := {}
IF ! Empty(hContact["email"])
   Aadd(aTo,{hContact["email"],hContact["name"]})
   //Aadd(aTo,{"amos.engelking@engelking.de","Amos Engelking"})
ELSE
   Aadd(aTo,{"samuel.engelking@engelking.de","Samuel Engelking"})
ENDIF
Aadd(aTo,{"amos.engelking@engelking.de","Amos Engelking","BCC"})

SendMail(aTo,IF(ku->Language=="D","Versandbenachrichtigung Lieferschein ","Advance Shipment Notification ")+LTrim(Str(nRechnr)),cEmail,aAttach,.F.,NIL,.T.,"info@engelking.de")

RestEnv(aEnv,.F.)