FUNCTION Get_CustomerCreditlimit(nKuNr,cKunde,nCredLimit)

LOCAL nMonths := 12
//LOCAL lDbg := Inkey() == 32 .AND. Tr_Getini(28) == 9 .AND. ProcName(6) == "TRD_02"
LOCAL lDbg := .F.
LOCAL nRating
LOCAL hSpecial,hBigCustomer
LOCAL nTotalPaid,nAvgOvr,nPaidOrDueTotal,nPaidTotal
LOCAL aOverrideMax := {}
LOCAL cID
LOCAL aRegex1,aRegex2,cRegex
LOCAL hMultiMax := {=>}
LOCAL nNettoBeitrag,dBeitragBis
LOCAL lAuftrag := ProcName(6) $ "ENGAUFT AUFCHECKCREDITLIMIT"
LOCAL cSCR,nRow,nCol
LOCAL aInsolv,dDate,lToLate,nWKVCL,nToLAte,nWait,lWKV,lSimpleCountry,lMoreCountry
LOCAL dPDate,dFinal,lPaid,nR,nC,aFiles,nOpenOrders,hTurnover,oSOAP
LOCAL oCtr,oSearch,oXML,oCompany,oReport,oIter,oNode,nMaxDeckung
LOCAL oExtra
LOCAL aRegex

MEMVAR mlShowInvoiceList
PUBLIC mlShowInvoiceList


IF Trim(ku->Kunde) == "SIGNALSZ"
RETURN 1500
ENDIF

