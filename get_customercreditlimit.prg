FUNCTION Get_CustomerCreditlimit(nKuNr,cKunde,nCredLimit,nError)

LOCAL nMonths := 12
//LOCAL lDbg := Inkey() == 32 .AND. Tr_Getini(28) == 9 .AND. ProcName(6) == "TRD_02"
LOCAL lDbg := .F. //Tr_Getini(28) == 9 //.F.
LOCAL nRating
LOCAL hSpecial,hBigCustomer
LOCAL nTotalPaid,nAvgOvr,nPaidOrDueTotal,nPaidTotal
LOCAL aOverrideMax := {}
LOCAL cID
//LOCAL aRegex1,aRegex2,cRegex
LOCAL hMultiMax := {=>}
LOCAL nNettoBeitrag,dBeitragBis
LOCAL lAuftrag := ProcName(6) $ "ENGAUFT AUFCHECKCREDITLIMIT AUFTRAGPOS:CHECKCREDITLIMIT"
LOCAL cSCR,nRow,nCol
LOCAL aInsolv,dDate,lToLate,nWKVCL,nToLAte,nWait,lWKV,lSimpleCountry,lMoreCountry
LOCAL dPDate,dFinal,lPaid,nR,nC,aFiles,nOpenOrders,hTurnover,oSOAP
LOCAL oCtr,oSearch,oXML,oCompany,oReport,oIter,oNode,nMaxDeckung
LOCAL oExtra
LOCAL aRegex
LOCAL hSpecialWKV
LOCAL hMaxLimit,hAddLimit
LOCAL hDisputedInvoices
LOCAL hFactoringLimits := {=>}
LOCAL cTiltaStatus
LOCAL cPic := "@E 99,999,999.99"

MEMVAR mlShowInvoiceList
PUBLIC mlShowInvoiceList

nError := 0 //set default error to 0

IF Trim(ku->Kunde) == "ENGELKIA"
   RETURN 1000000  //Konzernunternehmen
ENDIF

IF Trim(ku->Kunde) == "VARTAR" .AND. Tr_Getini(28) == 9
   //RETURN 22000
ENDIF


IF Trim(ku->Kunde) == "SCOLMORE" //.AND. Tr_Getini(28) == 9
   RETURN 8000
ENDIF

IF Trim(ku->Kunde) == "SOFTCOM"
   RETURN 40000
ENDIF

IF Trim(ku->Kunde) == "RMWKABEL"
   //RETURN 560000
ENDIF



LoadPrg(Path("run\creditsafe.prg"))

IF Tr_Getini(28) == 9 // .OR. (Tr_Getini(28) == 33 .AND. Date() <= StoD("2020109"))
   //lAuftrag := .T.
   //lDbg := .T.

   //nCredLimit := 1 //ku->CreditLimit
   /*CLS
   NX := 1
   DO WHILE ! Empty(Procname(nX))
      ? nX,Procname(nX)
      nX++
   ENDDO
   SInkey(0)*/
