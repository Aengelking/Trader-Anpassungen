NetUse("englsre","re",.F.,0)
re->(dbSetOrder( 4 ))

NetUse("lagerne","lne",.F.,0)
NetUse("engkund","ku",.F.,0)
NetUse("ups","ups")
NetUse("paknum","pnum")

cDir := "Y:\UPS\Import\"
cFile := cDir+"R35939"
aNummer := {}

aFiles := Directory(cDir+"*.out")
nF := 1
nTotProfit := 0

StartPrint(,,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:NewPage()
oPdf:SetFont("COURIER")
SetColor("N/W")
Do While nF <= Len(aFiles)

	cFile := cDir+aFiles[nF][1]
	oXml := TXmlDocument():New()
	oXml:Read(MemoRead(cFile)) //+".out"))
	

	oIter := TXmlIterator():new( oXml:findFirst( "OpenShipments" ) ) //oXml:findFirst( "OpenShipment" )
	oNode := oXml:findFirst( "OpenShipment" )

	cStatus := oNode:aAttributes["ProcessStatus"]  //Fail To Import | Processed
	If cStatus != "Processed"
		oNode := oXml:findFirst("ErrorMessage")
		If oNode == NIL
			Tr_MsgBox("Unbekannter Fehler")
		Endif
		Do While oNode != NIL
//			Tr_MsgBox(HB_AnsiToOem(oNode:cData),"Fehler!")
			oNode := oXml:findNext()
		Enddo
	Else  //Read Tracking numbers
/*		oNode := oXml:findFirst("TrackingNumbers")
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
					Aadd(aNummer,oSubNode:cData)
				Endif
			Enddo
			oNode := oXml:findNext()
		Enddo     */

		cType := SubStr(aFiles[nF][1],0,1)
		nPos := At(".",aFiles[nF][1])
		If At("_",aFiles[nF][1]) > 0
			nPos := At("_",aFiles[nF][1])
		Endif
		nPos -= 2
		cNr   := SubStr(aFiles[nF][1],2,nPos)

		oNode := oXml:findFirst("ShipperCharges")
	*//	oNode := oNode:findFirst("Negotiated")
		If oNode == NIL
			oPdf:NewLine()
			oPdf:AtSay(cType+" "+cNr+" "+"Keine Rückgabe der Kosten")
		Else
         IF cType == "R"
   			ups->(dbSetOrder( 3 ))
   			ups->(dbSeek( PadL(cNr,10) ))
   		ELSEIF cType == "E"
   	    	ups->(dbSetOrder( 4 ))
   	    	ups->(dbSeek( VaL(cNr) ))
   	   ENDIF
         pnum->(dbSeek( ups->Nr ))

		   nCost := 0
			DO WHILE oNode != NIL
            oNode := oNode:oChild:oChild:oNext
   			nCost += Val(StrTran(oNode:cData,",","."))


	        IF pnum->Nr == ups->Nr
	            pnum->(Rec_Lock())
        	      pnum->Preis  := Val(StrTran(oNode:cData,",","."))
        	      pnum->(dbUnLock())
           ENDIF


            pnum->(dbSkip())
   			oNode := oXml:FindNext()
   		ENDDO
			nInv  := 0
			If cType == "R" .AND. re->(dbSeek( PadL(cNr,6) ))
				nInv := re->ofqty
				ku->(dbSeek( re->Kunde+"K" ))

				dbSelectArea("re")
				LOCATE FOR AT("PORTO",re->Matchcode) == 1 WHILE re->Rechnr == Val(cNr)
				IF re->(Found())
				  nInv += re->PosWt
				ENDIF
			Elseif lne->(dbSeek( Val(cNr) ))
				ku->(dbSeek( lne->Kunde+lne->Gruppe ))
			Endif

         //IF nInv != 0
			nProfit := nInv-nCost
         nTotProfit += nProfit

			oPdf:NewLine()
			oPdf:AtSay(cType+" "+cNr+" "+ku->Kunde+" "+Str(nCost,6,2)+" "+Str(nInv,6,2))
			If nInv-nCost < 0
				SetColor("R+/W")
			Endif
			oPdf:AtSay(chr(253)+If(nProfit<0,Chr(255),Chr(0))+Chr(0)+Chr(0)+" "+Str(nProfit,7,2))
                        oPdf:AtSay(chr(253)+Chr(0)+Chr(0)+Chr(0))
			If nInv-nCost < 0
				SetColor("N/W")
			Endif
         //ENDIF
//			Alert( "Preis: "+Str(nCost) )
		Endif
		//Alert( Len(aNummer) )
	Endif
	nF++
Enddo
oPdf:NewLine()
oPdf:AtSay(Space(25)+Str(nTotProfit,9,2))
CopyPrint()