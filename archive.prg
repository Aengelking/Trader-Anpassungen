Head("PDF Dokumente ins Archiv verschieben")

/*will require diff-pdf
https://github.com/vslavik/diff-pdf
*/
#define MOVE_FILES
//#define CLEAN_ARCHIVE
//#define UPDATE_LASTCHANGE
//#define MOVE_ABS

cDir        := Path("pdf")
cDiffExe    := "C:\Users\Amos\Downloads\diff-pdf-2012-02-28\diff-pdf.exe"
cArchiveDir := "y:\archive\"
/*"AB"=>HB_AnsiToOem("Auftragsbestätigungen"),;
                "Belastungsanzeige_"=>"Belastungsanzeigen",;
                "Bestellung_"=>"Bestellungen",;
                "LS"=>"Lieferscheine",;
                "RE"=>"Rechnungen",;
                "PI"=>"Proformarechnungen",;
                "TA"=>HB_AnsiToOem("Terminänderungen")
*/

hTypes      := { ;
                "Angebot_"=>"Angebote";
}

FOR nT := 1 TO Len(hTypes)
    @ 01,00 SAY Pad(HGetValueAt(hTypes,nT),50)
    cType := HGetKeyAt(hTypes,nT)
    cArch := cArchiveDir+"\"+HGetValueAt(hTypes,nT)+"\"

    //move files from cDir to cArchiveDir
    #ifdef MOVE_FILES
    aDir  := Directory(cDir+"\"+cType+"*.pdf")
    @ 02,00 SAY Pad(HGetValueAt(hTypes,nT)+" "+Ltrim(Str(Len(aDir)))+t(" Einträge"),MaxCol())
    FOR nX := 1 TO Len(aDir)
        cTarget := aDir[nX][1]
        IF AT("?",cTarget) == 0  .AND. AT(".brf",cTarget) == 0 //no wrong encoded chars and not a letter
          DO WHILE File(cArch+cTarget)
             nPos := Rat("_",cTarget)
             IF nPos == 0
                nCount := 1
                nPos := Rat(".",cTarget)-1
                cTarget := SubStr(cTarget,1,nPos)+"_"+LTrim(Str(nCount))+".pdf"
             ELSE
                nCount := Val(SubStr(cTarget,nPos+1,Rat(".",cTarget)-nPos-1))
                nCount++
                cTarget := SubStr(cTarget,1,nPos)+LTrim(Str(nCount))+".pdf"
             ENDIF
          ENDDO
          @ 24,00 SAY Pad(aDir[nX][1],MaxCol())
          COPY FILE (cDir+"\"+aDir[nX][1]) TO (cArch+cTarget)
          SetFDaTi(cArch+cTarget,FileDate(cDir+"\"+aDir[nX][1]),FileTime(cDir+"\"+aDir[nX][1]))
          DELETE FILE (cDir+"\"+aDir[nX][1])
        ENDIF
  NEXT
  #endif

   #ifdef UPDATE_LASTCHANGE
   IF cType $ "AB"
      IF cType == "AB"
         NetUse("auftrag","ab")
      ENDIF
      aDir := Directory(cArch+"*.pdf")
      FOR nX := 1 TO Len(aDir)
         @ 24,00 SAY Pad(aDir[nX,1],50)
         cContent := FileStr(cArch+aDir[nX,1])
         cField    := SubStr(cContent,At("/CreationDate",cContent)+13)
         cDateTime := SubStr(cField,At("D:",cField)+2,14)
         nPos := Rat("_",aDir[nX,1])-1
         IF nPos == 0
            nPos := Rat(".",aDir[nX,1])-1
         ENDIF
         nNr := Val(SubStr(aDir[nX,1],Len(cType)+1,6))
         @ 25,00 SAY nNr
         @ 26,00 SAY cDateTime
         IF cType == "AB"
            IF ab->(dbSeek( Str(nNr,6) )) .AND. cDateTime > ab->LastChange
               ab->(Rec_Lock(0))
               ab->Lastchange := cDateTime
               ab->(dbUnLock())
            ENDIF
         ENDIF
      NEXT
   ENDIF
  #endif

  #ifdef MOVE_ABS
  IF cType $ "AB"
      aDir := Directory(cArch+"*.pdf")
      FOR nX := 1 TO Len(aDir)
         @ 24,00 SAY Pad(aDir[nX,1],50)
         cContent := FileStr(cArch+aDir[nX,1])
         cTarget := ""
         IF (At("TERMINÄNDERUNG",cContent) != 0 .OR. At("DELIVERY AMMENDMENT",cContent) != 0)
            cTarget := cArchiveDir+"\"+hTypes["TA"]+"\"+StrTran(aDir[nX,1],"AB","TA")
         ELSEIF (At("PROFORMA RECHNUNG",cContent) != 0 .OR. At("PROFORMA INVOICE",cContent) != 0)
            cTarget := cArchiveDir+"\"+hTypes["PI"]+"\"+StrTran(aDir[nX,1],"AB","PI")
         ENDIF
         IF ! EMPTY(cTarget)
            COPY FILE (cArch+"\"+aDir[nX][1]) TO (cTarget)
            SetFDaTi(cTarget,FileDate(cDir+"\"+aDir[nX][1]),FileTime(cDir+"\"+aDir[nX][1]))
            DELETE FILE (cArch+"\"+aDir[nX][1])
         ENDIF
      NEXT
  ENDIF
  #endif



  //Clean Archive from Duplicates
  #ifdef CLEAN_ARCHIVE
  aDir := Directory(cArch+"*.pdf")
  nLastNr := 0

  DiskChange(Left(cArch,1))
  DirChange(cArch)

  FOR nX := 1 TO Len(aDir)
     IF At(".brf",aDir[nX,1]) == 0
       nNr := Val(SubStr(aDir[nX,1],Len(cType)+1,6))
       IF nNr == nLastNr
//         ? WAPI_ShellExecuteEx(,"open",cDiffExe,cLastFile+" "+aDir[nX,1],cArch)
         cCmd := cDiffExe+' "'+cLastFile+'" "'+aDir[nX,1]+'"'
         nRet := HB_ProcessRun(cCmd)
         IF nRet == 0 //no difference
            IF AT("?",aDir[nX][1]) == 0
           COPY FILE (cArch+aDir[nX][1]) TO (cArch+"duplicates\"+aDir[nX][1])
           DELETE FILE (cArch+aDir[nX][1])
           ? aDir[nX,1]+" moved"
           ENDIF
         ELSEIF nRet < 0 //error

         ELSE
            cLastFile := aDir[nX,1]
         ENDIF
       ELSE
         nLastNr := nNr
         @ 24,00 CLEAR
         @ 24,00 SAY Str(nNr,6)
         cLastFile := aDir[nX,1]
       ENDIF

     ENDIF
  NEXT
  #endif

NEXT

Inkey(0,128)