ENDIF
    
    /***
      SETTINGS
    ***/

    nNettoBeitrag := 13214.83 //11522.96 //13712.82 //16430.86 //14961.43 //11844.02 //12511.50 //10879.57 //9460.49 //10766.35 //8610.54
    dBeitragBis   := SToD("20270131")

    aInsolv := {"CPL"}


    hSpecial := {=>}
    hBigCustomer := {=>}

    //Sonderlimite der WKV
    hSpecialWKV := {=>}
    hSpecialWKV["GESSMANN"] := 469453

    //bestrittene Rechnungen
    hDisputedInvoices := {=>}
    hDisputedInvoices[68252] := {"UNTIL"=>StoD("20240510")}
    hDisputedInvoices[69296] := {"UNTIL"=>StoD("20241025")}
    hDisputedInvoices[69788] := {"UNTIL"=>StoD("20241025")}
    hDisputedInvoices[69774] := {"UNTIL"=>StoD("20241205")}
    hDisputedInvoices[69963] := {"UNTIL"=>StoD("20241205")}
    hDisputedInvoices[69725] := {"UNTIL"=>StoD("20250115")} //not really disputed but there is some problem with the invoice
    hDisputedInvoices[71067] := {"UNTIL"=>StoD("20250607")} //addresses where not correct and the due has been reset to 
    hDisputedInvoices[72029] := {"UNTIL"=>StoD("20250908")} //Preisdifferenz wurde mit Gutschrift 72366/72367 korrigiert
    hDisputedInvoices[71839] := {"UNTIL"=>StoD("20251001")} //War nur telefonisch abgesprochen, gab keine AB oder Bestellung (Ware war fÅr eigene Verarbeitung anstatt Konfektion) dadurhc kam es zu Problemen in der RechungsprÅfung
    hDisputedInvoices[71859] := {"UNTIL"=>StoD("20251001")}  //wie zuvor
   IF lAuftrag      
      hSpecial["EXIDE"] := {"DATE"=>SToD("20211231"),"LIMIT"=>110000} //28.08.2020 bekommen nur 40.000 von der Versicherung, da die Ware aber beim Lieferant bestellt ist will ich auch die AuftrÑge eintragen
      hSpecial["VIRTENIO"]  := {"DATE"=>StoD("20201231"), "LIMIT"=>95000} //03.12.20 bekommen lediglich ein Limit von 35.000 von der Versicherung
      hSpecial["WESTFALM"]  := {"DATE"=>StoD("20201231"), "LIMIT"=>60000} //02.07.21 Nur Teilzusage erhalten
      hSpecial["LEONI"]  := {"DATE"=>StoD("20200430"), "LIMIT"=>28000} //06.12.21 Nur Teilzusage erhalten, ist fÅr einen Rahmen der Artikel wird auch von anderen gekauft. Meldebestand niedrig
      hSpecial["GESSMANN"]  := {"DATE"=>StoD("20230630"), "LIMIT"=>860000}  //27.04.22 Erhîht um weitere Abrufe eintragen zu kînnen //11.01.22 Um Abrufe eintragen zu kînnen. Das macht kaum Sinn die nicht einzutragen            
      hBigCustomer["GESSMANN"] := hSpecial["GESSMANN"]["LIMIT"]
      hSpecial["TECDESIG"]  := {"DATE"=>StoD("20220730"), "LIMIT"=>170000}  //30.05.22 Um einen Abruf einzutragen
      hSpecial["FRITSCH1"]  := {"DATE"=>StoD("20220530"), "LIMIT"=>3000}  //10.10.22 Hîheres Auftragslimit da dieser in zwei Lieferung geteilt wird
      hSpecial["LEDJENA"]  := {"DATE"=>StoD("20221230"), "LIMIT"=>85000}  //26.09.23 R+V limitiert auf 75k
      hSpecial["PROCOM"]  := {"DATE"=>StoD("20241230"), "LIMIT"=>165600}  //10.04.24 R+V max Limit 100k 

      hSpecial["AMANNGIR"]    := {"DATE"=>StoD("20241231"), "LIMIT"=>3500} //02.07.24 nachdem es jetzt eine Weile funktioniert hat beginnen die Probleme seit letztem Jahr wieder, daher auf 3500? gesetzt //nach RÅcksprache mit dem Kunden ist die schlechte Zahlungsweise durch eine verzîgerte Freigabe durch den EK bedingt, daher auf 30T gesesetzt und verlÑngert //03.08.18 zahlt schlecht, daher nur fÅr Abrufe
      //hSpecial["WEITEN"] := {"DATE"=>StoD("20181231"), "LIMIT"=>7200} //15.08.18 Zahl nicht konstant - daher Limit nur fÅr AuftrÑge //21.07.16 800Ä f¸r einen Abruf //19.07.16 Hat 1. Rechnung sp‰t bezahlt, Kurzfristiges CL (7000) um einen Rahmen  einzugeben (mit geringen Mindestbest‰nden!)
      //hSpecial["VERPATEC"] :=  {"DATE"=>SToD("20200630"),"LIMIT"=>250000} //31.03.20 Ist ein Rahmen, bekommen nur 100.000 von R+V
      //hSpecial["RMECABLE"] := {"DATE"=>SToD("20201230"),"LIMIT"=>4000} //02.06.2020 zahlt immer erst nach 1. Mahnung, daher nur Auftragslimit
      //hSpecial["VYRIAN"] :=  {"DATE"=>SToD("20201030"),"LIMIT"=>99999} //15.09.20 Erhîhung auf 99999, Limit bei R*V und fÅr Auslieferung weiterhin 20k //17.12.19 Bekommen nur 20k von der R+V            
      hSpecial["RMWKABEL"] :=  {"DATE"=>SToD("20261230"),"LIMIT"=>560000} 
      hSpecial["ARMAGMBH"] :=  {"DATE"=>SToD("20250630"),"LIMIT"=>4800} //15.04.25 Nochmals verlÑnget //10.02.25 VerlÑngert //03.12.24 Letzte zwei Rechnungen erst nach 2. Mahnung bezahlt, Auge draufhalten
      hSpecial["CLEVERCI"] :=  {"DATE"=>SToD("20250930"),"LIMIT"=>32000} //12.08.25 Letzte Rechnung verspÑtet bezahlt, Kreditlimit fÅr Auftrag dies muss jedoch nochmla genauer angeschaut werden vor Auslieferung, da es dort auf 11k beschrÑnkt wird

      
   ELSE
      hSpecial["AMANNGIR"] :=  {"DATE"=>SToD("20241230"),"LIMIT"=>1090} //02.07.24 nur fÅr die Auslieferung der Abrufe s.o.
      hSpecial["VARTAR"] := {"DATE"=>STOD("20241230"),"LIMIT"=>7000} //15.11.24 fÅr die Auslieferung bestehender AuftrÑge fÅr neue wurde das Limit seitens der WKV gestrichen
   ENDIF   

   hMaxLimit := {=>}  //absolute maximale Limits
   //IF Date() < StoD("20240601") .OR. Date() > StoD("20240831")
   //   hMaxLimit["PROCOM"] := 80000  //sollte eigentlich nach meiner Kalk. 60k sein, da wir dann auf die 100k von der R+V kommen mit dem Warenwert im Zulauf.
   //ENDIF

   hAddLimit := {=>}  //zusÑtzliche Limits durch Top-Up Versicherung
   //hAddLimit["PROCOM"] := {"ADD"=>50000,"FROM"=>StoD("20240601"),"UNTIL"=>StoD("20240831")}  //Haben eine zusage Åber 50k von crebita
   
   
   

   NetUse("speccl","spcl")
   IF spcl->(dbSeek(Str(nKuNr,6)))
      IF ! Empty(spcl->SpecLimit) .AND. spcl->SpecLimit > 0 .AND. spcl->Active
         hSpecial[Trim(spcl->Kunde)] :=  {"DATE"=>spcl->ValidUntil,"LIMIT"=>spcl->SpecLimit}         
         IF lDbg
            ? "Special Creditlimit found in speccl:",nCredLimit
         ENDIF
      ENDIF
   ENDIF

   
   //Auftragslimits fÅr gro·e Kunden, diese gelten wenn der Kunde die voll Deckung bei der Versicherung haben    
    hBigCustomer["FRANKE"]   := 241000
    hBigCustomer["STEIERMA"] := 390000
    //hBigCustomer["SCHNEIDG"] := 208000 //berechnetes Fabrikationsrisiko ca. 147 TEUR. 
    hBigCustomer["RMWKABEL"] := 520000 //Sonderlimit WKV

    //Bei diesen Kunden wird der Maximalbetrag nicht aus der Creditsafe-Empfehlung gezogen, sondern nach den allg. Regeln der VR berrechnet
    Aadd(aOverrideMax,"MERSCHJO") //zahlt immer sehr ¸ber-p¸nktlich
    Aadd(aOverrideMax,"ESS") //zahlt immer p¸nktlich mit skonto
    Aadd(aOverrideMax,"WELLER") //zahlt immer p¸nktlich mit skonto
    Aadd(aOverrideMax,HB_AnsiToOem("SETSCHR÷")) //zahlt immer p¸nktlich mit skonto
    Aadd(aOverrideMax,HB_AnsiToOem("R÷BEN")) //zahlt immer mit Skonto
    Aadd(aOverrideMax,"HEROLD") //zahlt immer p¸nktlich oder mit skonto
    Aadd(aOverrideMax,"COBOC") //zahlt immer p¸nktlich mit skonto
    Aadd(aOverrideMax,"NBB") //zahlt immer mit skonto
    Aadd(aOverrideMax,"WATZKA") //zahlt immer mit skonto
    Aadd(aOverrideMax,"INTERUNI") //zahlt immer mit skonto (auch wenn er Sonderzahlungsziel mit 21 Tagen hat!)
    Aadd(aOverrideMax,"ALDERS") //zahlt eigentlich immer mit skonto
    Aadd(aOverrideMax,"BECOMGIL") //zahlt eigentlich immer mit skonto
    Aadd(aOverrideMax,"AGILION") //zahlt immer mit skonto
    Aadd(aOverrideMax,"SSL") //zahlt immer p¸nktlich
    //Aadd(aOverrideMax,"CLEVERCI") //zahlt immer mit skonto
    Aadd(aOverrideMax,"EFBELEK") //zahlt immer mit skonto
    Aadd(aOverrideMax,"HERING") //zahlt immer mit skonto
    Aadd(aOverrideMax,"WENGLOR") //zahlt immer mit skonto    
    Aadd(aOverrideMax,"CARSTECH") //zahlt immer ÅberpÅnktlich
    Aadd(aOverrideMax,"BILZ") //zahlt immer ÅberpÅnktlich    
    Aadd(aOverrideMax,"HITACHI") //zahlt immer ÅberpÅnktlich        
    Aadd(aOverrideMax,"ROTTMANN") //zahle in der Vergangenheit immer mit Skonto
    //Aadd(aOverrideMax,"LORENTZ") //bisher immer mit Skonto
    //Aadd(aOverrideMax,"TJKABELK") //
    //
    //Aadd(aOverrideMax,"MTMMUELL")

