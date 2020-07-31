LOCAl cDir := "Y:\DHL\Export"
LOCAL cFile,nHandle,cLine := ""
LOCAL cType,nNr,nBox,aDir,nX

Head("DHL Sendungsnnummern importieren")

NetUse("ups","ups")
NetUse("paknum","pnum")

aDir := Directory(cDir+"\*.txt")

FOR nX := 1 TO Len(aDir)

	cFile := aDir[nX,1] //"ELSendEx20131118152819881.txt"
	nHandle := FOpen( cDir+"\"+cFile )

	@ 01,00 CLEAR
	? cFile
	
	lLeave := .F.

	DO WHILE ! lLeave
      lLeave := HB_FreadLine(nHandle,@cLine) != 0

      aData := HB_ATokens(cLine,";")

		cType := Left(aData[23],1)
		nPos := At("_",aData[23])
		IF nPos == 0
			nPos := Len(aData[23])+1
			aData[23] += "_1"
		ENDIF
		IF cType != "R" .AND. cType != "E"
			cType := "X"
			aData[23] := "X"+aData[23]
			nPos++
		ENDIF
		nNr := Val(SubStr(aData[23],2,nPos))
		nBox := Val(SubStr(aData[23],nPos+1,Len(aData[23])-nPos))

		? cType,nNr,nBox,aData[23],aData[12],aData[2],aData[18]

		IF nNr == 0
			? "Sendungsnr nicht erkannt"
			LOOP
		ELSEIF cType == "R" .OR. (cType == "X" .AND. nNr <= 80000)
			ups->(dbSetOrder( 3 ))
			ups->(dbSeek( Str(nNr,10) ))
		ELSEIF cType == "E"
	    	ups->(dbSetOrder( 4 ))
	    	ups->(dbSeek( nNr ))
	    ELSE
	    	? "Sendungstyp nicht erkannt"
	    	LOOP
		ENDIF
		IF ! ups->(Found())
			? "Sendung nicht gefunden"
			LOOP
		ELSE
	    	nSndNr := UPS->NR
	        pnum->(dbSeek( nSndNr ))
	        pnum->(dbSkip( nBox-1 ))
	        IF pnum->Nr != nSndNr
//	        	? "Paket Nr. "+LTrim(Str(nBox))+" nicht gefunden"
	        	pnum->(add_rec(0))
	        	pnum->Weight := Val(StrTran(aData[25],",","."))
	        	pnum->Nr     := nSndNr
	        	pnum->(dbUnLock())
	        ENDIF
        	pnum->(Rec_Lock())
        	pnum->Nummer := aData[2]
        	//pnum->Preis  := Val(StrTran(aData[30],",","."))
        	pnum->(dbUnLock())
		ENDIF
	ENDDO

	FClose(nHandle)
	__Run("move "+cDir+"\"+cFile+" "+cDir+"\imported\"+cFile)
NEXT
	/*
	25 = Gewicht (mit Komma)
	23 = Ref-Nr.
	12 = Datum
	2 =  Paketnr
	18 = Kunde
	30 = Preis
	*/

	Inkey(0,128)


