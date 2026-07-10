PROC RUN_CHECK_RAHMEN_ABRUFE()
LOCAL nRec
LOCAL nItmnr,nAbnr
LOCAL dFirst,dLast
LOCAL nCalls
LOCAL cFilter := 'Right(Str(Dterm,4),2) == "99" .AND. VkQty > 0 .AND. BeStat < 3 .AND. SDatum < StoD("'+DtoS(AddMonth(Date(),-3))+'") .AND. Wterm >= '+CalWeek(Date())
LOCAL aList
LOCAL cFile := Path("export\missing_calloffs.csv")
LOCAL nH
LOCAL dEnd,nLZ,nRestLZ,nLos,nMonthsBetween,nExptectedQty

NetUse("engauf","auf")
auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter))
auf->(dbGoTop())

CLS

nH := FCreate(cFile)

IF nH <= 0
   Tr_MsgBox(t("Datei kann nicht geöffnet werden"))
ENDIF

aList := {{"Kunde","AB-Nr","Datum","Matchcode","Anzahl Abrufe","Letzter Abruf","Rahmenende","Losgr”áe","Offene Menge","Erwartete offene Menge"}}

DO WHILE ! auf->(EOF())
   nRec := auf->(Recno())
   auf->(dbClearFilter())
   nAbNr := auf->AbNr
   nItmnr := auf->Itmnr
   dFirst := Date()
   dLast := auf->SDatum
   nCalls := 0
   dEnd := CalWD(auf->WTerm)+4
   nLZ := Max((dEnd-auf->SDatum)/30,1)
   nRestLZ := Max((Date()-dEnd)/30,0)
   

   auf->(dbSkip())
   DO WHILE auf->Abnr == nAbnr .AND. ! auf->(EOF())
      IF auf->ContrPos == nItmnr .AND. ((auf->Bestat < 3 .AND. auf->VkQty > 0) .OR. (auf->BeStat >= 3 .AND. auf->GelQty > 0))
         dFirst := Min(dFirst,auf->WDatum)
         dLast := Max(dLast,auf->WDatum)
         nCalls++
      ENDIF
      auf->(dbSkip())
   ENDDO

   auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter))
   auf->(dbGoto(nRec))

   IF nCalls == 0
      nLos := auf->ContrQty/nLZ
   ELSE
      nLos := (auf->ContrQty-auf->VkQty)/nCalls
   ENDIF
   nLos := Max(nLos,1)
   nMonthsBetween := (auf->VkQty)/nLos

   nExptectedQty := Round(auf->ContrQty-auf->ContrQty/nLZ*(Max(Date(),dLast)-auf->SDatum)/30,0)
   

   /*IF nCalls == 0
      ? auf->Abnr,auf->Besda,auf->Matchcode,"noch kein Abruf"
      Aadd(aList,{auf->Kundma,auf->Abnr,auf->Besda,auf->Matchcode,0,"",dEnd,nLos,auf->VkQty,nExptectedQty})
   ELSE*/IF nExptectedQty < auf->VkQty
      
      //IF dLast < AddMonth(Date(),nMonthsBetween*-1.5)
         ? auf->Abnr, auf->Besda,auf->Matchcode,"lange kein Abruf","Ist:",LTrim(Str((dLast-Date())/30)),"Erwartet:",LTrim(Str(nMonthsBetween))
         Aadd(aList,{auf->Kundma,auf->Abnr,auf->Besda,auf->Matchcode,nCalls,IF(nCalls==0,"",dLast),dEnd,nLos,auf->VkQty,nExptectedQty})
      //ENDIF
   ENDIF
   auf->(dbSkip())
ENDDO

FClose(nH)

SaveASCsv(cFile,aList)
Wapi_ShellExecute(,"open",cFile)

Sinkey(0)