//    Aadd(aOverrideMax,"BUTZ") //zahlt immer mit skonto

    //Bei diesen Kunden ist ein generelles ‹berschreiten des CS Limits nicht mˆglich, daher nur ein Mehrfaches (zahlen nicht immer p¸nktlich), max 3x
    hMultiMax["EDEKA"] := 4.5
    hMultiMax["TILLYTA"] := 1.75
    hMultiMax["KOCO"] := 2.6
    hMultiMax["BECOMGIL"] := 3
    hMultiMax["SONEPARE"] := 1.5
    hMultiMax[HB_AnsiToOem("G÷LZ")] := 2
    hMultiMax["WEITER"] := 1.8
    //hMultiMax["WANTEC"] := 1.8
    hMultiMax["HCSHYDRA"] := 1.2
    hMultiMax["BAUERELE"] := 4
    hMultiMax["ARMAGMBH"] := 2
    hMultiMax["MILTRONI"] := 1.02
    hMultiMax["CPL"] := 2
    hMultiMax["LKE"] := 1.5
    hMultiMax["QTECH"] := 2
    hMultiMax["BAUMEIST"] := 1.6
    hMultiMax["MESSEN"] := 1.2
    hMultiMax["HEISESCH"] := 2
    hMultiMax["TECHNOGR"] := 2
    //hMultiMax["ROTTMANN"] := 1.5    
    //hMultiMax["MIESEN"] := 1.1
   
    
    IF lAuftrag
      hMultiMax["MEDAQUA"] := 2 //19.02.19 Limit fÅr Rahmenauftrag. CS limitiert das auf 2500?            
    ENDIF

    //hFactoringLimits["PATELEC"] := 10000
    //hFactoringLimits["KEBAEMOB"] := 5000


   /***
      END OF SETTINGS
   ***/

   IF ValType(mlShowInvoiceList) == "L" .AND. ! lDbg
      lDbg := mlShowInvoiceList
   ENDIF

IF lDbg
	cScr := SaveScreen()
	nRow := Row()
	nCol := Col()
	nMonths := GetBox(nMonths,"Anzahl Monate","99")
ENDIF


NetUse("skontoa","sk")

IF ! lDbg .AND. sk->(IsPrePay(ku->Skonto)) .AND. ! IsInHook("validate_creditlimit")
   RETURN 0
ENDIF

nToLate := 0
If AScan(aInsolv,Trim(cKunde)) != 0
   If ! lAuftrag .OR. Tr_MsgBox("Wurde der Auftrag vom Insolvenzverwalter gezeichnet?","Kunde ist insolvent!",{"Nein","Ja"}) == 2
      Return 10000
   Else
       Return 0
   Endif
   //Return 25000
Endif

dDate         := Date()
//dDate := CToD("28.03.2013")

If dBeitragBis < dDate
   IF GetConfigValue("BATCHMODE")
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Neuen Beitrag der Kreditversicherung hinterlegen")
   ELSE
	   TR_MsgBox("Bitte neuen Beitrag der Kreditversichung hinterlegen.","Kreditversicherung am "+DToC(dBeitragBis)+" abgelaufen")
   ENDIF
	nNettoBeitrag := 0
Endif

NetUse("skontoa","ska",.F.,0)
NetUse("englsre","re",.F.,0)
NetUse("wkv","wkv",.F.,0)
NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder(1))
ku->(dbSeek( cKunde+"K" ))

re->(dbSetORder(2)) //str(reposnr)+Kunde
re->(dbSeek( Str(0,3)+cKunde ))

lToLate        := .F.
nTotalPaid     := 0
nWkvCL         := 0
lWKV           := .F.
lSimpleCountry := ku->CountryIso $ "DE AD BE BG DK EE FI FR GR GB IE IS IT HR LV LI LT LU MT MC NL NO AT PL PT RO SM SE CH SK SI ES CZ HU CY AU JP CA NZ US"
lMoreCountry   := ku->CountryIso $ "HK IN MY MX SG KR TW TH TR"
navgOvr        := 0
nPaidOrDueTotal       := 0
nPaidTotal     := 0

If ska->(IsPrepay(ku->Skonto))
//	Return 0

Endif

IF lDbg
	CLS
ENDIF

oExtra := ku->(ExtraData():New(nKuNr))