IF Tr_Getini(28) == 9   
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

    nNettoBeitrag := 11844.02 //12511.50 //10879.57 //9460.49 //10766.35 //8610.54
    dBeitragBis   := CToD("31.12.2020")

    aInsolv := {"CPL"}


    hSpecial := {=>}

   IF lAuftrag      
      hSpecial["AMANNGIR"]    := {"DATE"=>StoD("20191231"), "LIMIT"=>11000} //nach RÅcksprache mit dem Kunden ist die schlechte Zahlungsweise durch eine verzîgerte Freigabe durch den EK bedingt, daher auf 30T gesesetzt und verlÑngert //03.08.18 zahlt schlecht, daher nur fÅr Abrufe
      hSpecial["WEITEN"] := {"DATE"=>StoD("20181231"), "LIMIT"=>7200} //15.08.18 Zahl nicht konstant - daher Limit nur fÅr AuftrÑge //21.07.16 800Ä f¸r einen Abruf //19.07.16 Hat 1. Rechnung sp‰t bezahlt, Kurzfristiges CL (7000) um einen Rahmen  einzugeben (mit geringen Mindestbest‰nden!)
      hSpecial["VYRIAN"] :=  {"DATE"=>SToD("20200630"),"LIMIT"=>39999} //17.12.19 Bekommen nur 20k von der R+V      
      hSpecial["VERPATEC"] :=  {"DATE"=>SToD("20200630"),"LIMIT"=>250000} //31.03.20 Ist ein Rahmen, bekommen nur 100.000 von R+V
      hSpecial["RMECABLE"] := {"DATE"=>SToD("20201230"),"LIMIT"=>4000} //02.06.2020 zahlt immer erst nach 1. Mahnung, daher nur Auftragslimit
   ENDIF   

    hSpecial["WANTEC"]   := {"DATE"=>SToD("20201231"),"LIMIT"=>IF(lAuftrag,3000,760)}  //15.05.20 brauch jetzt auch zur Auslieferung eine hîheres Limit. //13.05.20 Neuer Rahmen, daher verlÑngert aber auf 3000 reduziert //16.04.19 brauchen das Limit fÅr einen Rahmen, der ist sehr schlampig beim bezahlen der Rechnungen //19.03.18 verl‰ngert //19.10. auf 3300 erhˆht //12.10.17 Verl‰ngerung und Erhˆhung auf 2900, letzten beiden Rechnungen wurden mit Skonto bezahlt //06.07.17 Erhˆhung auf 2120 von 1800 //13.03.17 kurzeitige Erhˆhung um einen Rahmen einzugeben. //18.01.17 nicht in CS gelistet daher nur 300Ä //06.09.16 Erhˆhung um 40Ä auf 2380
    hSpecial["HOFRAT"]   := {"DATE"=>StoD("20211231"), "LIMIT"=>500} //ich zahl das immer sofort!   
    hSpecial["TILLYTA"]  := {"DATE"=>StoD("20190430"), "LIMIT"=>12500} //12.11.18 öber Factoring wird pÅnktlich bezahlt, erhîhung auf 12,5K //5.6.18 Werden das zukÅnftig Åber Factoring abwickeln, die haben ein Limit von 10.000 eingerÑumt //16.04.18 schwieriger Kunde, zahlt sehr unp¸nktlich und dadruch ist das KL der Versicherung gestrichen.
    hSpecial["HANSEYAC"]    := {"DATE"=>StoD("20191231"), "LIMIT"=>IF(lAuftrag,25000,13000)} //16.04.19 Nach RÅcksprache mit Sigi das KL auf 13000? angehoben, der Kunde zahlt immer wenn sie Herrn Elmenhorst kontaktier //08.11.18 Auftragslimit auf 25k erhîht //27.07.18 Zahlt erst nach merhfacher Mahnung. Factoring keine Lîsung, da fas Limit hauptsÑchlich fÅr AuftrÑge und nicht fÅr die Rechnungen selbst benîtigt wird
    hSpecial["EDB"] := {"DATE"=>StoD("20191230"), "LIMIT"=>2200} //13.02.19 verlÑngert, weiterhin Factoring //16.10.18 Rating 3.5 daher Factoring
    hSpecial["IST"]      := {"DATE"=>StoD("20191231"), "LIMIT"=>1300} //23.11.18 dto. //3.4.18 dto. //16.01.18 weiterhin so //18.04.17 dto. //Rating 3.5, zahlt aber immer mit Skonto
    hSpecial["HOTEC"] := {"DATE"=>StoD("20190530"), "LIMIT"=>1700} //18.02.19 verlÑngert //Hatte anscheinend Scheck geschickt. Hat aber dann nach der Mahnung noch ca. 20 Tage gebraucht um zu zahlen.
    hSpecial["ELEPROM"] := {"DATE"=>StoD("20190330"),"LIMIT"=>2800} //Hatte die Rechnung nicht bekommen, da diese an eine falsche Email Adresse ginf
    hSpecial["ALSJENA"] := {"DATE"=>StoD("20190330"),"LIMIT"=>500} //Da stimmt was bei der Auskunft nicht. Da ist ein schwebendes Verfahren eingetragen - ist aber keines im HR. Leider akzeptiert Trader nicht mehr als  110?
    hSpecial["FRAUNHOD"] := {"DATE"=>StoD("20201231"),"LIMIT"=>662} //10.07.20 verlÑngert //05.05.20 verlÑngert //Anstalt des îffentlichen Rechts, daher keine Kreditbewertung
    hSpecial["WHTECH"]   := {"DATE"=>StoD("20191231"), "LIMIT"=>300} //14.03.19 Ziehen wir immer von den Rechnungen ab //28.07.16 wenn der weiterhin nicht zahlt, ziehen wir das von den Rechnungen ab!
    hSpecial["MIMMöLLE"]   := {"DATE"=>StoD("20190630"), "LIMIT"=>750} //01.04.19 Hat in der Vergangenheit immer mit Skonto bezahlt
    hSpecial["BR-ELEKT"]   := {"DATE"=>StoD("20190530"), "LIMIT"=>1300} //05.04.19 Zahlt immer mit Skonto.
    hSpecial["MEMOMAT"]   := {"DATE"=>StoD("20200330"), "LIMIT"=>200} //17.03.20 auslieferung des letzten Abrufs aus dem Rahmen von Jan 18, letzte Rechnung erst nach 3. Mahnung gezahlt //20.04.19 Hat endlich einen Abruf aus seinem Rahmen getÑtigt. Hat in der Vergangenheit immer nach der 1. Mahnung bezahlt.
    hSpecial["AIRSOE"]   := {"DATE"=>StoD("20190630"), "LIMIT"=>300} //Rating liegt bei 3.6 - letztes Jahr hat er aber noch mit Skonto bezahlt. 
    hSpecial["TECHNOGR"]   := {"DATE"=>StoD("20190630"), "LIMIT"=>2000} //29.04.19 Lieferant von Gessmann
    hSpecial["SEMEX"]   := {"DATE"=>StoD("20190730"), "LIMIT"=>420} //06.05.19 Rating 3.6, Kunde will woanders kaufen, wenn wir nicht auf Rechnung liefern. Auf Factoring umgestellt. 
    hSpecial["S-CORDS"]   := {"DATE"=>StoD("20200830"), "LIMIT"=>3500} //18.06.20 VerlÑngert und auf 3500,- erhîht, zahlt immer pktl. //05.11.19 VerlÑngert und auf 2000 erhîht // hat bereits 3 Lieferungen per Vorkasse bezahlt. Nich in CS gelistet
    hSpecial["SBB"]    := {"DATE"=>SToD("20200330"),"LIMIT"=>4200}  //05.02.20 Nach Hinterlegung von einem BH Kontakt KL wieder freigeschalten. //22.05.19 Bei der öberschreitung lohnt keine Anfrage bei Creditsafe //2015 war zu blˆd die letzte Rechnung zu bezahlen, Sigi schickt n‰chstes mal eine Atombombe, 19.08. auf 30 Tage umgestellt
    hSpecial["AQUAMETR"] := {"DATE"=>StoD("20190731"), "LIMIT"=>600} //27.05.19 2017 sehr pÅnktlich bezahlt //09.05.17 bisher auf Vorkasse, ist aber bei CreditSafe nicht gelistet
    hSpecial["VITRONIW"] := {"DATE"=>StoD("20190731"), "LIMIT"=>800} //12.06.19 Zahlt immer nach der 1. Mahnung, diese sollten wir schneller versenden
    hSpecial["OTTMESS"] := {"DATE"=>StoD("20191030"), "LIMIT"=>1730} //23.07.19 Kunde hatte Åbersehen, dass wir mit 14 Tagen berechnet hatten (Warum auch immer).     
    hSpecial["BROSEBAM"] := {"DATE"=>StoD("20191030"), "LIMIT"=>400,"TOLATE"=>.T.} //24.07.19 Rechnung ging an die falsche Email Adresse. Kunde ist KONZERN
    hSpecial["GEAFOOD"] := {"DATE"=>StoD("20200630"), "LIMIT"=>1200} //19.11.19 verlÑngert //26.07.19 Rechnung ging an falsche Adresse, daher wurde die Rechnung zu spÑt bezahlt. 
    hSpecial["STEIERMA"] := {"DATE"=>StoD("20191230"), "LIMIT"=>180000} //18.11.19 verlÑngert //30.07.19 Zahlt schlecht - ist aber durch WKV gedeckt.
    hSpecial["CABEX"] := {"DATE"=>SToD("20191231"),"LIMIT"=>500} //05.09.19 Zahlt immer erst nach 30 Tagen obwohl der 14 Tage steht. Werde das ZZ eebenfalls anpassen
    hSpecial["MEDTRONI"] := {"DATE"=>SToD("20191231"),"LIMIT"=>100} //11.9.19 wegen schlechten Rating, hat aber in der Vergangenheit auch schlecht bezahlt
    hSpecial["SIELAFF"] := {"DATE"=>SToD("20191231"),"LIMIT"=>600} //17.9.19 hat erste Rechnung direkt nach der 1. Mahnung bezahlt
    hSpecial["BRUEGGEN"] := {"DATE"=>SToD("20191231"),"LIMIT"=>2000} //30.09.19 sehr schlechtes Rating (4.4), zahlt aber immer mit Skonto
   hSpecial["WôLFLEKA"] :=  {"DATE"=>SToD("20200630"),"LIMIT"=>200} //10.02.20 verlÑngert, zahlt weiterhin mit Skonto //11.10.19 Rating schlecht, zahlt aber immer mit Skonto
   hSpecial["CAMBRAS"] :=  {"DATE"=>SToD("20191231"),"LIMIT"=>550} //14.10.19 Rating sehr schlecht (4.4), daher auf Faktoring gestellt
   hSpecial["MOODROOM"] :=  {"DATE"=>SToD("20191231"),"LIMIT"=>550} //14.10.19 Rating schlecht (3.9) hatte aber letztes Mal innerhalb von 7 Tagen gezahlt (mit Skonto)
   hSpecial["IT4YOU"] :=  {"DATE"=>SToD("20191231"),"LIMIT"=>600} //18.10.19 Sehr schlechtes Rating (4.3)
   hSpecial["KRONEFAH"] :=  {"DATE"=>SToD("20201231"),"LIMIT"=>200} //06.05.20 verlÑngert, Rating weiterhin 3.6 //21.10.19 schlechtes Rating (3.6), zahlt aber mit Skonto
   hSpecial["SEDLBAU"] :=  {"DATE"=>SToD("20191231"),"LIMIT"=>1500} //05.11.19 schlechtes Rating (3.4), zahlt meistens mit Skonto
   hSpecial["ENDLERKU"] :=  {"DATE"=>SToD("20191231"),"LIMIT"=>3000} //05.11.19 schlechtes Rating (3.2), zahlt mit Skonto
   hSpecial["SELKA"] :=  {"DATE"=>SToD("20201231"),"LIMIT"=>989} //03.02.20 Rating auf 3.5 verbessert, verlÑngert //26.11.19 Rating 3.7 - zahlt immer pÅnktlich
   hSpecial["JMO"] :=  {"DATE"=>SToD("20200630"),"LIMIT"=>1999} //Hatte Anfang des Jahres Zahlungsschwierigkeiten, hat sich aber gemeldet und in Teilen gezahlt //09.12.19 Hat direkt nach der 1. Mahnung gezahlt (diese wurde sehr spÑt versendet)
   hSpecial["FBI"] :=  {"DATE"=>SToD("20191231"),"LIMIT"=>659} //10.12.19 Letzte Rechnung wurde direkt nach der ersten Mahnung beglichen, hat kein Rating bei CS mehr da die GmbH (war zuvor OHG) zu jung
   hSpecial["21UNITY"] :=  {"DATE"=>SToD("20200630"),"LIMIT"=>100} //17.12.19 Hat 2018 mit Skonto bezahlt, Rating liegt aber bei 4.6
   hSpecial["SIGNALSZ"] :=  {"DATE"=>SToD("20200630"),"LIMIT"=>200} //wird bei der PI abgezogen
   hSpecial["CS-INST"] :=  {"DATE"=>SToD("20201231"),"LIMIT"=>700} //19.12.19 zahlt immer mit Skonto, Rating: 3.4
   hSpecial["BRAUNO"] :=  {"DATE"=>SToD("20201231"),"LIMIT"=>1000} //05.02.20 Hat eine Rechnung erst nach der Mahnung bezahlt. Die nÑchste aber mit Skonto
   hSpecial["DETERDIN"] :=  {"DATE"=>SToD("20200210"),"LIMIT"=>1000} //10.02.20 Wegen Rechnungskorrektur, Rating hat sich wohl verschlechtert
   hSpecial["ZEITZ"]  :=  {"DATE"=>SToD("20200228"),"LIMIT"=>600} //Wurde 2015 auf Rechnung umgestellt, wollen Ihn nicht wieder zurÅckstellen.
   hSpecial["B+SGRO·"]  :=  {"DATE"=>SToD("20200330"),"LIMIT"=>800} //Rating 3.3
   hSpecial["RTB"]  :=  {"DATE"=>SToD("20200630"),"LIMIT"=>2001} //19.02.20 Rating 3.3, haben aber in der Vergangenheit (2018) pkt. bezahlt.
   hSpecial["IHTB"]  :=  {"DATE"=>SToD("20200730"),"LIMIT"=>1999} //25.06.20 verlÑngert, hatte Åbersehen de Rechnung zu bezahlen (anscheinend aufgrund von Corona) //20.02.20 Einzelfirma daher keine Auskunft
   hSpecial["FORSCHNE"]  :=  {"DATE"=>SToD("20200530"),"LIMIT"=>600} //02.03.20 hat eine Rechnung sehr spÑt bezahlt. Da scheint es aber ein Problem gegeben zu haben - es wurde nÑmlich nicht gemahnt
   hSpecial["ELEMENTO"]  :=  {"DATE"=>SToD("20200630"),"LIMIT"=>600} //17.03.20 Kunde hat erst nach 2. Mahnung gezahlt. Mahnungen wurden aber erst spÑt verschickt.
   hSpecial["PROBEAM"]  :=  {"DATE"=>SToD("20200630"),"LIMIT"=>550} //23.03.20 Schlechtes Rating (4.0) erhîhung um 20 EUR
   hSpecial["EMSREGEN"] :=  {"DATE"=>SToD("20200730"),"LIMIT"=>1000} //06.07.20 VerlÑngert //23.03.20 Schlechtes Rating (4.0), hatte aber in der Vergangenheit entweder mit Skonto oder pktl. bezahlt. Keine neuen GrÅnde in der BoniAuskunft die auf eine Verschlechterung hindeuten 
   hSpecial["SMAE"] :=  {"DATE"=>SToD("20200630"),"LIMIT"=>100} //25.03.19 Schlechtes Rating, zahlt auch nicht besonders gut, aber nur ein kleiner Betrag
   hSpecial["MIESEN"]   := {"DATE"=>SToD("20200630"),"LIMIT"=>1100} //17.04.20 um 100? erhîht //25.03.20 Seit 2016 nicht notwendig. Erhîhung des KL von 750 auf 1000 //19.10.16 Kurzfristig angehoben um eine kleine Auslieferung mit 150Ä vor zu nehmen und einen neune Auftrag einzugeben //Rating nun 3.4 weiterhin Mahnung nˆtig, Erhˆhung um 260Ä //18.05.16 wieder zwei Rechnungen nach erster bzw. zweiter Mahnung bezahlt, Erhˆhung um 200Ä //erste Rechnung zu sp‰t bezahlt, werden in zukunft enger mahnen; letzten zwei Rechungen pktl. bezahlt (21.7.15)
   hSpecial["AUTOPARK"]   := {"DATE"=>SToD("20200630"),"LIMIT"=>60} //01.04.20 schlechtes Rating, kleiner Betrag
   //hSpecial["FAFNIR"]   := {"DATE"=>SToD("20200430"),"LIMIT"=>25000} //01.04.20 Diffreenz zwischen Rechnung und Gutschrift (Fracht) verspÑtet gezahlt
   hSpecial["235MEDIA"] := {"DATE"=>StoD("2h0200630"), "LIMIT"=>95} //Rating schlecht 4.1, kleiner Betrag und haben in der Vergangenheit (bis Feb. 2019) immer mit Skonto gezahlt
   hSpecial["M+E"] := {"DATE"=>StoD("20200630"), "LIMIT"=>180} //Rating 4.0, hat aber fast immer mit Skonto bezahlt
   hSpecial["URBANGMB"] := {"DATE"=>StoD("20200630"), "LIMIT"=>250} //Rating 3.5, zahlt aber immer mit skonto
   hSpecial["BATTERYD"] := {"DATE"=>StoD("20200630"), "LIMIT"=>150} //
   hSpecial["PROVENDO"] := {"DATE"=>StoD("20200630"), "LIMIT"=>562} //25.05.20 auf 562 erhîht (um weitere 22?) //29.04.20 Rating 4.0 steht auf Factoring, Erhîhung um 40?
   hSpecial["SCEMTEC"] := {"DATE"=>StoD("20200630"), "LIMIT"=>1600} //07.05.20 Rating 3.2 zahlt aber immer mit Skonto
   hSpecial["ISAINDUS"] := {"DATE"=>SToD("20200630"),"LIMIT"=>631}  //12.05.20 auf 631 erhîht //08.05.20 Steht inzwischen auf Factoring. Limit von 500 auf 620 erhîht //29.03.17 Zahˆlungsmoral gleich geblieben, braucht weiterhin eine Mahnung //27.09.16 um 200Ä erhˆht, Zahlungsmoral verschlechtert sich
   hSpecial["WEITER"] := {"DATE"=>SToD("20200830"),"LIMIT"=>1363}  //25.06.20 Limit um letzten Abruf einzutragen
   hSpecial["WIDU"] := {"DATE"=>SToD("20200830"),"LIMIT"=>540}  //25.06.20 Hatte frÅher schonmal auf Rechnung, kînnen das schlecht Ñndern
   hSpecial["KSF"] := {"DATE"=>SToD("20200830"),"LIMIT"=>1300}  //29.06.20 War bereits auf Zahlungszziel, hat frÅher mit Skonto bezahlt. Rating liegt bei 3,1. Test Auskunft von Creditrefrom liegt bei 1,85
   hSpecial["STAYONLI"] := {"DATE"=>SToD("20200930"),"LIMIT"=>3999} //31.07.20 VerlÑngert und auf 3999 erhîht //10.07.20 zahlt fast pktl., eine Auskunft lohn sich nicht
   hSpecial["KACON"]    := {"DATE"=>StoD("20201030"), "LIMIT"=>IF(lAuftrag,35000,13500)} //13.07.20 Bisher hat das Limit gereicht (seit 31.12.18). Aufgrund von Corona wurde die letzte Rechnung sehr spÑt bezahlt. Daher Erhîhung von 8.4 aud 13.5k //06.08. Auftragslimit auf 35k //09.07.18 Limit wieder auf 20k, haben ein lÑngeres Zahlungsziel vereinbart, sollte dadurch nicht mehr zu öberschreitungen kommen
   hSpecial["AMBERPRO"]    := {"DATE"=>StoD("20201030"), "LIMIT"=>2990} //20.07.20 hatte letztes Jahr ein Limit von 10k von der R+V. Rating ist aufgrund der Einzelfirma schlecht.
   hSpecial["PROCOM"]    := {"DATE"=>StoD("20201030"), "LIMIT"=>300} //29.07.20 Zahlt immer mit Skonto, Rating 4.0
   hSpecial["EYETI"]    := {"DATE"=>StoD("20201030"), "LIMIT"=>3000} //30.07.20 schlechtes Rating - Factoring
   hSpecial["SPEEDY"]    := {"DATE"=>StoD("20201031"), "LIMIT"=>1000} //31.07.20 schlechtes Rating - Factoring

   //Auftragslimits fÅr gro·e Kunden, diese gelten wenn der Kunde die volle Deckung bei der Versicherung haben
    hBigCustomer := {=>}
    hBigCustomer["FRANKE"]   := 241000
    hBigCustomer["STEIERMA"] := 390000
    //hBigCustomer["SCHNEIDG"] := 208000 //berechnetes Fabrikationsrisiko ca. 147 TEUR. 
    hBigCustomer["RMWKABEL"] := 400000 

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
    Aadd(aOverrideMax,"CLEVERCI") //zahlt immer mit skonto
    Aadd(aOverrideMax,"EFBELEK") //zahlt immer mit skonto
    Aadd(aOverrideMax,"HERING") //zahlt immer mit skonto
    Aadd(aOverrideMax,"WENGLOR") //zahlt immer mit skonto    
    Aadd(aOverrideMax,"CARSTECH") //zahlt immer ÅberpÅnktlich
    Aadd(aOverrideMax,"BILZ") //zahlt immer ÅberpÅnktlich
    //

