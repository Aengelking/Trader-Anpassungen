FUNC HOOK_GET_DRAWINGFILE( lAW,cZeich,cInd,lKuZeichnung,aFiles )

LOCAL cDir
LOCAl aDir,cFile := "",nX,nPos,cNr
LOCAL lLP := .F.
LOCAL nListArt,aEnv,lZip,lTop

IF ValType(lAw) != "L"
   lAW := .F.
ENDIF

IF Select("art") != 0
   Default(@lKuZeichnung,art->KuZeichnun)
   IF ValType(cZeich) != "C"
      IF lAW
         cZeich := art->Anweisung
         cInd := "" //art->AWIndex
      ELSE
         cZeich := art->Zeichnung
         cInd   := art->ZeichIndex
         cZeich := CharRepl("/\?_-",cZeich," ")
         cInd := CharRepl("/\?",cInd,"_")
      ENDIF
   ENDIF
   IF Trim(cZeich) == Trim(art->Zeichnung) .AND. AT(".LP.BS",art->Matchcode) != 0 //Leiterplatte hier werden wir die Unterzeichnungen zu einer ZIP zusammenfgen (falls notwendig)
      lLP := .T.         
   ENDIF
ENDIF

cDir := "\\EK-SERVER4\Data\Technik\Prozessdoku\"
IF lAW 
   cDir += "Arbeitsanweisungen\"
ELSEIF lKuZeichnung
   cDir += "Kunden\"
ENDIF

IF ValType(cInd) != "C"
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

IF lLP   
   aEnv := SaveEnv()
   NetUse("parts","part")
   part->(dbSetORder( 1 ))
   art->(dbSetORder( 2 ))
   nListArt := art->Artikelnr
   IF ValType(aFiles) != "A"
      aFiles := {}
      lTop := .T.
   ELSE
      lTop := .F.
   ENDIF
   Aadd(aFiles,cFile)
   IF part->(dbSeek( Str(nListArt,6) ))
      DO WHILE part->ListArt == nListArt .AND. ! part->(EOF())
         IF part->Pos > 0
            art->(dbSeek( Str(part->Partart,6) ))
            IF AT(".LP",art->Matchcode) != 0
               aFiles := Hook("GET_DRAWINGFILE",{.F.,art->Zeichnung,art->ZeichIndex,art->KuZeichnun,aFiles})                
               IF ValType(aFiles) == "C"
                  Alert("Error getting drawing file for PCB "+art->Matchcode+";"+aFiles)
                  //Aadd(aFiles,xRet)
               ELSE
                  //aFiles
               ENDIF
            ENDIF
         ENDIF
         part->(dbSkip())
      ENDDO
   ENDIF
   IF lTop      
      IF Len(aFiles) >= 1         
         cFile := cDir+"PCB_"+StrZero(art->Artikelnr,6)+".ZIP"
         /*lZip := .F. //we would also need to check if all files are in the ZIP file
         IF File(cFile)
            FOR nX := 1 TO Len(aFiles)  
               IF FileDate(cFile) < FileDate(aFiles[nX]) .OR. (FileDate(cFile) == FileDate(aFiles[nX]) .AND. FileTime(cFile) < FileTime(aFiles[nX]))
                  lZip := .T.
                  EXIT
               ENDIF            
            NEXT
         ELSE*/
            lZip := .T.
         //ENDIF
         IF lZip
            FOR nX := 1 TO Len(aFiles)  
               IF ! hb_ZipFile( cFile,aFiles,4,,.T.,,.F.,.F.)
                  IF ! GetConfigValue("BATCHMODE")
                     Tr_MsgBox("Error creating ZIP file: "+cFile)
                  ENDIF
                  cFile := ""
               ENDIF               
            NEXT   
         ENDIF
      ENDIF   
      aFiles := NIL  //clear array so we return the ZIP file
   ENDIF
   RestEnv(aEnv,.F.)   
ENDIF
IF ValType(aFiles) == "A" 
   IF ! lLP
      Aadd(aFiles,cFile)
   ENDIF
   RETURN aFiles
ENDIF
RETURN cFile