IF oExtra:Factoring
   oTiltaApi := RestApi():New()
   oTiltaApi:cBaseUrl := "https://api.tilta.io/v1/"
   oTiltaApi:cApiKeyName := "TILTA"
   hLimit := hb_jsonDecode(oTiltaApi:Execute("buyers/"+LTrim(Str(ku->Nummer))+"/facility","GET",,{"authorization: Bearer $APIKEY$"}))

   //Status der FazilitÑt beachten: bei FROZEN (und den endgÅltigen ZustÑnden) finanziert Tilta
   //nichts Neues, auch wenn available_amount noch einen Betrag ausweist. Dann bleibt es beim
   //bereits offenen Bestand - kein zusÑtzlicher Spielraum, aber auch keine kÅnstliche 0, die
   //jede Bewegung auf den bestehenden Rechnungen blockieren wÅrde.
   cTiltaStatus := __TiltaStatus(hLimit)
   IF lDbg
      ? "Tilta-Status:",IF(Empty(cTiltaStatus),"(nicht geliefert)",cTiltaStatus)
   ENDIF
   //Achtung: AScan vergleicht Zeichenketten mit "=", also nur den Anfang - ein leerer
   //Status wuerde damit auf JEDEN Eintrag passen. Deshalb Codeblock mit "==" und Empty-Pruefung.
   IF ! Empty(cTiltaStatus) ;
      .AND. AScan({"FROZEN","BLOCKED","SUSPENDED","CLOSED","CANCELLED","CANCELED","TERMINATED","REJECTED","EXPIRED","INACTIVE"},{|c| c == cTiltaStatus}) != 0
      hTurnOver := GetCustomerTurnover(ku->kunde)
      IF lDbg
         ? "FazilitÑt nicht nutzbar ("+cTiltaStatus+") - nur der offene Bestand:",LTrim(Transform(hTurnOver["open"],cPic))
      ENDIF
      RETURN hTurnOver["open"]
   ENDIF

   IF HHasKey(hLimit,"available_amount")
      hTurnOver := GetCustomerTurnover(ku->kunde)
      RETURN hLimit["available_amount"]/100+hTurnOver["open"]
   ELSEIF HHasKey(hFactoringLimits,Trim(ku->Kunde))
      RETURN hFactoringLimits[Trim(ku->Kunde)]
   ELSE
      RETURN 0
   ENDIF   
ELSEIf wkv->(dbSeek( Str(nKuNr,6) ))
   If wkv->Blocked
      IF lDbg
         Alert("Durch WKV gesperrt")
      ENDIF
      /*IF Trim(cKunde) == "AER" .AND. Date() <= STOD("20160613")
         //RETURN 1000
      ENDIF*/
      /*IF Trim(cKunde) == "WEITEN"
         nCredLimit := Min(nCredLimit,2500) //auf 2500 (Selbstbehalt) reduzieren, da der Antrag f‰lschlicher Weise gestellt wurde und die R+V keinen Versicherungsschutz ¸bernehmen.
      ELSE*/
      	Return 0
      //ENDIF
   ELSEIf dDate <= wkv->Until .OR. Empty(wkv->Until)
		nWkvCL := wkv->CredLimit
      IF HHasKey(hAddLimit,Trim(cKunde)) .AND. Date() >= hAddLimit[Trim(cKunde)]["FROM"] .AND. Date() <= hAddLimit[Trim(cKunde)]["UNTIL"]
         nWkvCL += hAddLimit[Trim(cKunde)]["ADD"]
      ENDIF
		lWkv   := .T.
      IF lDbg
         ? "Limit von der WKV gefunden:",nWkvCL
      ENDIF
	Endif
ELSE
   IF lDbg
      ? "Kein Limit von der WKV gefunden"
   ENDIF
//   Alert("not found")
Endif

IF lDbg
    ? PadL("Rechnr",6),PadL("Datum",8),PadL(t("F‰llig"),8),PadL("Zahlung",8),Pad("Mahnung",2+1+8),PadL(t("‹ber"),3),PadL("Wert",12),PadL("Gewicht",12)
ENDIF

//collect information about the invoices in the last 12 months
Do While re->Reposnr == 0 .AND. re->Kunde == cKunde .AND. ! re->(Eof())
   If AddMonth(re->rechdat,nMonths) >= dDate
      nWait  := ska->(GetSkontoWait(re->Skonto,re->Rechdat))
      ska->(dbGoto( re->Skonto+1 ))
      IF ska->Ziel1 != -3  //Keine Vorkasse
         dPDate := re->rechdat+nWait
         IF re->Rechnr $ hDisputedInvoices
            dPDate := hDisputedInvoices[re->Rechnr]["UNTIL"]
         ENDIF
         dFinal := AddMonth(dPDate,2) //2 Monate nach F‰lligkeit
         lPaid := re->Code == 3 .OR. re->Status != 0 .OR. re->Poswt <= re->AoQty
         IF re->PosWt > 0  .AND. (lPaid .OR. dPDate+ska->Kulanz <= dDate)
            If  ((lPaid .AND. re->PayDate > dFinal) .OR. (! lPaid .AND. dDate > dFinal)) //Rechnung wurde nicht innerhalb von 2 Monaten bezahlt
               lToLate := .T.
               nToLate := Max(nToLate,IF(Empty(re->Paydate) .OR. ! lPaid,Date(),re->PayDate)-dFinal)
               //nLastReToLate := re->Rechnr
               IF Tr_Getini(28) == 9
   //               Alert("Rechnung "+t( LTrim(Str(re->Rechnr,6))+" zu sp‰t bezahlt. Eingang: "+DToC(re->PayDate)+" Finaltermin: "+DToC(dFinal) )+" "+Str(nToLAte))
               ENDIF
               //Alert(ProcName(6))
               IF ProcName(6) == "(b)TRD_ADDRESS"  //Info in customer window
                  nR := Row()
                  nC := Col()
                  @ 31,03 SAY Pad("Rechnung "+t( LTrim(Str(re->Rechnr,6))+" zu sp‰t bezahlt. Eingang: "+DToC(re->PayDate)+" Finaltermin: "+DToC(dFinal) ),78)
                  SetPos(nR,nC)
               ENDIF
            Endif
            IF lDbg
               ? re->Rechnr,re->rechdat,dPDate,re->payDate,re->rem,re->madate,Str((IF(Empty(re->PayDate),Date(),re->payDate)-dPDate),3),re->poswt,(IF(Empty(re->PayDate),Date(),re->payDate)-dPDate-ska->Kulanz)/Max(nWait+ska->Kulanz,1)*re->PosWt
            ENDIF
            nAvgOvr += (IF(Empty(re->PayDate),Date(),re->payDate)-dPDate-ska->Kulanz)/Max(nWait+ska->Kulanz,1)*re->PosWt
            nPaidOrDueTotal += re->PosWt
            IF lPaid
               nPaidTotal += re->Poswt
            ENDIF
         ENDIF
         IF lPaid
            nTotalPaid += re->poswt //Brutto
         ENDIF
      ENDIF
   ENDIF
   re->(dbSkip())
Enddo

