PROCEDURE RUN_UPDATE_CREDITSAFE
LOCAL nDays := 15
LOCAL nOpenOrders,hTurnOver
LOCAL aFiles
LOCAL aList := {}


NetUse("creditsafe","cs")
NetUse("engkund",   "ku")
NetUse("skontoa","sk")


Head(t("Aktualisierung Creditsafe Auskünfte"))

cs->(dbSetFilter({|| cs->LastCheck < Date()-nDays},'lastcheck < StoD("'+DtoS(Date()-nDays)+'")'))
cs->(dbGoTop())

ku->(dbSetOrder( 8 ))

DO WHILE ! cs->(Eof())

   IF ku->(dbSeek( Str(cs->Kunde,6) ))
      ? ku->Kunde
   
      IF Empty(cs->LastCheck)
         aFiles := GetArchiveFiles({"KAM"=>cs->Kunde})
         cs->(Rec_Lock())
         IF Len(aFiles) >= 1         
            cs->LastCheck := ATail(aFiles)[3]         
         ELSE
            cs->LastCheck := Date()
         ENDIF
         cs->(dbUnLock())
      ENDIF
      nOpenOrders := GetCustomerOpenOrders(ku->kunde)
      IF nOpenOrders == 0
         hTurnover := GetCustomerTurnover(ku->kunde)
      ENDIF
      IF ! sk->(IsPrePay(ku->Skonto)) .AND. (nOpenOrders != 0 .OR. hTurnover["12-month"] > 0)
         Aadd(aList,{SubStr(cs->ID,RAT("/",cs->Id)+1),,,ku->Nummer})
      ELSE
         ?? " nicht aktiv"
         cs->(Rec_Lock())
         cs->LastCheck := Date()
         cs->(dbUnLock())
      ENDIF      
   ELSE
      ? "Kunde nicht gefunden "+Str(cs->Kunde)
      cs->(Rec_Lock(0))
      cs->(dbDelete())
      cs->(dbUnLock())
   ENDIF
   
   cs->(dbSkip())
   
ENDDO

SaveAsCSV(Path("export\csmonitor.csv"),aList)
SendMail({{"amos.engelking@engelking.de","Amos"}},"Creditsafe Montioring aktualisieren","Datei x:\export\csmonitor.csv")

//#include 'X:\run\creditsafe.prg'