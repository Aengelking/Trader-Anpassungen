
FUNCTION HOOK_BEFORE_PACK(nNr,lRech,nVersandart,nPerson)

LOCAL nRec,aParts := {},cKunde,aList
LOCAL cFilter := "aoqty != 0"
LOCAL oRechnung,oExtra
LOCAL dDate,aEMPB,nX,aInv
LOCAL cText := ""

HB_SYMBOL_UNUSED(nVersandart)
HB_SYMBOL_UNUSED(nPerson)

IF lRech
   oRechnung := Rechnung():New()
   oRechnung:Load(nNr)

   re->(dbSetOrder( 12 ))
   re->(dbSeek( Str(nNr,6)+Str(0,3) ))
   nRec := re->(Recno())
   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( re->Kunde+"K" ))
   oExtra := ku->(ExtraData():New( ku->Nummer ))

   IF /*oExtra:EMPB .OR.*/ oExtra:PrintBegin //Trim(re->Kunde) $  {"SCHNEIDG"}
      cKunde := re->Kunde
      dDate  := re->Rechdat
      aList := {Pad("Matchcode",25)+Chr(179)+Pad("Etikett",20),Replicate(Chr(196),25)+Chr(197)+Replicate(Chr(196),20)}
      //aEMPB := {}

      re->(dbSetFilter({|| re->(&(cFilter)) },cFilter))
      re->(dbSkip(1))
      DO WHILE re->Rechnr == nNr .AND. ! re->(EOF())
         IF ! re->Artikelnr $ aParts
            Aadd(aParts,re->Artikelnr)
         ENDIF
         re->(dbSkip())
      ENDDO
      art->(dbSetOrder( 2 ))
      FOR nX := 1 TO Len(aParts)
         art->(dbSeek( Str(aParts[nX],6) ))
         aInv := {}
         re->(dbSetOrder( 15 ))
         re->(dbSeek( cKunde+art->Matchcode ))
         DO WHILE re->Kunde == cKunde .AND. re->Matchcode == art->Matchcode .AND. Len(aInv) < 3
            IF re->Rechnr != nNr .AND. ! re->Rechnr $ aInv .AND. re->Rechdat < dDate
               nRec := re->(Recno())
               re->(dbSetOrder( 12 ))
               re->(dbClearFilter())
               re->(dbSeek( Str(re->Rechnr,6)+Str(0,3) ))
               IF re->Packed  //packed is only set on the header record
                  Aadd(aInv,re->Rechnr)
               ENDIF
               re->(dbSetOrder( 15 ))
               re->(dbSetFilter({|| re->(&(cFilter)) },cFilter))
               re->(dbGoto(nRec))
            ENDIF
            re->(dbSkip())
         ENDDO
         IF Len(aInv) != 3
            IF Len(aInv) == 0 //bisher noch keine Lieferung
               //Aadd(aEMPB,art->Matchcode)
               IF ! Empty(cText)
                  cText += "<br>"
               ENDIF
               cText += art->Matchcode
            ENDIF
            Aadd(aList,art->Matchcode+Chr(179)+Pad("Serienanlauf",20))
         ENDIF
      NEXT
      /*IF oExtra:EMPB .AND. Len(aEMPB) != 0
         SendMail({{"amos.engelking@engelking.de","AMOS"}},"EMPB erstellen fÅr "+ku->Kunde,"Hallo,<br><br>bitte EMPB fÅr folgende Artikel an "+Trim(ku->Name1)+" erstellen:<br><br><pre>"+cText+"</pre>")
      ENDIF*/
      re->(dbClearFilter())
      re->(dbSetOrder( 12 ))
      IF oExtra:PrintBegin .AND. Len(aList) > 2
         DO WHILE Tr_MsgBox(aList,"ETIKETTEN AUFBRINGEN",{"abbrechen","OK"}) != 2
         ENDDO
      ENDIF
      re->(dbGoto(nRec))
   ENDIF

   IF oExtra:WerksBesch
      /*IF Tr_MsgBox("Werksbescheinigung erforderlich. Vorhanden?",,{"Nein","Ja"}) != 2
         RETURN .F.
      ENDIF*/
   ENDIF 

   IF oExtra:PrintKuArt // Trim(re->Kunde) $ {"BACHMANG","BACHMANN","BACHMANR","TEST"} //Bei diesen Kunden Etiketten mit Kundenartikelnr
      NetUse("artkund","aku")
      NetUse("artikel","art",.F.,0)
      art->(dbSetOrder( 1 ))

      re->(dbSetOrder( 12 ))
      re->(dbSeek( Str(nNr,6)+Str(0,3) ))
      
   
      DO WHILE re->Rechnr == nNr         
         art->(dbSeek( re->Matchcode ))
         IF re->RePosnr > 0 .AND. re->AoQty > 0 .AND. art->Lagerart .AND. aku->(dbSeek( re->Kunde+Str(art->Artikelnr,6) ))
            TxtBox({t("Aufkleber f¸r"),art->Matchcode,"","","","","","","","",""})
            SetPrinterMethodType(5) //stickers
            StickPrint("KUNDENART")
            SetPrinterMethodType(0)
            TxtClear()
         ENDIF

         re->(dbSkip())
      ENDDO
   ENDIF

   IF oRechnung:Taxcode == 0 .AND. oRechnung:Brutto > 1000 .AND. oRechnung:State != "ZOLL"
      Tr_MsgBox("Bitte zuerst die Zollanmeldung durchfÅhren")
      RETURN .F.
   ENDIF
   
ENDIF

RETURN .T.