IF nPaidOrDueTotal != 0
   IF lDbg
      ? ""
      ? "Summe Åberschritten :",Str(nAvgOvr,7,2)
      ? "Summe bezahlt       :",Str(nPaidTotal,7,2)
      ? "Summe insgesamt     :",Str(nPaidOrDueTotal,7,2)
      
	ENDIF
	
	nAvgOvr := Round(nAvgOvr/nPaidOrDueTotal,2)

	IF lDbg
		?
		? t("Durchschn. ‹berschreitung:"),Str(nAvgOvr*100,3)+"%"
    ENDIF

ENDIF




IF lWKV .AND. lAuftrag .AND. HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]["DATE"] >= Date()
   nCredLimit := Min(nWKVCL*3,hSpecial[Trim(cKunde)]["LIMIT"])
ELSEIf lWKV //.AND. ! (lAuftrag .AND. HHasKey(hSpecial,Trim(cKunde)))
   nCredLimit := Min(nCredLimit,nWKVCL)      
   IF lDbg		
      ? t("Limit durch die WKV festgelegt:"),Str(nWKVCL)
   ENDIF
ELSEIF Trim(ku->CompForm) == "KOER" .OR. Trim(ku->CompForm) == "STIFT"
   nCredLimit := Max(1000,nCredLimit)
ELSEIF lSimpleCountry .AND. ((nTotalPaid >= 4000 .AND. nCredLimit <= 20000) .OR. (nTotalPaid >= 2500  .AND. nCredLimit <= 10000)) //in diesem Fall brauchen wir keine Kreditauskunft. Da reicht die Zahlungserfahrung	
   nCredLimit := Max(nCredLimit,3000) //min. 3000
   nWKVCL := IF(nTotalPaid >= 4000,20000,IF(nTotalPaid >= 2500,10000,0))
   lWKV := .T.
   IF lDbg		
      ? "Limit durch LÑndervereinfachung:",LTrim(Str(nCredLimit,12,0))
   ENDIF
ELSE
   IF lDbg
      ? "Kein WKV Limit"
   ENDIF
   nRow := Row()
   nCol := Col()


   nOpenOrders := GetCustomerOpenOrders(ku->kunde)
   hTurnOver := GetCustomerTurnover(ku->kunde)

   //IF Tr_Getini(28) == 9
   NetUse("creditsafe","cs")
   aFiles := GetArchiveFiles({"KAM"=>ku->Nummer})

   IF (Len(aFiles) == 0 .OR.  ! cs->(dbSeek( Str(ku->Nummer,6))) .OR. Empty(cs->ID) .OR. ATail(aFiles)[3] < AddMonth(Date(),-12))
      
      IF nOpenOrders > 0 .OR. hTurnover["current"]+hTurnover["last"] > 0 .OR. ProcName(7) != "TRD_ADDRESS" //Abfrage bei Creditsafe nur bei aktiven Kunden oder man befindet sich nicht im Infofenster des Kunden
         
         IF ku->CountryIso == "DE" //kein Eintrag der WKV, Abruf Daten Creditsafe
            
            IF cs->(dbSeek( Str(ku->Nummer,6))) .OR. (! Empty(ku->CompForm) .AND. ! Empty(ku->Compno) .AND. ! Empty(ku->Gericht))
               oSOAP := hb_ExecFromArray({"CreditSafe"})
                    
               IF lDbg
                  ? "Auskunft wird eingeholt (CS-ID: "+Trim(cs->ID)+")"
               ELSE               
                  __TxtBox("Auskunft wird eingeholt...")               
               ENDIF

               IF ! cs->(Found()) .OR. Empty(cs->ID)
                  IF lDbg
                     ? "Suche Unternehmen in CS Datenbank"
                  ENDIF
                  NetUse("gerichte","ger")
                  ger->(dbSeek( ku->CountryIso+Str(ku->Gericht,4) ))
                  oCtr := SOAPParameter():New("countries")
                  oCtr:CreateChild("CountryCode","DE",,"http://schemas.datacontract.org/2004/07/Creditsafe.GlobalData")
   
                  aRegex := HB_Regex("([A-Za-z]{2,3})\s*([0-9][^\s]*[\sA-Za-z]*)",ku->Compno)
                  IF Len(aRegex) >= 3
                     //Alert(aRegex[2]+" "+aRegex[3])
                     oSearch := SOAPParameter():New("searchCriteria",,,"http://www.creditsafe.com/globaldata/operations")
                     oSearch:CreateChild("RegistrationNumber",aRegex[2]+" "+aRegex[3],,"http://www.creditsafe.com/globaldata/datatypes")
                     //oSearch:CreateChild("Address",,,"http://www.creditsafe.com/globaldata/datatypes"):CreateChild("City",StrTran(ger->SimpleName,HB_AnsiToOem("ﬂ"),"ss"),,"http://www.creditsafe.com/globaldata/datatypes")
                     //oSearch:CreateChild("Address",,,"http://www.creditsafe.com/globaldata/datatypes"):CreateChild("City",StrTran(ku->Town,HB_AnsiToOem("ﬂ"),"ss"),,"http://www.creditsafe.com/globaldata/datatypes")

                     oXML := oSOAP:Call("FindCompanies",{oCtr,oSearch})
                     oCompany :=  TXmlIteratorScan():New(oXML:oRoot):Find("Companies"):oChild
                  ENDIF
                  IF oCompany == NIL
                     IF lDbg
                        ? "Keinen Eintrag gefunden"                        
                     ENDIF
                     __TxtBox("Keinen Eintrag gefunden",.T.)
                     nError := 101
                     nCredLimit := 0                     
                     //EXIT
                  ELSEIF oCompany:oNext != NIL //we have at least two entries, then we try and find the correct one
                     //cList := ""
                     
                     DO WHILE oCompany != NIL
                        //cList += TXMLIteratorScan():New(oCompany):Find("Name"):cData+";"
                        IF Lower(StrTran(TXMLIteratorScan():New(oCompany):Find("Name"):cData," ","")) == Lower(StrTran(ku->Name1+ku->Name2," ",""))
                           EXIT
                        ENDIF
                        /*
                     //this needs re -working to compare the registergericht too if that information is in CS                     
                        cRegex  := "[A-Z]{2,3}\s*[0-9]{3,}[\sA-Za-z]*"
                        aRegex1 := HB_Regex(cRegex,Upper(TXMLIteratorScan():New(oCompany):Find("RegistrationNumber"):cData))
                        aRegex2 := HB_Regex(cRegex,Upper(ku->Compno))
                        IF Len(aRegex1) > 0 .AND. Len(aRegex2) > 0 .AND. StrTran(aRegex1[1]," ","") == StrTran(aRegex2[1]," ","")
                           EXIT
                        ELSEIF Tr_Getini(28) == 9
                           IF Len(aRegex1) == 0
                              Alert("Keine Registernummer bei CS")
                           ELSEIF Len(aRegex2) == 0
                              Alert("Keine Registernummer im Trader "+ku->Compno)
                           ELSE
                              Alert("CS: "+StrTran(aRegex1[1]," ","")+";Trader:"+StrTran(aRegex1[2]," ",""))
                           ENDIF
                        ENDIF*/
                        //Alert(TXMLIteratorScan():New(oCompany):Find("RegistrationNumber"):cData)
                        oCompany := oCompany:oNext
                     ENDDO
                     IF ! lDbg
                        TxtClear()
                     ENDIF
                     IF oCompany == NIL
                        IF Tr_Getini(28) == 9
                           //Alert(cList)
                        ENDIF   
                        __TxtBox("Keinen passenden Eintrag gefunden",.T.)
                        nError := 102
                     ELSE
                        cID := oCompany:GetAttribute("Id")
                     ENDIF
                        //__TxtBox("Zu viele Eintr‰ge gefunden!;"+TXMLIteratorScan():New(oCompany):Find("RegistrationNumber"):cData,.T.)
                  ELSE   
                     cID := oCompany:GetAttribute("Id")
                     IF ! lDbg
                        TxtClear()
                     ENDIF
                  ENDIF
               ELSE
                  cID := cs->ID
                  IF ! lDbg .AND. ! GetConfigValue("BATCHMODE")
                     TxtClear()
                  ENDIF
               ENDIF
               
               //IF cs->Kunde == ku->Nummer
               IF cID != NIL
                  oSOAP := hb_ExecFromArray({"CreditSafe"})
                  oReport := HB_ExecFromArray({"CS_GetCompanyReport",oSoap,cID,3})
                  IF oReport == NIL
                     __TxtBox("Fehler beim herunterladen der Auskunft!",.T.)
                     nCredLimit := 1
                  ELSE
                     HB_ExecFromArray({"CS_SaveReport",ku->Nummer,oReport})
                  ENDIF
               ENDIF
               //TxtClear()
            ENDIF
         ENDIF

      ELSE  //Ausland
         //   nCredLimit := 0
