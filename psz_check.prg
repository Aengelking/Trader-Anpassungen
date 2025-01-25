#define CRLF "<br />"
PROC RUN_PSZ_CHECK
LOCAL nGrad,hContact
LOCAL aCustomers,oExtra,cText
LOCAL nKdId
LOCAL cCustomer
LOCAL nFrQty
LOCAL nCheckYears := 4

NetUse("engauf","auf")
NetUse("engkund","ku")
NetUse("fremdab","frab")
NetUse("erschoepf","er")
NetUse("artikel","art")


auf->(dbSetOrder( 2 ))

auf->(dbSetFilter({|| Right(Str(auf->DTerm,4),2) == "99" .AND. auf->Besda >= Date()-365*nCheckYears },'Right(Str(DTerm,4),2) == "99" .AND. Besda >= StoD("'+DtoS(Date()-365*nCheckYears)+'")'))

CLS

aCustomers := GetIdsWithExtraField("KU","AUFGRAD")  //alle Kunden mit einem gesetzten Ersch”pfungsgrad (kann aber auch 0 sein)

FOR EACH nKdId IN aCustomers
   ? nKdId
   ku->(dbSetOrder( 8 ))
   ku->(dbSeek( Str(nKdId,6) ))
   oExtra := ku->(ExtraData():New(ku->Nummer))
   cCustomer := Trim(ku->Kunde) //hCustomer["MATCH"]
   nGrad     := oExtra:AufGrad //hCustomer["GRAD"]
   ku->(dbSetOrder( 1 ))
   ? cCustomer
   IF oExtra:AufGrad != 0 //Wenn der Grad wirklich gesetzt ist, dieser kann auch kleiner als 0 fr Sonderf„lle sein
      hContact  := GetContact(oExtra:AufErschoe) //hCustomer["CONTACT"])
      auf->(dbSeek( Pad(cCustomer,8)+Str(0,1) ))
      DO WHILE Trim(auf->Kundma) == cCustomer  /*.AND. auf->Bestat == 0*/ //cannot exclude ones with bestat == 0 then it will not warn when all is used up immediatally
         ? auf->Abnr,auf->Besda
         IF ! er->(dbSeek( Str(auf->Abnr,6) ))
            IF auf->Besda >= Date()-365*nCheckYears
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
               ?? auf->VkQty,auf->GelQty,nFrQty,auf->VkQty-auf->GelQty-nFrQty , (auf->ContrQty+nFrQty)*(1-nGrad/100)
               IF  auf->VkQty-auf->GelQty <= (auf->ContrQty+nFrQty)*(1-nGrad/100)
                  art->(dbSetOrder( 2 ))
                  art->(dbSeek( Str(auf->Artikelnr,6) ))
                  cText := hContact["anrede"]+",<br/><br/>"
                  cText += "Ihr o.g. Auftrag ist zu "+LTrim(Str( (1-(auf->VkQty-auf->GelQty)/(auf->ContrQty+nFrQty))*100,3,0))+"% erschöpft."
                  cText += " Es wurden "+Transform(auf->ContrQty-auf->VkQty+nFrQty+auf->GelQty,Me(art->Me))+" der "+Transform(auf->ContrQty+nFrQty,Me(art->Me))+" "+Trim(art->Me)+" abgerufen.<br/><br/>"
                  cText += "Bitte prüfen Sie ob ein neuer Rahmen notwendig ist.<br/><br/>"
                  cText += "Mit freundlichen Grüßen<br/><br/>"
                  cText += "<b>Engelking Elektronik GmbH</b><br/>"
                  cText += "Albstrasse 16<br/>"
                  cText += "78609 Tuningen<br/>"
                  cText += "Germany<br/>"
                  cText += "http://www.engelking.de<br/>"
                  cText += "eMail: info@engelking.de<br/>"
                  cText += "Tel: +49-(0)7464-9865-0<br/>"
                  cText += "Fax: +49-(0)7464-9865-71<br/><br/>"
                  cText += "Amtsgericht Freiburg (HRB 602241)<br/>"
                  cText += "Geschäftsführer: Amos Engelking<br/>"

//                  SendMail({{hContact["email"],hContact["name"]},{"amos.engelking@engelking.de","Amos","BCC"}},HB_AnsiToOem("Auftrag "+Trim(auf->Aufnr)+" (AB "+LTrim(Str(auf->Abnr))+"/"+LTrim(Str(auf->Itmnr))+")"),HB_AnsiToOem(cText),,,,.T.,"info@engelking.de")
                  SendMail({{"amos.engelking@engelking.de","Amos"}},HB_AnsiToOem("Auftrag "+Trim(auf->Aufnr)+" (AB "+LTrim(Str(auf->Abnr))+"/"+LTrim(Str(auf->Itmnr))+")"),HB_AnsiToOem(cText),,,,.T.,"info@engelking.de")

                  er->(Add_Rec())
                  er->Aufnr := auf->Abnr
                  er->Date := Date()
                  er->(dbUnLock())
               ENDIF
            ENDIF
         ENDIF
         auf->(dbSkip())
      ENDDO
   ENDIF
NEXT

auf->(dbClearFilter())
IF ! getConfigValue("BATCHMODE")
   SInkey(0)
ENDIF
/*IF ! MemoWrit(Trim(Tr_getini(1))+"\run\erschoepf.ch",ValToPrg(aExclude))
   Throw(Error(,,,,"Could not save erschoepf.ch"))
ENDIF */