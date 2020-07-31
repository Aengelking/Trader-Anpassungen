LOCAL nRec
LOCAL nItmnr,nAbnr
LOCAL dFirst,dLast
LOCAL nCalls
LOCAL cFilter := 'Right(Str(Dterm,4),2) == "99" .AND. VkQty > 0 .AND. BeStat < 3 .AND. SDatum < StoD("'+DtoS(AddMonth(Date(),-3))+'")'
LOCAL aList
LOCAL cFile := Path("export\missin_calloffs.csv")
LOCAL nH
Alert(cFilter)
NetUse("engauf","auf")
auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter))
auf->(dbGoTop())

CLS

nH := FCreate(cFile)

IF nH <= 0
   Tr_MsgBox(t("Datei kann nicht geöffnet werden"))
ENDIF

aList := {{"AB-Nr","Datum","Matchcode","Monate seit letzem Abruf","Erwartete Monate"}}

DO WHILE ! auf->(EOF())
   nRec := auf->(Recno())
   auf->(dbClearFilter())
   nAbNr := auf->AbNr
   nItmnr := auf->Itmnr
   dFirst := Date()
   dLast := Date()
   nCalls := 0

   auf->(dbSkip())
   DO WHILE auf->Abnr == nAbnr .AND. ! auf->(EOF())
      IF auf->ContrPos == nItmnr
         dFirst := Min(dFirst,auf->WDatum)
         dLast := Max(dLAst,auf->WDatum)
         nCalls++
      ENDIF
      auf->(dbSkip())
   ENDDO
   auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter))
   auf->(dbGoto(nRec))
   IF nCalls == 0
      ? auf->Abnr,auf->Besda,auf->Matchcode,"noch kein Abruf"
      Aadd(aList,{auf->Abnr,auf->Besda,auf->Matchcode,"kein Abruf",0})
   ELSE
      nMonthsBetween := ((auf->ContrQty-auf->VkQty)/nCalls)/(auf->ContrQty/12)
      IF dLast > AddMonth(Date(),nMonthsBetween*1.5)
         ? auf->Abnr, auf->Besda,auf->Matchcode,"lange kein Abruf","Ist:",LTrim(Str((dLast-Date())/30)),"Erwartet:",LTrim(Str(nMonthsBetween))
         Aadd(aList,{auf->Abnr,auf->Besda,auf->Matchcode,(dLast-Date())/30,nMonthsBetween})
      ENDIF
   ENDIF
   auf->(dbSkip())
ENDDO

FClose(nH)

SaveASCsv(cFile,aList)
Wapi_ShellExecute(,"open",cFile)

Sinkey(0)