//         EXIT
      ENDIF
   ENDIF

   IF (! cs->(dbSeek( Str(ku->Nummer,6))) .OR. Empty(cs->ID))  
      IF lDbg
         ? "Keine CS Auskunft vorhanden"    
      ENDIF
      IF HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date()
         nCredLimit := Min(5000,hSpecial[Trim(cKunde)]["LIMIT"])
      
      ELSEIF ku->CountryIso == "DE"  //nur im Inlad reduzieren
         IF Empty(ku->CompForm)
            __TxtBox("Bitte Rechtsform hinterlegen!",.T.)
            nCredLimit := 0.1
         ELSEIF Empty(ku->Compno)
            nCredLimit := Min(nCredLimit,300)
         ELSE
            nCredLimit := 0.2
         ENDIF
      ELSE
         IF lDbg
            ? "Kein Sonderlimit und nicht aus Deutschland"
         ENDIF
         nCredLimit := 0.3
      ENDIF
   ELSE
      IF lDbg
         ? "Creditsafe wird geprÅft"
      ENDIF
      oReport := HB_ExecFromArray({"CS_GetCompanyReportFromArchive",ku->Nummer})
      IF oReport != NIL
         /*IF  ! cs->(dbSeek( Str(ku->Nummer,6) ))
            cs->(Add_Rec(0))
            cs->Kunde := ku->Nummer
            cs->ID    := oReport:oRoot:oChild:oChild:oChild:GetAttribute("CompanyId")
            cs->(dbUnLock())
         ENDIF*/
         oIter := TXmlIteratorScan():New(oReport:oRoot)
         IF Tr_Getini(28) == 9
            //gtSetClipboard(oReport:oRoot:toString())
         ENDIF
         IF ku->CountryIso == "DE"
            oNode := oIter:Find("DECurrentRating")
            IF oNode != NIL
               nRating := Val(oNode:cData)
            ENDIF
         ELSE
            oNode := oIter:Find("CurrentCreditRating")
            IF oNode != NIL
               oNode := TXmlIteratorScan():New(oNode):Find("CommonValue")
               IF oNode != NIL
                  IF oNode:cData == "A"
                     nRating := 1
                  ELSEIF oNode:cData == "B"
                     nRating := 2
                  ELSEIF oNode:cData == "C"
                     nRating := 3.1 //keine Deckung durch R+V            
                  ELSE
                     nRating := 6
                  ENDIF
               ELSE
                  nRating := 6
               ENDIF
            ENDIF
         ENDIF
         IF oNode != NIL
            //nRating := Val(oNode:cData)
            IF lDbg
               ? "Rating: "+LTrim(Str(nRating,3,1))               
            ENDIF               
            IF nRating >= 5 
               IF (HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date()) .AND. HHasKey(hSpecial[Trim(cKunde)],"IGNORERATING") .AND. hSpecial[Trim(cKunde)]["IGNORERATING"]//es kam schon vor, dass ein Falscheintrag vorlag.
                  nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],1000)
               ELSE                  
                  nCredLimit := 0.5
               ENDIF            
            ELSEIF (nRating >= 3 .OR. nRating == 0) .AND. ! (nAvgOvr <= 0 .AND. nPaidOrDueTotal > 0) //schlechtes Rating und keine gute Zahlungserfahrung               
               IF lDbg
                  ? "Schlechtes Rating (>3) und keine gute Zahlungserfahrung"
               ENDIF
               IF (HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date())
                  nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],IF(lAuftrag.OR.oExtra:AutoMahn,3200,1000))
                  IF lDbg
                     ? "Limit beschrÑnkt auf "+Str(nCredLimit)+" aufgrund von Rating"
                  ENDIF
               ELSEIF oExtra:Automahn .AND. nRating < 3.5 .AND. nAvgOvr <= 0.15                                    
                  nCredLimit := Min(nCredLimit,1500) //max 1500 Euro bis Rating 3.5
                  IF lDbg
                     ? "Automahn und schlechtes Rating (<3.5) und schlechte Zahlungserfahrung -> Limit beschrÑnkt auf "+Str(nCredLimit)
                  ENDIF
               ELSEIF oExtra:Automahn .AND. nRating < 4.5 .AND. nAvgOvr <= 0.15                  
                  nCredLimit := Min(nCredLimit,750)
                  IF lDbg
                     ? "Automahn und schlechtes Rating (<4.5) und schlechte Zahlungserfahrung -> Limit beschrÑnkt auf "+Str(nCredLimit)
                  ENDIF
               ELSE
                  nCredLimit := .5
               ENDIF
            ELSE               
               oIter:Rewind()
               oNode := oIter:Find("CompanyStatus")     
               
               IF oNode != NIL .AND. oNode:GetAttribute("Code") == "Other" .AND. oNode:cData $ {"active","aktiv"} .AND.  HHasKey(hSpecial,Trim(cKunde)) //aktiv aber unbewertet
                  nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],100)
               ELSEIF oNode == NIL .OR. oNode:GetAttribute("Code") != "Active" .OR. (! Empty(oNode:cData) .AND. ! Lower(oNode:cData) $ {"active","aktiv","aktive firma","active company","in activity","economically active"})
                  nCredLimit := -2
               ELSEIF nRating < 3  //Deckung durch die R+V
                  IF nRating < 2
                     nCredLimit := Max(nCredLimit,3000) //min 3000
                  ELSEIF nRating <= 2.5
                     nCredLimit := Max(nCredLimit,2000) //min 2000
                  ELSE
                     nCredLimit := Max(nCredLimit,1000) //default to 1000 Euros in Germany
                  ENDIF
                  
                  nCredLimit := Min(nCredLimit,20000)

                  IF lDbg
                     ? "Bewertung anhand Rating: "+LTrim(Transform(nCredLimit,cPic))
                  ENDIF

               ELSEIF HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date()                      
                  nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],IF(lAuftrag,5000,3000))
               ELSEIF ! oExtra:Factoring //keine R+V Deckung, dann aufgrund positive Zahlungserfahrung bewerten                  
                  //bewerten das nur nach Zahlungserfahrung
                  IF lDbg
                     ? "Keine Deckung durch die WKV. Bewertung nach Zahlungserfahrung."
                  ENDIF
                  /*nCredLimit := Min(nCredLimit,1000-(nRating-2.9)*10*100) 
                  IF nAvgOvr <= -0.4 //zahlt mit skonto, max 2700                     
                     nCredLimit := Max( Min(nCredLimit*3,nPaidTotal), nCredLimit*1.5 )
                  ELSEIF nAvgOvr <= 0 //zahlt p¸nktlich oder ist auf Factoring gestellt  
                     nCredLimit := Max( Min(nCredLimit*2,nPaidTotal/2), nCredLimit )
                  ENDIF*/
                  IF nAvgOvr <= -0.4 //zahlt mit skonto
                     IF lDbg
                        ? "Zahlt mit Skonto. Limit: ",nPaidTotal*4
                     ENDIF
                     nCredLimit := Min(3000,nPaidTotal*4)
                     Aadd(aOverrideMax,Trim(cKunde)) //In this case we will ignore the max. level set by CS
                  ELSEIF nAvgOvr <= 0 //zahlt p¸nktlich
                     IF lDbg
                        ? "Zahlt pÅnktlich ("+LTrim(Str(nPaidOrDueTotal,12,2))+"EUR) -> Maximales Limit:",Ltrim(Str(nPaidTotal*2)),", hîchstens: 2000"
                     ENDIF
                     nCredLimit := Min(nCredLimit,Min(2000,nPaidTotal*2))
                  ELSE
                     ? "Zahlungserfahrung nicht gut"
                  ENDIF
               ENDIF

               IF AScan(aOverrideMax,Trim(cKunde)) != 0  .AND. nAvgOvr <= 0 .AND. nPaidOrDueTotal > 0 //ignore the maximum on these customers  as long as they pay punctual

               ELSE
                  oNode := oIter:Find("CreditLimit")
                  IF lDbg
                     ? "CS Limit:",Ltrim(Transform(Val(oNode:cData),cPic))
                  ENDIF
                  IF oNode != NIL
                     IF Trim(cKunde) $ hMultiMax .AND. nAvgOvr <= 0.25 //these customers get a multiple of the CS level
                        nCredLimit := Min(nCredLimit,Val(oNode:cData)*Min(hMultiMax[Trim(cKunde)],4))
                     ELSEIF Val(oNode:cData) == 0  .AND. HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]["DATE"] >= Date() //no rating, and special limit set
                        nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],IF(oExtra:AutoMahn,3200,1500))
                     ELSE
                        nCredLimit := Min(nCredLimit,Val(oNode:cData))
                     ENDIF
                  ELSE
                     nCredLimit := -3
                  ENDIF
               ENDIF

            ENDIF
         ELSE
            nCredLimit := -4 
         ENDIF
         IF lDbg		
            ? t("Limit durch Bewertung:"),LTrim(Transform(nCredLimit,cPic))
         ENDIF
      ENDIF
   ENDIF
   


   //SetPos(nRow,nCol)

   //ENDIF