//    Aadd(aOverrideMax,"BUTZ") //zahlt immer mit skonto

    //Bei diesen Kunden ist ein generelles ‹berschreiten des CS Limits nicht mˆglich, daher nur ein Mehrfaches (zahlen nicht immer p¸nktlich), max 3x
    hMultiMax["EDEKA"] := 4.5
    hMultiMax["TILLYTA"] := 1.75
    hMultiMax["KOCO"] := 2.6
    hMultiMax["BECOMGIL"] := 3
    hMultiMax["SONEPARE"] := 1.5
    hMultiMax[HB_AnsiToOem("G÷LZ")] := 2
    hMultiMax["WEITER"] := 1.8
    hMultiMax["WANTEC"] := 1.8
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
    //hMultiMax["MIESEN"] := 1.1
   
    
    IF lAuftrag
      hMultiMax["MEDAQUA"] := 2 //19.02.19 Limit fÅr Rahmenauftrag. CS limitiert das auf 2500?            
    ENDIF

//    hMultiMax["EIB"] := 1.65

    //hMultiMax["SCHORF"] := 3.0

    //hSpecial["RKB"]      := {"DATE"=>StoD("20171231"), "LIMIT"=>1450} //26.10.17 Letzte Rechnung mit Skonto bezahlt, Rating weiterhin schlecht //07.09.17 hat nach Insolvenz nur ein Rating von 4.5
    //hSpecial["CPL"]      := {"DATE"=>SToD("20180630"),"LIMIT"=>IF(lAuftrag,4500,1000)} //06.04.18 Aufrragslimit auf 4500 und Rechnung auf 1000 gesetzt //07.12.16 das gleiche mit den n‰chsten Abrufen //27.06.16 Schein hat getr¸gt. Kurzfristiger KL f¸r Rahmen und wieder auf 1000Ä erhˆht. H¸gler mitgeteilt, dass bereits nach der 1. Mahnung ans Inkasso ¸bergeben wird //18.04.16 Scheint nach langer Zeit wieder liquide zu sein, hat die letzte Rechnung p¸nktlich bezahlt
    //hSpecial["STG"] := {"DATE"=>StoD("20180330"), "LIMIT"=>2700} //03.01.18 Immer mit Skonto, Rating weterhin bei 3.1, KL auf 2700 erhˆht und verl‰ngert //07.07.17 weiterhin eine erhˆhung wegen dem Rating nˆtig. //29.03.17 zahlt inzwischen immer mit Skonto, hat ein Rating von 3.1 und ein KL von 2400, kurzfristige Erhˆhung damit ein Rahmen angelegt werden kann danach sollte das KL von 2400 reichen//22.04.16 Hat letzte Rechnung pktl. bezahlt von 1430 auf 2000 angehoben//02.03.16 wird engmaschig gemahnt und kriegt vorab Auszug, es haben nur 10Ä zum errechneten Limit gefehlt    
    //hSpecial["KEILBACH"] := {"DATE"=>StoD("20180330"), "LIMIT"=>750} //23.01.17 Rating weiterhin 3.2, zahlt nun nur p¸nktlich, daher "nur" 750Ä //30.11.17 Rating 3.2, zahlte in der Vergangenheit immer mit Skonto    
    //hSpecial["PARKHERE"] := {"DATE"=>StoD("20181230"), "LIMIT"=>1000} //06.09.18 auf Factoring umgestellt //22.01.18 zahlt mit Skonto wurde auf Rating wurde von 2.4 auf 3.6 reduziert
    //hSpecial["XERA"]     := {"DATE"=>StoD("20180228"), "LIMIT"=>120} //07.02.18 Rating liegt bei 3.6
    
    //hSpecial["FKBGMBH"]    := {"DATE"=>StoD("20181231"), "LIMIT"=>5000} //12.07.18 Zahlt immer direkt nach der Mahnung, hat dies nur im Januar erst 16 Tage nach FÑlligkeit erhalten
    //hSpecial["SCHENCKG"]    := {"DATE"=>StoD("20181231"), "LIMIT"=>2500} //13.07.18 War auf 14 Tage netto. Habe das auf 30 Tage, 10-2% umgestellt. Hatte zuvor immer erst nach der ersten Mahnung bezahlt. Vielleicht wird es dadurch besser.
    //hSpecial["ALLSTEIN"]    := {"DATE"=>StoD("20181231"), "LIMIT"=>8000} //18.07.18 Zahlt erst nach 3. Mahnung - auf Factoring umgestellt. Fundflow hat Limit bei 8k gestzt
    //hSpecial["DEDOTEC"]    := {"DATE"=>StoD("20181231"), "LIMIT"=>3000} //23.07.18 Zahlt immer erst nach der 1. Mahnung - auf Factoring umgestellt.
    //hSpecial["ELECTROX"] := {"DATE"=>StoD("20181230"), "LIMIT"=>3400} //13.08.18 Ist inzwischen auf Factoring. //16.08.17 hat letzte Rechnung vorzeitig beglichen (ohne Skonto!) daher auf 3150 erhˆht //11.07.17 Unterscheidung zwischen Auftrag und nicht Auftrag //08.06.17 nochmals etwas angehoben //09.05.17 um 431 auf 7030 erhˆht //Auf Druck letzte Rechnung p¸nktlich bezahlt. Deckung durch die R+V vorhanden (durch Umsatz)
    //hSpecial["SONO"] := {"DATE"=>StoD("20181031"), "LIMIT"=>1100} //16.10.18 Hat die letzte Rechnung pÅnktlich bezahlt
    //hSpecial["HEIDELBE"] := {"DATE"=>StoD("20181231"), "LIMIT"=>30000} //19.10.18 Bei der letzten Rechnung blieb ein kleiner Betrag, nach Verrrechnung, stehen der spÑt bezahlt wurde    
    //hSpecial["NWTGMBH"]  := {"DATE"=>StoD("20181130"), "LIMIT"=>1500} //21.11.18 erneuter Ausrutscher im April, davor mehr oder weniger pÅnktlich 21.08.17 letzte Rechnung erst nach 2. Mahnung - scheint ein Ausrutscher zu sein. Hat zuvor immer sehr pktl. bezahlt
    //hSpecial["RICHTERJ"] := {"DATE"=>StoD("20181231"), "LIMIT"=>820} //Zahlungsmoral scheint sich verschlechtert zu haben. Daher "nur" von 750 auf 820 erhîht
    //hSpecial["TRIAD"] :=  {"DATE"=>StoD("20181031"), "LIMIT"=>250} //Kein Eintrag bei CS    
    //hSpecial["ENERGYDE"] := {"DATE"=>StoD("20180330"), "LIMIT"=>401} //15.01.18 Zahlte zuletzt mit Skonto, hat aber ein Rating von 3.6
    //hSpecial["LAGRATEC"] := {"DATE"=>StoD("20180205"), "LIMIT"=>363} //05.02.18 Ware falsch versandt, daher ¸ber KL
    //hSpecial["TEST"] := {"DATE"=>StoD("20991230"), "LIMIT"=>100}
    //hSpecial["ELME"] := {"DATE"=>StoD("20190330"),"LIMIT"=>200} //04.03.19 Keine Auskunft
    //hSpecial["ROHDEAG"] := {"DATE"=>StoD("20190330"),"LIMIT"=>2000} //05.03.19 Auskunft fehlerhaft
    //hSpecial["IMO-TEC"]  := {"DATE"=>StoD("20161027"), "LIMIT"=>799} //Rating 3.2, angeboten aber mit ZZ, daher Versuch    
    //hSpecial["RMECABLE"] := {"DATE"=>SToD("20170830"),"LIMIT"=>1050}  //30.08.17 auf 1050 erhˆht //18.07.17 Erhˆhung auf 1000 redutziert und verl‰ngert //16.03.17 KL wegen Auslieferung angehoben, werden aber durchgreifen m¸ssen, wenn die n‰chste Rechnung nicht bezahlt wird //10.03.17 Kurzfristige Erhˆhung von 800 auf 1875 um Rahmen einzupflegen //13.09.16 Erhˆhung um 100Ä auf 600
    //hSpecial["REPUTATI"] := {"DATE"=>SToD("20161030"),"LIMIT"=>1800}  //14.09.16 Hat letzte Rechnung (M‰rz 15) mit Skonto bezahlt ist aber nicht in der CS Datenbank
    //hSpecial["KRENNNEU"] := {"DATE"=>SToD("20161230"),"LIMIT"=>400}  //19.09.16 Frimierung neue - Gesamtrechtsnachfolge
    
    //hSpecial["DEGER"]    := {"DATE"=>StoD("20161117"), "LIMIT"=>301} //Nicht bei der CS gelistet, zahlt relativ pkt., von sofort netto auf 14 Tage umgestellt
    //hSpecial["SENECT"]   := {"DATE"=>StoD("20161130"), "LIMIT"=>301} //Rating 3.5, zahlt weitesgehend p¸nktlich
    //hSpecial[HB_AnsiToOem("MIMM‹LLE")] := {"DATE"=>StoD("20161231"), "LIMIT"=>700} //Rating 3,2 zahlt aber immer mit Skonto
    //hSpecial["PRIM"]     := {"DATE"=>StoD("20161109"), "LIMIT"=>8000} //Zahlen immer mit Skonto, daher max. Limit der CS ¸bergehen
    //hSpecial["OLYMPA"]   := {"DATE"=>StoD("20161231"), "LIMIT"=>3000} //Auskunft Creditsafe, Rating C
    //hSpecial["NIMBUS"]   := {"DATE"=>StoD("20161231"), "LIMIT"=>700} //14.04.16 letzte Rechnung wurde nach der 1. Mahnung bezahlt, diese wurde jedoch urlaubsbedingt sp‰t versendet (August 2015)    

    //hSpecial[HB_AnsiToOem("R÷BEN")] := {"DATE"=>StoD("20161230"), "LIMIT"=>3600} //einzelfirma rating 3.2, aber immer gute Erfahrung (mit Skonto)    
    //hSpecial["MILON"]    := {"DATE"=>StoD("20170630"), "LIMIT"=>3800} //10.03.16 die sind sicherlich liquide nur zu blˆd zum pktl zahlen, die nehmen jetzt die komplette Jahresmenge auf einmal dann werden wir nur einmal dem Geld hinterherhagen m¸ssen //20.10.16 Hˆherer KL um Abruf eintragen zu kˆnnen, da inzwischen die 2 Rechnung wieder gemahnt werden muss und noch unbezahlt ist //22.08.16 Hoher Kreditrahmen um Abruf eintragen zu kˆnnen //03.08.16 erste Rechnung erst nach 2.Mahnung bezahlt. Versuch ob sich das verbessert. Rating sehr gut!
    //hSpecial["ZANDERFR"] := {"DATE"=>StoD("20161231"), "LIMIT"=>900} //15.08.16 Kunde hatte Rechnung nicht vorliegen und hat sich auf die Mahnung nicht ger¸hrt. Tobi wird BH Kontakt anfragen und hinterlegen
    //hSpecial["WINTERGA"] := {"DATE"=>StoD("20181231"), "LIMIT"=>1100} //20.04.18 Rating weiterhin nur 3.0 und zahlt pkt. daher 1100Ä //15.08.16 Zahlt immer sehr pktl. KL nur aufgrund des Rating von 3.0
    //hSpecial["BINTIN"]   := {"DATE"=>StoD("20161231"), "LIMIT"=>550} //19.08.16 Kein Listing bei Creditsafe
    //hSpecial["STAKPURE"] := {"DATE"=>StoD("20161231"), "LIMIT"=>99} //02.09.16 Rating 3,6 hat aber zuletzt sehr pktl. bezahlt
    //hSpecial["POLYELEC"] := {"DATE"=>StoD("20170228"), "LIMIT"=>2999} //16.1.17 Verbesserung eingetreten, letzte sogar p¸nktlich! //02.09.16 Hat die letzten 2 Rechnungen erst auf die 1. Mahnung hin bezahlt, diese wurde zumindest bei der letzten relativ sp‰t verschickt
    //hSpecial["DFS"]      := {"DATE"=>StoD("20180430"), "LIMIT"=>900} //24.01.18 Letzten beiden Rechnung mit Skotno, Rating 3.5 Limit auf 900Ä festgesetzt //10.03.17 auf 1500 limitiert. Letzten beiden Rechnungen erst nach erster Mahnung bezahlt //27.10.16 Zahlt immer mit Skonto auf 3000Ä angehoben //Durch R¸ckstellungen f¸r Pensionszusagen ist das Eigenkapital um 1,1 Mrd gesunken, das sollte die Liquidit‰t vorerst nicht beeinflussen
    //hSpecial["IASGMBH"]  := {"DATE"=>StoD("20170130"), "LIMIT"=>1999} //12.10.16 Eine Rechnung erst nach 2. Mahnung bezahlt, vorr. weil die erste per Fax ignoriert wurde. Erhˆhung um 950Ä
    //hSpecial["TECHS.A."] := {"DATE"=>StoD("20161231"), "LIMIT"=>350} //16.11.16 Hat zuletzt 2006 bezogen, damals pktl. bezhalt. schlechtes Kreditrating scheint aber wieder besser zu laufen, daher kleines Limit
    //hSpecial["LABPRO"]   := {"DATE"=>StoD("20161231"), "LIMIT"=>1200} //18.11.16 Hat letzte Rechnung sofort nach der ersten Mahnung bezahlt, erhˆhung von 750 auf 1200Ä
    //hSpecial["AIRBUSDS"] := {"DATE"=>StoD("20161231"), "LIMIT"=>800} //23.11.16 Die hatten die falschen Zahlungsbedingungen hinterlegt. Sonderkond. nun vereinbart und hinterlegt
    //hSpecial["GEOSERVE"] := {"DATE"=>StoD("20161231"), "LIMIT"=>1000} //29.11.16 nicht in CS gelistet - hat aber in der Vergangenheit eigentlich immer mit Skonot bezahlt.
    //hSpecial["WHN"]      := {"DATE"=>StoD("20170830"), "LIMIT"=>IF(lAuftrag,3980,1800)} //01.08.17 verl‰ngert //29.06.17 Auftraglimit auf 3900 wegen Rahmenvertrag, Rechnungen hˆchstens 1800 //19.05.17 wieder f¸r Abrufe erhˆht, aktuell offen nur 467,79 //27.02.17 wieder kurz f¸r Abrufe erhˆht //07.12.16 Wieder kurz f¸r Abrufe erhˆht und auf 1500 begrenzt //21.07.16 BH Dame hat gewechselt und wir hoffen, dass es besser wird ich lege mir das auf WV um eine engmaschige Mahnung zu gew‰hrleisten + kurzfristges KL f¸r Rahmen mit geringen Mindestbest. //07.06.16 Bestehnder Rahmen zus‰tzlicher Auftrag, 30.05.16 Bestehnder Rahmen, nur Abruf ¸ber ca. 470Ä, letzte Rechnung wurde sehr pktl. bezahlt //Hat letzte Rechnung versp‰tet bezahlt, mit seltsamen Ausreden (hat 3 Mahnungnen nicht bekommen, nur er kann zahlen...). Daher kurze Zeit
    //hSpecial["GIGATRON"] := {"DATE"=>StoD("20170131"), "LIMIT"=>150} //16.12.16 Hoher Verlust in 2014, zahlte aber danach immer mit Skonto
    //hSpecial["GEDA"]     := {"DATE"=>StoD("20170131"), "LIMIT"=>500} //12.01.17 eine kleine (97.22) Rechnung wurde vor Weihnachten nicht bezahlt, soll aber jetzt ezahlt werden¥. Zahlt ansonsten p¸nktlich
    //hSpecial["ROTTMANN"] := {"DATE"=>StoD("20170330"), "LIMIT"=>401} //17.01.17 zahlte in der Vergangenheit immer p¸nktlich und durch eine Preiserhˆhung kommt er jetzt ¸ber 300Ä
    //hSpecial["STARZ"]    := {"DATE"=>SToD("20170126"),"LIMIT"=>1201}  //26.01.17 zahlt schlecht, neuer Auftrag aber Standardartikel, daher Erhˆhung f¸r einen Tag damit der Auftrag angelegt werden kann, ausgeliefert wird erst wenn die aktuelle Rechnung beglichen ist.
    //hSpecial["SSL"]      := {"DATE"=>SToD("20170428"),"LIMIT"=>9000}  //21.03.17 Keine neue Rechnung, daher Verl‰ngerung und Erhˆhung auf 9000 //06.02.17 zahlt in immer pktl., hat ein rating von 3.3  //29.09.16 Rating 3.1 und erster Auftrag
    //hSpecial["ROSESYST"] := {"DATE"=>SToD("20170228"),"LIMIT"=>1200}  //13.02.17 Konzern, zahlt erst nach Mahnung!
    //hSpecial["SAGERWIN"] := {"DATE"=>SToD("20170530"),"LIMIT"=>200}  //05.04.17 verl‰ngert //20.02.17 Zahlt pkt. oder mit Skonto hat aber ein Rating von 3.7
    //hSpecial["SCHARFE"]  := {"DATE"=>SToD("20170330"),"LIMIT"=>1250}  //24.02.17 Hat letztes Jahr erst nach 2. bzw. 1. Mahnung gezahlt, Rating ist aber gut.
