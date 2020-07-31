FUNCTION RUN_SHIP_NOTIFICATION( nRechnr )

LOCAL oExtra

LOCAL cEmail,aEnv := SaveEnv()
LOCAL nCount,cNumbers
LOCAL nWeight
LOCAL aAttach
LOCAL hContact

NetUse("paknum","pnum")
NetUse("ups","ups")
NetUse("englsre","re")
NetUse("engkund","ku")

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
cEmail += "soeben wurde eine Lieferung f&uuml;r Sie zum Versand angemeldet.</p>"
cEmail += "<p>Folgende Produkte/Bestellungen sind darin enthalten:<br />"
cEmail += '<table border="1"><tr><th align="left">Bestellung</th><th align="left">AB</th><th align="left">Artikel</th><th align="left">Menge</th></tr>'

re->(dbSkip())
DO WHILE re->Rechnr == nRechnr
   IF re->AoQty > 0 .AND. ! re->Folge
      cEmail += "<tr><td>"+Trim(re->Aufnr)+"</td><td>"+LTrim(Str(re->Abnr))+"</td><td>"+Trim(re->Matchcode)+"</td><td>"+Transform(re->AoQty,Me(re->Me))+" "+Trim(re->Me)+"</td></tr>"
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
   cEmail += t("<p>Die Sendung besteht aus "+LTrim(Str(nCount))+" Packstück"+IF(nCount>1,"en","")+" mit de"+IF(nCount>1,"n","r")+" folgenden Trackingnummer"+IF(nCount>1,"n","")+": "+cNumbers+"</p>")
   cEmail += t("<p>Das Gesamtgewicht der Sendung beträgt "+LTrim(Str(nWeight))+"kg</p>")
ENDIF

IF oExtra:ShpNtfyCst
   cEmail += "<p>Es werden Fracht- und Verpackungskosten von "+Currate(re->Money,"X")+" "+Trim(Str(re->OfQty,8,2))+" in Rechnung gestellt.</p>"
ENDIF

aAttach := {}
aFiles := GetArchiveFiles( {"LS"=>nRechnr} )
IF Len(aFiles) > 0
   cEmail += "<p>Im Anhang finden Sie eine Kopie des Lieferscheins"

   Aadd(aAttach,ATail(aFiles)[6])

   IF ku->TaxCode == 0 //nicht EG
      aFiles := GetArchiveFiles( {"RE"=>nRechnr} )
      IF Len(aFiles) > 0
         cEmail += " sowie der Rechnung"
         Aadd(aAttach,ATail(aFiles)[6])
      ENDIF
   ENDIF
   cEmail += ".</p>"
ENDIF


cEmail += "<p>Mit freundlichen Gr&uuml;&szlig;en<br /></p>"
cEmail += "<p><b>Engelking Elektronik GmbH</b><br />Albstrasse 16<br />78609 Tuningen<br />Deutschland<br />Tel: 07464-9865-0<br />Fax: 07464-9865-71"
cEmail += "<br />Email: info@engelking.de<br />Amtsgericht Freiburg (HRB 602241)<br />Gesch&auml;ftsf&uuml;hrer: Amos Engelking, Hans-Peter Schwei&szlig;</p>"

//cEmail := "To: "+hContact["email"]+"<br>"+cEmail
aTo := {}
IF ! Empty(hContact["email"])
   Aadd(aTo,{hContact["email"],hContact["name"]})
ELSE
   Aadd(aTo,{"samuel.engelking@engelking.de","Samuel Engelking"})
ENDIF
//Aadd(aTo,{"amos.engelking@engelking.de","Amos Engelking","BCC"})

SendMail(aTo,"Versandbenachrichtigung Lieferschein "+LTrim(Str(nRechnr)),cEmail,aAttach,.F.,NIL,.T.,"info@engelking.de")

RestEnv(aEnv,.F.)