ENDIF

//IF lDbg; Alert("AFTER CS "+Str(nCredLimit)+Str(nWKVCL)); ENDIF

nMaxDeckung := Min(nCredLimit,40*nNettoBeitrag/0.9)
IF HHAsKey(hSpecialWKV,Trim(cKunde))
   nMaxDeckung := hSpecialWKV[Trim(cKunde)]
ENDIF



IF nMaxDeckung < nCredLimit   
   IF lAuftrag .AND. HHasKey(hBigCustomer,Trim(cKunde)) //.AND. hSpecial[Trim(cKunde)]["DATE"] < Date()
      nCredLimit := Min(nCredLimit,hBigCustomer[Trim(cKunde)])
   ELSE
      IF lDbg
         ? "Max. Deckung durch R+V:",LTrim(Transform(nMaxDeckung,cPic))
      ENDIF
      nCredLimit := nMaxDeckung //Deckung = 20x Grunddeckungbetrag zzgl 30% Selbstbeteiligung
   ENDIF
ENDIF

If Trim(cKunde) == "JANNIS"
	Return 2000
Endif

ku->(dbSetOrder( 8 ))
ku->(dbSeek( Str(nKuNr,6) ))
ska->(dbGoto( ku->Skonto+1 ))



IF ska->Ziel1 != -2 .AND. nAvgOvr >= 0.25  //Zahlt verspÑtet, 25% Åberschreitung erlaubt, 03.02.25 ! lWKV enntfernt //.AND. ! lWKV //.AND. ! oExtra:Factoring
      IF ! HHasKey(hSpecial,Trim(cKunde)) .OR. hSpecial[Trim(cKunde)]:Date < Date()
         IF nAvgOvr >= 0.80                        
            nCredLimit := Min(nCredLimit,200)
         ELSEIF nAvgOvr >= 0.60            
            nCredLimit := Min(nCredLimit,Max(nPaidTotal*1/8,300))
         ELSEIF nAvgOvr >= 0.40
            nCredLimit := Min(nCredLimit,Max(nPaidTotal*1/4,500))
         ELSEIF nAvgOvr >= 0.25
            nCredLimit := Min(nCredLimit,Max(nPaidTotal*1/2,750))
         ENDIF
         IF lDbg
            IF HHasKey(hSpecial,Trim(cKunde))
               ? "Sonderlimit abgelaufen am",DToC(hSpecial[Trim(cKunde)]:Date)
            ENDIF            
            ? "Kunde zahlt verzîgert, Reduzierung des Creditlimits auf ",LTrim(Transform(nCredLimit,cPic))
         ENDIF
      ELSEIF ! lAuftrag         
         nCredLimit := Min(hSpecial[Trim(cKunde)]:Limit,IF(! lWKV,10000,nWkvCL))
         IF lDbg
            ? "Sonderlimit: ",LTrim(Transform(hSpecial[Trim(cKunde)]:Limit,cPic))            
            IF hSpecial[Trim(cKunde)]:Limit > nCredLimit
               ? " beschrÑnkt auf: ",LTrim(Transform(nCredLimit,cPic))
               IF lWKV
                  ?? " durch WKV Limit: ",LTrim(Transform(nWkvCL,cPic))
               ENDIF
            ENDIF
         ENDIF
      ENDIF