//    hSpecial["AQUAVITA"] := {"DATE"=>SToD("20170330"),"LIMIT"=>860}  //27.02.17 Kreditrating hat sich von 2.2 auf 3.1 verschlechtert, Erhˆhung des KL um 60Ä um einen laufenden Auftrag ausliefern zu kˆnnen - muss im Auge behalten werden.
    //hSpecial["SCAPE"]    := {"DATE"=>SToD("20170403"),"LIMIT"=>6999}  //27.02.17 Auslieferung der ersten Muster, hat aber noch eine Rechnung offen. Habe die bereits beim Einkauf angemahnt
    //hSpecial["BUTZ"]     := {"DATE"=>SToD("20170630"),"LIMIT"=>960}  //04.03.17 Zahˆt immer mit Skonto, Rating aber 3.2
//    hSpecial["SCHORF"] := {"DATE"=>SToD("20170530"),"LIMIT"=>2900}  //13.03.17 kurzeitige Erhˆhung um einen Rahmen einzugeben.
    //hSpecial["EDB"]      := {"DATE"=>SToD("20170630"),"LIMIT"=>1501} //15.03.17 zahlt seit Mitte 2015 immer p¸nktlich! Hat aber schlechtes Rating - aber auch hier ist das Working Capital gestiegen
    //hSpecial["CELESTIR"] := {"DATE"=>SToD("20170731"),"LIMIT"=>20000} //22.03.17 Hatten letztes Mal Konzernprobleme. Alle Kontakte sind nun richtig hinterlegt.
    //hSpecial["BECOMGIL"] := {"DATE"=>SToD("20171230"),"LIMIT"=>2500} //18.06.17 gleicher Grund //22.03.17 Zahlt immer mit Skonto hat aber schlechtes Rating
    //hSpecial["AUTOSPLI"] := {"DATE"=>StoD("20170531"), "LIMIT"=>340} //29.03.17 zahlt schlecht, Erhˆhung um 40Ä
    //hSpecial["IRTSYSTE"] := {"DATE"=>StoD("20170630"), "LIMIT"=>300} //29.03.17 seitdem keine Rechnung, Rahmen ausgelaufen und wir haben nicht alles da //18.07.16 Rating 3.6, zahlt aber bisher p¸nktlich
    //hSpecial["BERGHAUS"] := {"DATE"=>StoD("20170415"), "LIMIT"=>1500} //29.03.17 Situation scheint sich wieder entspannt zu haben, diesmal jedoch nur 1500Ä //09.08.16 Bonit‰t scheint leicht angespannt zu sein, versucht aber immer pktl. zu zahlen. Daher Erhˆhung von ca. 3k auf 4k
    //hSpecial["ROBSYSTE"] := {"DATE"=>StoD("20170331"), "LIMIT"=>2500} //31.03.17 neuer Rahmen und mehrere Abrufe, Bestellungen kamen nicht an.
    //hSpecial["GO11SAVE"] := {"DATE"=>StoD("20171231"), "LIMIT"=>110} //neugegr¸ndete AG, CS sagt ungen¸gend Daten
    //hSpecial["BINTIN"]   := {"DATE"=>StoD("20171231"), "LIMIT"=>500} //Zahlt mit Skonto
    //hSpecial["SURYS"]    := {"DATE"=>StoD("20170530"), "LIMIT"=>2035} //Hat die erste Rechnung sofort nach der ersten Mahnung bezahlt. Im Auge behalten
    //hSpecial["RMG"]      := {"DATE"=>StoD("20170930"), "LIMIT"=>1630} //03.08.17 Wieder erhˆht. Gehˆren nun nicht mehr zu Honeywell sollte also besser werden //12.05.17 auf von 1500Ä erhˆht //08.05.17 Konzernproblem. Laut RMG wurden die aber aufgekauft und lˆsen sich von Honeywell //2015 Probleme bei der Umstellung auf Honeywell
    //
    //hSpecial["EFGWEST"]  := {"DATE"=>StoD("20170930"), "LIMIT"=>1500} //28.06.17 Die brauchen besondere Zahlungsbedingungen und haben letztes mal das Skonto nachbezahlt
    //hSpecial["HESSGER"]  := {"DATE"=>StoD("20170730"), "LIMIT"=>3500} //12.07.17 zahlt immer nach erster Mahnung - werde ich im Auge behalten
    //hSpecial["BRUNENBM"] := {"DATE"=>StoD("20170830"), "LIMIT"=>499} //17.07.17 Rating 3.5, wir probieren das mal mit 500Ä, hoffentlich wird diese mit Skonto bezahlt
    //hSpecial["BRINKMEY"] := {"DATE"=>StoD("20170830"), "LIMIT"=>740} //26.07.17 nicht bei CS gelistet
    //hSpecial["HEGERFER"] := {"DATE"=>StoD("20171230"), "LIMIT"=>2300} //12.09.17 verl‰ngert, zahlt weiterhin mit Skonto //02.08.17 Rating 3.3 zahlt aber mit Skonto
    
    //
    //hSpecial["BAUERELE"] := {"DATE"=>StoD("20171030"), "LIMIT"=>4000} //21.09.17 gehˆrt zu einer groﬂen Holding, CS vergibt aber nur 1000Ä limit
    //hSpecial["REINMEDI"] := {"DATE"=>StoD("20171130"), "LIMIT"=>200} //20.10.17 Rating 3.5, daher nur 200Ä
