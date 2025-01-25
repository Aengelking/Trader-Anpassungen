PROC RUN_TEST_UPS_PRICE
   LOCAL cFile,cDir
   NetUse("englsre","re",.F.,0)
   re->(dbSetOrder( 4 ))

   NetUse("lagerne","lne",.F.,0)
   NetUse("engkund","ku",.F.,0)
   NetUse("ups","ups")
   NetUse("paknum","pnum")

   CLS

   cDir := "Y:\UPS\Import\"
   cFile := cDir+"R68398"
   aNummer := {}

   //aFiles := Directory(cDir+"*.out")
   nF := 1
   nTotProfit := 0

   SetColor("N/W")
   /*Do While nF <= Len(aFiles)

      cFile := cDir+aFiles[nF][1]*/

      oXml := TXmlDocument():New()
      oXml:Read(MemoRead(cFile+".out"))

      oNode := oXml:findFirst( "OpenShipment" )

      cStatus := oNode:aAttributes["ProcessStatus"]  //Fail To Import | Processed

      If cStatus != "Processed"
         oNode := oXml:findFirst("ErrorMessage")
         If oNode == NIL
            Tr_MsgBox("Unbekannter Fehler")
         Endif
         Do While oNode != NIL
            Tr_MsgBox(HB_AnsiToOem(oNode:cData),"Fehler!")
            oNode := oXml:findNext()
         Enddo
      Else  //Read Tracking numbers
         oNode := oXml:findFirst("TrackingNumbers")
         If oNode == NIL
            Tr_MsgBox("Keine Sendungsnummern gefunden")
            Return .F.
         Endif
         Do While oNode != NIL
            oIter := TXmlIterator():new( oNode )
            oIter:Rewind()
            lIter := .T.
            Do While lIter
               oSubNode := oIter:next()
               If oSubNode == NIL
                  lIter := .F.
               Else
                  Aadd(aNummer,{"NUMMER"=>oSubNode:cData})
               Endif
            Enddo
            oNode := oXml:findNext()
         Enddo

         oNode := oXml:findFirst("ShipperCharges")
         If oNode == NIL
            Tr_MsgBox("Keine Kosten gefunden")
            Return .F.
         Endif
         nX := 1
         Do While oNode != NIL
            oCost := oNode:oChild:oChild:oNext
            IF nX <= Len(aNummer) .AND. ku->CountryIso != "DE" //.AND. aNummer[nX]["PREIS"] == 0
               ? oCost:cData,Val(StrTran(oCost:cData,",","."))
            ENDIF
            oNode := oXml:FindNext()
            nX++
         Enddo
         nF++
      ENDIF
   //Enddo

Sinkey(0)