ENDIF

IF HHAsKey(hMaxLimit,Trim(cKunde))
   nCredLimit := Min(nCredLimit,hMaxLimit[Trim(cKunde)])
   IF lDbg
      ? "Max. Limit durch interne BeschrÑnkung: ",LTrim(Transform(nCredLimit,cPic))
   ENDIF
ENDIF

IF lDbg   
   ? "Kreditlimit: "+LTrim(Transform(nCredLimit,cPic))
   DO WHILE SInkey(0,128) == 32
   ENDDO
   RestScreen(,,,,cScr)
   SetPos(nRow,nCol)
ENDIF


If lToLate //one invoice was paid to late
   IF lDbg
      Alert( "Kunde hat zu spÑt bezahlt. Limit wird reduziert." )
   ENDIF
   If nToLate <= 15 //small credit limit for 15 further days
		If ska->Ziel1 == -2 //bankeinzug
			Return 500
		ELSEIF  HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date()
        RETURN Min(1500,hSpecial[Trim(cKunde)]:Limit)
      Endif
   ELSEIF HHasKey(hSpecial,Trim(cKunde)) .AND. HHasKey(hSpecial[Trim(cKunde)],"TOLATE") .AND. hSpecial[Trim(cKunde)]["TOLATE"]
      RETURN Min(500,hSpecial[Trim(cKunde)]:Limit)
    ELSEIF oExtra:Factoring //if he paid to late and we change him to factoring, then we will allow a small amount
      RETURN 250
	Endif
	Return -6  //no credit
Elseif ! lSimpleCountry .AND. ! lMoreCountry .AND. !lWKV
   //IF Tr_Getini(28) == 9; Alert("Country: "+ku->CountryIso); Endif
   IF lDbg
      Alert( "Kein Schutz fÅr dieses Land vorhanden." )      
   ENDIF
   IF  HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date() 
      RETURN Min(500,hSpecial[Trim(cKunde)]:Limit)
   ENDIF
	Return -5 //country has no protection
Elseif lWKV
	Return nCredLimit
ELSEIF lSimpleCountry //ku->CountryIso $ {"DE","AT","LI","FR","HR"} //Abfrage Creditsafe
   RETURN nCredLimit
ELSEIF nTotalPaid < 2500 //unter selbstbehalt

    IF HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date()
      //Return hSpecial[Trim(cKunde)]:Limit
    	Return Min(hSpecial[Trim(cKunde)]:Limit,3000)
    ENDIF

  	Return Min(nCredLimit,3000)  //Min 1000, Max 3000 Euro Limit

ELSEIF lSimpleCountry .AND. nTotalPaid >= 4000
	Return Min(nCredLimit,20000)
ELSEIF lSimpleCountry .AND. nTotalPaid >= 2500  //more than 2500 Euros turnover
	Return Min(nCredLimit,10000)
Endif

IF lDbg; Alert("NO LIMIT?"); ENDIF

Return 0

/*  Status der Tilta-FazilitÑt aus der Antwort ziehen. Tilta liefert ihn auf oberster Ebene;
 *  die verschachtelten Varianten sind Vorsorge, falls die API das Objekt einpackt.
 *  Rueckgabe "" wenn kein Status geliefert wird - dann gilt wie bisher available_amount.  */
STATIC FUNCTION __TiltaStatus(hLimit)
   LOCAL cStatus := ""
   LOCAL cWrap
   IF ValType(hLimit) != "H"
      RETURN ""
   ENDIF
   IF HHasKey(hLimit,"status") .AND. ValType(hLimit["status"]) == "C"
      cStatus := hLimit["status"]
   ELSE
      FOR EACH cWrap IN {"facility","data"}
         IF HHasKey(hLimit,cWrap) .AND. ValType(hLimit[cWrap]) == "H" ;
            .AND. HHasKey(hLimit[cWrap],"status") .AND. ValType(hLimit[cWrap]["status"]) == "C"
            cStatus := hLimit[cWrap]["status"]
            EXIT
         ENDIF
      NEXT
   ENDIF
RETURN Upper(AllTrim(cStatus))

STATIC Function __TxtBox(cTxt,lWait)
   IF ! GetConfigValue("BATCHMODE")
      TxtBox(t(cTxt))
      IF lWait == .T.
         Inkey(1,128)
         TxtClear()
      ENDIF
   ENDIF
RETURN NIL

//#include 'X:\run\creditsafe.prg'
