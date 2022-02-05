PROC RUN_IMPORT_KN
   //Downloaded and modified from https://www.destatis.de/DE/Methoden/Klassifikationen/Aussenhandel/sova-leitdatei.html
   LOCAL cFile := "Y:\Dokumente und Einstellungen\amos\Documents\01_SOVA_alle_gueltigen_Warennummern_WA2022.csv"
   LOCAL aData := FParseEx(cFile,",")
   LOCAL nX

   NetUse("kn","kn")

   kn->(dbGoTop())
   DO WHILE ! kn->(EOF())
      IF AScan(aData,{|x| Trim(x[1]) != Alltrim(StrTran(kn->Code," ","")) }) == 0
         ? kn->Code,"wird gel”scht"      
      ENDIF
      kn->(dbSkip())
   ENDDO

   FOR nX := 1 TO Len(aData)
      IF ! kn->(dbSeek( aData[nX,1] ))
         ? aData[nX,1],aData[nX,2]
         kn->(Add_Rec())
         kn->Code := aData[nX,1]
         kn->Self_expla := aData[nX,2]
         kn->Supplement := aData[nX,3]
         kn->(dbUnLock())
      ENDIF
   NEXT

   ? "Abgeschlossen"
   Sinkey(0)
      