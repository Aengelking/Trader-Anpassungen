FUNC HOOK_GET_DRAWINGFILE( lAW,cZeich,cInd,lKuZeichnung )

LOCAL cDir
LOCAl aDir,cFile := "",nX,nPos,cNr

IF ValType(lAw) != "L"
   lAW := .F.
ENDIF
IF Select("art") != 0
   Default(@lKuZeichnung,art->KuZeichnun)
ENDIF

cDir := "\\EK-SERVER4\Data\Technik\Prozessdoku\"
IF lAW 
   cDir += "Arbeitsanweisungen\"
ELSEIF lKuZeichnung
   cDir += "Kunden\"
ENDIF

IF ValType(cZeich) != "C" .AND. Select("art") != 0
   IF lAW
      cZeich := art->Anweisung
      cInd := "" //art->AWIndex
   ELSE
      cZeich := art->Zeichnung
      cInd   := art->ZeichIndex
      cZeich := CharRepl("/\?_-",cZeich," ")
      cInd := CharRepl("/\?",cInd,"_")
   ENDIF
ELSEIF ValType(cInd) != "C"
   cInd := ""
ENDIF
cZeich := Trim(cZeich)
cInd   := Trim(cInd)

aDir  := Directory(cDir+"*.*")

FOR nX := 1 TO Len(aDir)
	nPos := At("_",aDir[nX,1])
	IF nPos == 0
		nPos := RAt(".",aDir[nX,1])
	ENDIF

	cNr := SubStr(aDir[nX,1],1,nPos-1)
	DO WHILE (nPos := At("0",cNr)) == 1
		cNr := SubStr(cNr,nPos+1)
   ENDDO

   IF cNr == cZeich+cInd .OR. cNr == cZeich+"-"+cInd
		cFile := cDir+aDir[nX,1]
		EXIT
	ENDIF
NEXT

RETURN cFile