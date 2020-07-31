PARAMETERS aWeights,lRech,nNr,nRechNr,aPakData,lExpress

LOCAL cDir := "Y:\DHL\import\"
LOCAL cDirEx := "Y:\DHL\export\"
LOCAL cText := ""
LOCAL nX,cFile,nF,lSuccess
LOCAL lAusland := .F. ,lEg := .F.

IF ValType(lExpress) != "L"
   lExpress := .F.
ENDIF

IF lRech
   nNr := nRechnr
   
   re->(dbSetOrder(4))
   re->(dbSeek( Str(nRechnr,6) ))
   GotoRechAddress(.T.)

ENDIF

cFile := cDir+IF(lRech,"R","E")+LTrim(Str(nNr))+".txt"

IF File(cFile)
   TR_MsgBox(t("Sendung wurde bereits an DHL übergeben"))
   RETURN .F.
ENDIF

IF ku->CountryIso != "DE"
	lAusland := .T.
	NetUse("countri2","ctr")
	ctr->(dbSeek( ku->CountryIso ))
	lEg := ctr->EG
ENDIF


FOR nX := 1 TO Len(aWeights)
   IF nX > 1
      cText += Chr(13)+Chr(10)
   ENDIF
   cText += IF(lRech,"R","E")+LTrim(Str(nNr,6))+"_"+LTrim(str(nX))+";"+HB_OEMToAnsi(StrTran(Trim(Trim(ku->Name1)+" "+ku->Name2),";"," ")+";;;"+StrTran(Trim(ku->Street),";"," ")+";"+Trim(ku->PLZ)+";"+Trim(ku->Town))+";"+Ltrim(StrTran(Str(aWeights[nX],8,2),".",","))
   //Verfahren
   IF lExpress
      cText += ";"+IF(lAusland,"99","72")
   ELSE
      cText += ";"+IF(lAusland,"53","01")
   ENDIF
   //Teilnahme
   cText += ";01"
   //Produkt
   IF lExpress
      cText += ";"+IF(lAusland,"9904","7202")
   ELSE
      cText += ";"+IF(lAusland,"5301","101")
   ENDIF
   //Land
   cText += ";"+HB_OemToAnsi(ku->CountryIso)+";"
   IF lAusland .AND. ! lEG
      cText += LTrim( Str(GetBox(0,"Warenwert",,,,,{|x| x>0})) )
   ELSE
      cText += "0"
   ENDIF
NEXT

nF := FCreate(cFile)
IF nF <= 0 //Error
	TR_MsgBox(t("Fehler beim Erstellen der Datei "+cFile))
	RETURN .F.
ENDIF
FWrite(nF,cText)
FClose(nF)

/*TxtBox("Warte auf DHL Easylog...")

nTime := Seconds()
nX := 1
nDone := 0

DO WHILE Seconds() <= nTime+10 .AND. nDone < Len(aWeights)
   FOR nX := nX TO Len(aWeights)
      IF File(cDirEx+IF(lRech,"R","E")+LTrim(Str(nNr,6))+"_"+LTrim(str(nX))+"*.txt")
         TxtClear()
         TxtBox("Paket "+LTrim(Str(nX))+" verarbeitet")
         nDone++
      ELSE
         EXIT
      ENDIF
   NEXT
   Inkey(1)
ENDDO

IF nDone <  Len(aWeights)
   TR_MsgBox("Sendung wurde nicht korrekt verarbeitet!")
   lSuccess := .F.
ELSE
   lSuccess := .T.
ENDIF

//delete result files
FOR nX := 1 TO Len(aWeights)
   aDir := Directory(cDirEx+IF(lRech,"R","E")+LTrim(Str(nNr,6))+"_"+LTrim(str(nX))+"*.txt")
   FOR nF := 1 TO Len(aDir)
      FErase(aDir[nF,1])
   NEXT
NEXT

//RETURN .F. //FOR TESTING ONLY
//RETURN lSuccess  */
RETURN .T.