//    hSpecial["NBB"] := {"DATE"=>StoD("20161011"), "LIMIT"=>15000} //Rating 2.2, aber auf 3k limitiert
//    hSpecial["ISAAR"] := {"DATE"=>StoD("20160630"), "LIMIT"=>1100} //Rating 3.5, zahlt meist p¸nktlich oder nach 1. Mahnung
//    hSpecial["COBOC"] := {"DATE"=>StoD("20160630"), "LIMIT"=>2001} //Rating 3.0, zahlt aber mit Skonto
//    hSpecial["MOLL"] := {"DATE"=>StoD("20160330"), "LIMIT"=>1100} //Durch CS auf 1000 begrenzt
//    hSpecial["ROB"] := {"DATE"=>StoD("20160630"), "LIMIT"=>IF(Date()<=StoD("20160606"),3800,2950)} //Zahlt immer erst nach der 3. Mahnung. Sigi wird sehr engmaschig und mit Kontoauszug vorab mahnen.
//    hSpecial["ARTEKO"] := {"DATE"=>StoD("20160415"), "LIMIT"=>1200} //14.04.16 Rechnung wurde an den falschen Kunden ausgestellt
//    hSpecial["SARTORIG"] := {"DATE"=>StoD("20160630"), "LIMIT"=>2100} //Rechnung war an die falsche Adresse ausgestellt und konnte so nicht zugeordnet werden
//    hSpecial["HKTEST"] := {"DATE"=>StoD("20160831"), "LIMIT"=>IF(Date()<StoD("20160630"),7500,1990)} //27.06. 7500 f¸r Rahmen //Letzte Rechnung mit 8 Tagen Verzug beglichen (2. Mahnung), davor aber mit Skonto, liegt aber auﬂerhalb des Betrachtungszeitraums
//    hSpecial["CAC"] := {"DATE"=>StoD("20160930"), "LIMIT"=>1900} //Auftrag wurd in zwei Teile gesplittet um ein Druckmittel zu haben
//    hSpecial["SATCOM"] := {"DATE"=>StoD("20160930"), "LIMIT"=>2000} //Firma d¸rfte nach Bilanz und CS sehr liquide sein, werden sowieso einen Vorabauszug bekommen
//    hSpecial["APRAPOL"] := {"DATE"=>StoD("20160630"), "LIMIT"=>6801} //Hat 1. Rechnung schlecht bezahlt, werden das weiter beobachten
//    hSpecial["PROCESSS"] := {"DATE"=>StoD("20160330"), "LIMIT"=>150} //Hat schon einmal auf Rechnung erhalten und mehr oder weniger pkt. (nach 1. Mahnung) bezahlt.
//    hSpecial["TILLYTA"] := {"DATE"=>StoD("20160331"), "LIMIT"=>3801} //wird nur zur Anlage des Rahmens benˆtigt
//    hSpecial["KARRE"] := {"DATE"=>StoD("20160330"), "LIMIT"=>2999} //Hat immer nach der ersten Mahnung bezahlt. Sollte zuk¸nftig (aufgrund der bisherigen Verzˆgerung) vorab einen Kontoauszug erhalten
//    hSpecial["WHN"] := {"DATE"=>StoD("20160130"), "LIMIT"=>2401} //Hat letzten beiden Rechnungen zu sp‰t bezahlt (eine erst nach der 4. Mahnung, von den Zahlen her (CS) sollte es aber kein Problem geben)
//    hSpecial["VIVEROO"] := {"DATE"=>StoD("20160130"), "LIMIT"=>349} //Rating 3.6, zahlt aber immer pkt. oder sogar mit Skonto
//    hSpecial["GHL"] := {"DATE"=>StoD("20160331"), "LIMIT"=>2999} //wird engmaschig gemahnt und kriegt vorab Auszug
//    hSpecial["SETIS"] := {"DATE"=>StoD("20161027"), "LIMIT"=>705} //Rating 3.3, angeboten mit ZZ, daher um 5Ä erhˆht
//    hSpecial["KWAUTOMO"] := {"DATE"=>SToD("20151030"),"LIMIT"=>4999} //20.02.15 auf 14 Tage umgestellt; 06.07.15 auf 4999 erhˆht, letzte Rechnung "nur" 9 Tage versp‰tet

//    hSpecial["GHIELMET"] := {"DATE"=>StoD("20150930"), "LIMIT"=>2195} //bisher nur einmal vorgekommen.
//    hSpecial["ARNOLDRI"] := {"DATE"=>StoD("20151130"), "LIMIT"=>949} //Rating 3.1 , KL ein wenig erhˆht
//    hSpecial["ELEXXION"] := {"DATE"=>StoD("20151230"), "LIMIT"=>401} //Rating 3.8, zahlt aber immer p¸nktlich
//    hSpecial["SETIS"] := {"DATE"=>StoD("20151230"), "LIMIT"=>1201} //Hat den falschen Artikel bestellt, daher kurzfristige erhˆhung.
//    hSpecial["ISAAR"] := {"DATE"=>StoD("20151230"), "LIMIT"=>601} //Rating 3.5 hat letzte Rechnung aber pktlt. bezahlt.
//    hSpecial["INNOVATE"] := {"DATE"=>StoD("20151130"), "LIMIT"=>476} //Rating 3.5 - mit GF gesprochen, daraufhin letzten beiden Rechnungen sofort bezahlt. GF nochmals kontaktieren falls zu sp‰t
//    hSpecial["MIDDENDO"] := {"DATE"=>SToD("20150630"),"LIMIT"=>621}
//    hSpecial["MULTIPUB"]    := {"DATE"=>SToD("20150630"),"LIMIT"=>803} //Weihnachten
//    hSpecial["AMANNGIR"] := {"DATE"=>SToD("20141230"),"LIMIT"=>2742}
//    hSpecial["EDEKA"]    := {"DATE"=>SToD("20141231"),"LIMIT"=>6701}
//    hSpecial["BECOMHO"]    := {"DATE"=>SToD("20150405"),"LIMIT"=>6510} //Kunde zu blˆd zu zahlen
//    hSpecial["DRESDENE"]    := {"DATE"=>SToD("20150830"),"LIMIT"=>6985} //kunde wird engmaschig gemahnt, wenige historische daten //2.6.15 zahlungsmoral hat sich verbessert. Nach Pr¸fung der Bilanz (2013) scheint es eher Taktik zu sein
//    hSpecial["ICINTRA"] := {"DATE"=>SToD("20150530"),"LIMIT"=>7100} //hat versprocehn p¸nktlicher zu zahlen, ansonsten auf vorkasse umstellen
//    hSpecial["STECA"] := {"DATE"=>StoD("20150530"),"LIMIT"=>4105} //hatte unberechtigter weise eine belasungsanzeige abgezogen
//    hSpecial["IKT"] := {"DATE"=>StoD("20150530"),"LIMIT"=>3501} //spezielle GBR
//    hSpecial["ERA-CONT"] := {"DATE"=>StoD("20150730"), "LIMIT"=>1001} //2.6.15 zahlungsverhalten hat sich bei den letzten zwei Rechnungen verbessert
//    hSpecial["SONO"]    := {"DATE"=>SToD("20150228"),"LIMIT"=>2401} //bisher VTS (jetzt Holding), Sigi wird auf Zahlungeingang achten und eng mahnen
//    hSpecial["SCHOR"]    := {"DATE"=>SToD("20150530"),"LIMIT"=>4999} //Zahlung hat sich immer weiter verschlechter, begrenzung auf 5.000 damit ist nur eine Teillieferung mˆglich ->Druckmittel
//    hSpecial["KARRE"]    := {"DATE"=>SToD("20150228"),"LIMIT"=>1999} //Mahnung zu sp‰t verschickt
//    hSpecial["PENTAIR"]    := {"DATE"=>SToD("20150228"),"LIMIT"=>9000} //probleme beim einrichten als kreditor (konzern?!)
//    hSpecial["WURLITZE"]    := {"DATE"=>SToD("20150228"),"LIMIT"=>689}

//    hSpecial["OMITRON"] := {"DATE"=>SToD("20141230"),"LIMIT"=>5837}
//    hSpecial["AER"] := {"DATE"=>StoD("20160613"), "LIMIT"=>1000}
//    hSpecial["ITTERMAN"]    := {"DATE"=>SToD("20150330"),"LIMIT"=>1236}
//    hSpecial["MEXTAL"] := {"DATE"=>SToD("20141231"),"LIMIT"=>450}
//    hSpecial["SONEPAR"] := {"DATE"=>SToD("20141230"),"LIMIT"=>2501}
//    hSpecial["HITZINGE"] := {"DATE"=>SToD("20150306"),"LIMIT"=>3214.69}   //auftrag ware bereits angelegt, deshalb verl‰ngerung
//       hSpecial["MOTTURA"]  := {"DATE"=>SToD("20140603"),"LIMIT"=>3000}
//    hSpecial["VIEGA"] := {"DATE"=>SToD("20140516"),"LIMIT"=>nCredLimit}
//    hSpecial["TRIPLE"]   := {"DATE"=>SToD("20140825"),"LIMIT"=>nCredLimit}  //wegen qualit‰tsproblem
//    hSpecial["COBES"]    := {"DATE"=>SToD("20131126"),"LIMIT"=>1500}
//    hSpecial["MILTRONI"] := {"DATE"=>SToD("20140523"),"LIMIT"=>nCredLimit} //rechnung wurde an Engelking e.K. ¸berwiesen, dauerte bis das geld bei uns war
//    hSpecial["VIENCO"] := {"DATE"=>SToD("20140220"),"LIMIT"=>5000}
//   hSpecial["TLS"] := {"DATE"=>SToD("20140301"),"LIMIT"=>1205} //400 -> 700 -> 995 -> 1005
//   hSpecial["SELTEGRO"] := {"DATE"=>SToD("20140301"),"LIMIT"=>2000} => GESPERRT Mahnbescheid
//   hSpecial["ACTIVEPH"] := {"DATE"=>SToD("20140101"),"LIMIT"=>1000}
//    hSpecial["B&R"] := {"DATE"=>SToD("20131231"),"LIMIT"=>1600}
//    hSpecial["3SANTRIE"] := {"DATE"=>SToD("20140131"),"LIMIT"=>900}
//     hSpecial["VOSCH"] := {"DATE"=>SToD("20140430"),"LIMIT"=>1670} //ziel von 14 auf 30T verl‰ngert, 21.03.14
//     hSpecial["HEIJDEN"] := {"DATE"=>SToD("20140331"),"LIMIT"=>230}
//     hSpecial["PRESS"] := {"DATE"=>SToD("20131231"),"LIMIT"=>1120}
//     hSpecial["ROHDEM"] := {"DATE"=>SToD("20140116"),"LIMIT"=>1700} //nachberechnung ¸berlieferung
//      
//      hSpecial["MRMETALL"] := {"DATE"=>SToD("20140331"),"LIMIT"=>255}
//      hSpecial["RUDOLPHI"] := {"DATE"=>SToD("20140430"),"LIMIT"=>360}
//      hSpecial["HOLTKAMP"] := {"DATE"=>SToD("20140430"),"LIMIT"=>4000}
//      hSpecial["SCSGMBH"] := {"DATE"=>SToD("20140415"),"LIMIT"=>325} //rechnung 29872 viel zu sp‰t bezahlt!
//    hSpecial["LIGHTPOW"] := {"DATE"=>SToD("20141231"),"LIMIT"=>1500} //Bankeinz¸ge wurden zu sp‰t eingezogen
//    hSpecial["UWEGMBH"] := {"DATE"=>SToD("20141230"),"LIMIT"=>401}

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
   IF lDbg
      Alert("Vorkasse")
   ENDIF
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
	TR_MsgBox("Bitte neuen Beitrag der Kreditversichung hinterlegen")
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

If wkv->(dbSeek( Str(nKuNr,6) ))
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
		lWkv   := .T.
	Endif
ELSE
//   Alert("not found")
Endif

IF lDbg
	CLS
    ? PadL("Rechnr",6),PadL("Datum",8),PadL(t("F‰llig"),8),PadL("Zahlung",8),Pad("Mahnung",2+1+8),PadL(t("‹ber"),3),PadL("Wert",12),PadL("Gewicht",12)
ENDIF

//collect information about the invoices in the last 12 months
Do While re->Reposnr == 0 .AND. re->Kunde == cKunde .AND. ! re->(Eof())
   If AddMonth(re->rechdat,nMonths) >= dDate
      nWait  := ska->(GetSkontoWait(re->Skonto,re->Rechdat))
      ska->(dbGoto( re->Skonto+1 ))

      dPDate := re->rechdat+nWait
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


oExtra := ku->(ExtraData():New(nKuNr))

If lWKV .AND. ! (lAuftrag .AND. HHasKey(hSpecial,Trim(cKunde)))
   nCredLimit := Min(nCredLimit,nWKVCL)
   IF lDbg		
      ? t("Limit durch die WKV festgelegt:"),Str(nCredLimit)
   ENDIF
ELSEIF Trim(ku->CompForm) == "KOER" .OR. Trim(ku->CompForm) == "STIFT"
   nCredLimit := Max(1000,nCredLimit)
ELSEIF lSimpleCountry .AND. ((nTotalPaid >= 4000 .AND. nCredLimit <= 20000) .OR. (nTotalPaid >= 2500  .AND. nCredLimit <= 10000)) //in diesem Fall brauchen wir keine Kreditauskunft. Da reicht die Zahlungserfahrung	
   nCredLimit := Max(nCredLimit,3000) //min. 3000
   IF lDbg		
      ? "Limit durch LÑndervereinfachung:",LTrim(Str(nCredLimit,12,0))
   ENDIF
ELSE
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
               oSOAP := CreditSafe()
   
               __TxtBox("Auskunft wird eingeholt...")
   
               IF ! cs->(Found()) .OR. Empty(cs->ID)
                  NetUse("gerichte","ger")
                  ger->(dbSeek( ku->CountryIso+Str(ku->Gericht,4) ))
                  oCtr := SOAPParameter():New("countries")
                  oCtr:CreateChild("CountryCode","DE",,"http://schemas.datacontract.org/2004/07/Creditsafe.GlobalData")
   
                  aRegex := HB_Regex("([A-Za-z]{2,3})\s*([0-9][^\s]*[\sA-Za-z]*)",ku->Compno)
                  IF Len(aRegex) >= 3
                     //Alert(aRegex[2]+" "+aRegex[3])
                     oSearch := SOAPParameter():New("searchCriteria",,,"http://www.creditsafe.com/globaldata/operations")
                     oSearch:CreateChild("RegistrationNumber",aRegex[2]+" "+aRegex[3],,"http://www.creditsafe.com/globaldata/datatypes")
                     oSearch:CreateChild("Address",,,"http://www.creditsafe.com/globaldata/datatypes"):CreateChild("City",StrTran(ger->SimpleName,HB_AnsiToOem("ﬂ"),"ss"),,"http://www.creditsafe.com/globaldata/datatypes")
      
                     oXML := oSOAP:Call("FindCompanies",{oCtr,oSearch})
                     oCompany :=  TXmlIteratorScan():New(oXML:oRoot):Find("Companies"):oChild
                  ENDIF
                  IF oCompany == NIL
                     __TxtBox("Keinen Eintrag gefunden",.T.)
                     nCredLimit := 0
                     TxtClear()
                     //EXIT
                  ELSEIF oCompany:oNext != NIL
   
                     DO WHILE oCompany != NIL //.AND. Upper(StrTran(TXMLIteratorScan():New(oCompany):Find("RegistrationNumber"):cData," ","")) != Upper(StrTran(ku->CompNo," ",""))
                        cRegex  := "[A-Z]{2,3}\s*[0-9]{3,}[\sA-Za-z]*"
                        aRegex1 := HB_Regex(cRegex,Upper(TXMLIteratorScan():New(oCompany):Find("RegistrationNumber"):cData))
                        aRegex2 := HB_Regex(cRegex,Upper(ku->Compno))
                        IF Len(aRegex1) > 0 .AND. Len(aRegex2) > 0 .AND. StrTran(aRegex1[1]," ","") == StrTran(aRegex2[1]," ","")
                           EXIT
                        ELSEIF Tr_Getini(28) == 9
                           /*IF Len(aRegex1) == 0
                              Alert("Keine Registernummer bei CS")
                           ELSEIF Len(aRegex2) == 0
                              Alert("Keine Registernummer im Trader "+ku->Compno)
                           ELSE
                              Alert("CS: "+StrTran(aRegex1[1]," ","")+";Trader:"+StrTran(aRegex1[2]," ",""))
                           ENDIF*/
                        ENDIF
                        /*IF Len(aRegex1) > 0 .AND. Len(aRegex2) > 0
                           Alert(aRegex1[1]+";"+aRegex2[1])
                        ELSE
                           Alert("No Regex;"+Ltrim(str(Len(aRegex1)))+" - "+Ltrim(str(Len(aregex2)))+";"+Upper(TXMLIteratorScan():New(oCompany):Find("RegistrationNumber"):cData))
                        ENDIF */
                        //Alert(TXMLIteratorScan():New(oCompany):Find("RegistrationNumber"):cData)
                        oCompany := oCompany:oNext
                     ENDDO
                     TxtClear()
                     IF oCompany == NIL
                        __TxtBox("Keinen passenden Eintrag gefunden",.T.)
                     ELSE
                        cID := oCompany:GetAttribute("Id")
                     ENDIF
                        //__TxtBox("Zu viele Eintr‰ge gefunden!;"+TXMLIteratorScan():New(oCompany):Find("RegistrationNumber"):cData,.T.)
                  ELSE
   /*                     cs->(Add_rec(0))
                     cs->Kunde := ku->Nummer
                     cs->ID    := oCompany:GetAttribute("Id")
                     cs->(dbUnLock())*/
                     cID := oCompany:GetAttribute("Id")
                  ENDIF
               ELSE
                  cID := cs->ID
               ENDIF
               //IF cs->Kunde == ku->Nummer
               IF cID != NIL
                  oSOAP := CreditSafe()
                  oReport := CS_GetCompanyReport(oSoap,cID,3)
                  IF oReport == NIL
                     __TxtBox("Fehler beim herunterladen der Auskunft!",.T.)
                     nCredLimit := 1
                  ELSE
                     CS_SaveReport(ku->Nummer,oReport)
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
      IF HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date()
         nCredLimit := hSpecial[Trim(cKunde)]["LIMIT"]
      
      ELSEIF ku->CountryIso == "DE"  //nur im Inlad reduzieren
         IF Empty(ku->CompForm)
            __TxtBox("Bitte Rechtsform hinterlegen!",.T.)
            nCredLimit := 0.1
         ELSEIF Empty(ku->Compno)
            nCredLimit := Min(nCredLimit,300)
         ELSE
            nCredLimit := 0.2
         ENDIF
      ENDIF
   ELSE
      oReport := CS_GetCompanyReportFromArchive(ku->Nummer)
      IF oReport != NIL
         /*IF  ! cs->(dbSeek( Str(ku->Nummer,6) ))
            cs->(Add_Rec(0))
            cs->Kunde := ku->Nummer
            cs->ID    := oReport:oRoot:oChild:oChild:oChild:GetAttribute("CompanyId")
            cs->(dbUnLock())
         ENDIF*/
         oIter := TXmlIteratorScan():New(oReport:oRoot)
         oNode := oIter:Find("DECurrentRating")
         IF oNode != NIL
            nRating := Val(oNode:cData)
             IF nRating >= 5
               nCredLimit := 0.5
             ELSEIF nRating >= 3.5 //schlechtes Rating               
               IF (HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date()) .OR. oExtra:Factoring  //this is not such a good idea, it means you can put in any credit limit for any customer, maybe we need to refine this
                  IF Trim(cKunde)=="DFS" //Sonderbehandlung
                     nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],3000)
                  ELSEIF oExtra:Factoring                      
                     nCredLimit := Min(Max(IF(HHasKey(hSpecial,Trim(cKunde)),hSpecial[Trim(cKunde)]["LIMIT"],0),500),3000)  //min. 500? Limit max. 3000
                  ELSEIF nAvgOvr <= 0 .AND. nPaidOrDueTotal > 0  //if they have paid all invoices punctually in the last 12 months (and they had invoices)
                     nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],2000) //Min(2000,Max(nPaidOrDueTotal,1800)))
                  ELSE
                     nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],1000)
                  ENDIF
               ELSE
                  nCredLimit := .5
               ENDIF
            ELSE               
               oIter:Rewind()
               oNode := oIter:Find("CompanyStatus")               
               IF oNode:GetAttribute("Code") == "Other" .AND. oNode:cData $ "active aktiv" .AND.  HHasKey(hSpecial,Trim(cKunde)) //aktiv aber unbewertet
                  nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],100)
               ELSEIF oNode == NIL .OR. oNode:GetAttribute("Code") != "Active" .OR. ! oNode:cData $ "active aktiv"
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
               ELSEIF HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date()                  
                  nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],20000)
               ELSEIF ! oExtra:Factoring //Max 900Ä wenn keine R+V Deckung, auﬂer positive Zahlungserfahrung                  
                  nCredLimit := Min(nCredLimit,1000-(nRating-2.9)*10*100)
                  IF nAvgOvr <= -0.4 //zahlt mit skonto, max 2700                     
                     nCredLimit := Max( Min(nCredLimit*3,nPaidTotal), nCredLimit*1.5 )
                  ELSEIF nAvgOvr <= 0 //zahlt p¸nktlich oder ist auf Factoring gestellt  
                     nCredLimit := Max( Min(nCredLimit*2,nPaidTotal/2), nCredLimit )
                  ENDIF
               ENDIF

               IF AScan(aOverrideMax,Trim(cKunde)) != 0  .AND. nAvgOvr <= 0 .AND. nPaidOrDueTotal > 0//ignore the maximum on these customers  as long as they pay punctual

               ELSE
                  oNode := oIter:Find("CreditLimit")
                  IF lDbg
                     ? "CS Limit:",oNode:cData
                  ENDIF
                  IF oNode != NIL
                     IF Trim(cKunde) $ hMultiMax .AND. (nAvgOvr <= 0.25 .OR. oExtra:Factoring) //these customers get a multiple of the CS level
                        nCredLimit := Min(nCredLimit,Val(oNode:cData)*Min(hMultiMax[Trim(cKunde)],4000))
                     ELSEIF Val(oNode:cData) == 0  .AND. HHasKey(hSpecial,Trim(cKunde))
                        nCredLimit := Min(hSpecial[Trim(cKunde)]["LIMIT"],110)
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
            ? t("Limit durch Bewertung:"),Str(nCredLimit)
         ENDIF
      ENDIF
   ENDIF
   


   SetPos(nRow,nCol)

   //ENDIF
ENDIF

IF lDbg
   DO WHILE SInkey(0,128) == 32
   ENDDO
   RestScreen(,,,,cScr)
   SetPos(nRow,nCol)
ENDIF

//IF lDbg; Alert("AFTER CS "+Str(nCredLimit)+Str(nWKVCL)); ENDIF

nMaxDeckung := Min(nCredLimit,20*nNettoBeitrag/0.7)
nCredLimit := nMaxDeckung //Deckung = 20x Grunddeckungbetrag zzgl 30% Selbstbeteiligung

IF lAuftrag .AND. HHasKey(hBigCustomer,Trim(cKunde)) .AND. nWKVCL >= nMaxDeckung
   nCredLimit := hBigCustomer[Trim(cKunde)]
ENDIF

IF lAuftrag .AND. Trim(cKunde) == "WHTECH" .AND. nWKvCL >= 30000
   nCredLimit := Max(52000,nWKVCL) //im schlimmsten Fall m¸ssten wir uns auf unsere R¸cksendeklause bei Bulgin berufen.
ENDIF

If Trim(cKunde) == "JANNIS"
	Return 2000
Endif

ku->(dbSetOrder( 8 ))
ku->(dbSeek( Str(nKuNr,6) ))
ska->(dbGoto( ku->Skonto+1 ))

IF ska->Ziel1 != -2 .AND. nAvgOvr >= 0.25 .AND. ! oExtra:Factoring 
      IF ! HHasKey(hSpecial,Trim(cKunde)) .OR. hSpecial[Trim(cKunde)]:Date < Date()
         IF nAvgOvr >= 0.80
            nCredLimit := Min(nCredLimit,200)
         ENDIF
         IF nAvgOvr >= 0.60
            nCredLimit := Min(nCredLimit,Max(nPaidTotal*1/8,300))
         ELSEIF nAvgOvr >= 0.40
            nCredLimit := Min(nCredLimit,Max(nPaidTotal*1/4,500))
         ELSEIF nAvgOvr >= 0.25
            nCredLimit := Min(nCredLimit,Max(nPaidTotal*1/2,750))
         ENDIF
      ELSE
         nCredLimit := hSpecial[Trim(cKunde)]:Limit
      ENDIF
ENDIF

If lToLate //one invoice was paid to late
   If nToLate <= 15 //small credit limit for 15 further days
		If ska->Ziel1 == -2 //bankeinzug
			Return 500
		ELSEIF  HHasKey(hSpecial,Trim(cKunde)) .AND. hSpecial[Trim(cKunde)]:Date >= Date()
        RETURN Min(1200,hSpecial[Trim(cKunde)]:Limit)
      Endif
   ELSEIF HHasKey(hSpecial,Trim(cKunde)) .AND. HHasKey(hSpecial[Trim(cKunde)],"TOLATE") .AND. hSpecial[Trim(cKunde)]["TOLATE"]
      RETURN Min(500,hSpecial[Trim(cKunde)]:Limit)
    ELSEIF oExtra:Factoring //if he paid to late and we change him to factoring, then we will allow a small amount
      RETURN 250
	Endif
	Return -6  //no credit
Elseif ! lSimpleCountry .AND. ! lMoreCountry
   IF Tr_Getini(28) == 9; Alert("Country: "+ku->CountryIso); Endif
	Return -5 //country has no protection
Elseif lWKV
	Return nCredLimit
ELSEIF ku->CountryIso == "DE" //Abfrage Creditsafe
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

STATIC Function __TxtBox(cTxt,lWait)
   TxtBox(t(cTxt))
   IF lWait == .T.
      Inkey(1,128)
      TxtClear()
   ENDIF
RETURN NIL

#include 'X:\run\creditsafe.prg'