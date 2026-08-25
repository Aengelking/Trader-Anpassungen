#define LX_CAT_KREDITOR         256
#include 'inkey.ch'

#define CRLF Chr(13)+Chr(10)

/*
   RUN_Check_REB_Betrag

   PrÅft die im Rechnungseingangsbuch (reb) erfasste Rechnungssumme
   (reb->Betrag, Brutto) gegen die tatsÑchlich in Lexware gebuchten BetrÑge.

   Zugeordnet werden die Buchungen Åber den Belegtext "#ER<Index>"
   (LX_GetBookingsForID). Gewertet wird der Bruttobetrag NETTO+UST der
   Buchungen, bei denen ein Kreditorenkonto steht
      - im HABEN  -> Rechnung   (Belastung des Kreditors)
      - im SOLL   -> Gutschrift (Entlastung des Kreditors)
   Buchungen gegen ein Finanzkonto (Zahlungen) und WÑhrungsdifferenzen
   bleiben au·en vor. Stornos dagegen zÑhlen mit: die Ursprungsbuchung und
   die Stornobuchung (negativer Betrag, <STORNO> im Text) heben sich
   gegenseitig auf, so dass bei einer Neuverbuchung genau diese Åbrig
   bleibt. Ein einseitiger Ausschluss wÅrde die Summe verfÑlschen.

   Fremdwaehrung braucht keine Umrechnung: die Rechnung selbst wird mit dem
   Betrag der Fremdwaehrung gebucht, erst die ausgeschlossene Differenz-
   buchung stellt das Konto auf EUR. Die verbleibende Summe ist damit direkt
   mit reb->Betrag vergleichbar.

   Ein Nachlass gegen das Nachlasskonto (REBCHK_NACHLASS, Standard 3800)
   bleibt als eigene Buchung aussen vor. Als Splitzeile innerhalb der
   Rechnungsbuchung gehîrt er dagegen zum Rechnungsbetrag und zÑhlt mit.

   Skonto-Buchungen laufen als "Soll Kreditor / Haben Skontokonto" und werden
   deshalb nur bei Gutschriften (negativer REB-Betrag) Åberhaupt gewertet.
   Zeigt der Detailbereich trotzdem falsch gewertete Gegenkonten, kînnen diese
   Åber den Konfigurationswert REBCHK_IGNKTO ausgeschlossen werden.
*/

PROCEDURE RUN_Check_REB_Betrag
LOCAL nYear   := Year(Date())
LOCAL nTol    := GetValue("REBCHK_TOL",0.01,"Toleranz Betragsabweichung (EUR)")
LOCAL aIgnore := GetValue("REBCHK_IGNKTO",{},"Weitere Konten, die bei der BetragsprÅfung ignoriert werden")
LOCAL aTexts  := GetValue("REBCHK_IGNTEXT",{"HRUNGSDIFF","HRUNGDIFF","KURSDIFF"},"Buchungstexte, die nicht in die Summe eingehen")
LOCAL nNachlass := GetValue("REBCHK_NACHLASS",3800,"Nachlasskonto, wird beim Betragsvergleich nicht mitgerechnet")
LOCAL hIgnore := {=>}
LOCAL nKto,cKto
LOCAL lStapel := .T.
LOCAL getlist := {}
LOCAL hCreditors := {=>},aCreditors,nCreditor
LOCAL aList := {}
LOCAL aBookings,aDetail,nHaben,nSoll,nCount,nStapel,nBooked,nDiff
LOCAL nChecked := 0,nSumDiff := 0
LOCAL cYear
LOCAL nReb
LOCAL oBrowse,oPdf,nWName
LOCAL hErrors := {"D"=>"Betrag weicht ab",;
                  "M"=>"Keine Buchung",;
                  "S"=>"Nur im Stapel",;
                  "K"=>"Kein Kreditorkonto",;
                  "0"=>"Kein Betrag im REB"}

MEMVAR c_three

Head(t("Rechnungsbetr‰ge gegen Lexware pr¸fen"))

NetUse("reb","reb")
NetUse("rebprot","rebp")
NetUse("vat","vat",.F.,0)
NetUse("projcost","pjcst")

@ 01,00 SAY Pad("Belegjahr",20)         GET nYear   PICTURE "9999" VALID nYear >= 2017 .AND. nYear <= Year(Date())
@ 02,00 SAY Pad("Toleranz (EUR)",20)    GET nTol    PICTURE "@E 9,999.99" VALID nTol >= 0
@ 03,00 SAY Pad("Stapel mitrechnen",20) GET lStapel PICTURE "Y"
READ

IF LastKey() == 27
   RETURN
ENDIF

TxtBox(t("Betr‰ge werden verglichen..."))

IF ! LX_Start()
   TxtClear()
   Alert("Keine Verbindung zu Lexware")
   RETURN
ENDIF

aCreditors := LX_GetAccountsInCat(LX_CAT_KREDITOR,.F.)
FOR EACH nCreditor IN aCreditors
   hCreditors[nCreditor] := .T.
NEXT

//Nachlass nur als eigenstÑndige Buchung ausschliessen, daher .F.
IF nNachlass != 0
   hIgnore[nNachlass] := .F.
ENDIF

//Skontokonten aus der Steuertabelle - Skonto wird als
//"Soll Kreditor / Haben Skontokonto" gebucht und darf die Summe nicht mindern
vat->(dbGoTop())
DO WHILE ! vat->(EOF())
   FOR EACH cKto IN {vat->SkontoNeu,vat->SkontoAlt}
      IF (nKto := Val(AllTrim(cKto))) != 0
         hIgnore[nKto] := .T.
      ENDIF
   NEXT
   vat->(dbSkip())
ENDDO
cKto := LX_GetConfigValue("KONTEN","SkontiOhneUSt")
IF ValType(cKto) == "C" .AND. (nKto := Val(AllTrim(cKto))) != 0
   hIgnore[nKto] := .T.
ENDIF
FOR EACH nKto IN aIgnore
   hIgnore[nKto] := .T.
NEXT

cYear := Right(Str(nYear,4),2)

reb->(dbSetOrder( 1 ))
rebp->(dbSetOrder( 2 ))

reb->(dbSeek( cYear+Replicate("0",7),.T. ))
DO WHILE ! reb->(EOF()) .AND. Left(Str(reb->ID,9),2) == cYear

   @ MaxRow(),00 SAY t("Pr¸fe")+" "+Str(reb->ID,9)

   IF rebp->(dbSeek( Str(reb->ID,9)+"STORN" ))   //stornierter Beleg
      reb->(dbSkip())
      LOOP
   ENDIF

   //lStapel == .T. liefert BH_JOURNAL + BH_STAPEL, .F. nur das Journal
   aBookings := LX_GetBookingsForID("ER"+Str(reb->ID,9),lStapel)

   IF Len(aBookings) == 0
      IF reb->Status == 9      //als verbucht markiert, aber nichts gefunden
         Aadd(aList,__NewRow("M",0,0))
      ENDIF
      reb->(dbSkip())
      LOOP
   ENDIF

   nChecked++

   aDetail := {}
   nCount  := 0
   nStapel := 0
   nHaben  := __SumSide(aBookings,hCreditors,hIgnore,aTexts,.T.,@aDetail,@nCount,@nStapel)
   nSoll   := __SumSide(aBookings,hCreditors,hIgnore,aTexts,.F.,@aDetail,@nCount,@nStapel)

   nReb := reb->Betrag

   //Saldo auf dem Kreditor: Haben belastet, Soll entlastet.
   //Deckt beide Buchungsweisen einer Gutschrift ab - negativer Betrag im
   //Haben oder positiver Betrag im Soll.
   nBooked := nHaben-nSoll

   IF Empty(reb->Betrag)
      Aadd(aList,__NewRow("0",0,nBooked,aDetail))
   ELSEIF nCount == 0
      Aadd(aList,__NewRow("K",nReb,0,aDetail))
   ELSE
      nDiff := Round(nBooked-nReb,2)
      IF Abs(nDiff) > nTol
         Aadd(aList,__NewRow("D",nReb,nBooked,aDetail))
         nSumDiff += nDiff
      ELSEIF nStapel == nCount      //ausschliesslich Stapelbuchungen
         Aadd(aList,__NewRow("S",nReb,nBooked,aDetail))
      ENDIF
   ENDIF

   reb->(dbSkip())
ENDDO

TxtClear()

IF Len(aList) == 0
   Alert(t("Keine Abweichungen")+" ("+LTrim(Str(nChecked))+" "+t("Belege gepr¸ft")+")")
   RETURN
ENDIF

nWName := Max(15,MaxCol()-87)

@ MaxRow(),00 SAY Pad(">ENTER< Rechnung - >STRG+ENTER< Betrag anpassen - >ENTF< entfernen - >STRG+P< Drucken - >ALT+C< Kopieren",MaxCol()) COLOR c_three
@ MaxRow()-1,00 SAY Replicate(Chr(196),MaxCol())
@ MaxRow()-7,00 SAY Replicate(Chr(196),MaxCol())
@ MaxRow()-6,00 SAY Pad("Buchungen: Datum    Soll   Haben        Brutto +/-. *=Stapel  Text",MaxCol())
@ 01,00 SAY Pad(LTrim(Str(nChecked))+" Belege geprÅft - "+LTrim(Str(Len(aList)))+" Abweichungen - Summe "+LTrim(Str(nSumDiff,14,2))+" EUR",MaxCol())

oBrowse := TaBrowse():New(03,00,MaxRow()-8,MaxCol())
oBrowse:lBox := .F.
oBrowse:NewColumn(Pad(Pad("Fehler",18)+" "+Pad("Index",9)+" "+Pad("Beleg",18)+" "+Pad("Lieferant/Konto",nWName)+" "+;
                      "         REB"+" "+"     Gebucht"+" "+"      Diff",MaxCol()-2),{||
   LOCAL hD := oBrowse:CurrentDataRow()
   LOCAL cRow
   IF hD == NIL
      RETURN Space(MaxCol()-2)
   ENDIF
   cRow := Pad(hErrors[hD["ERROR"]],18)+" "
   cRow += Str(hD["ID"],9)+" "
   cRow += Pad(hD["BELEG"],18)+" "
   cRow += Pad(hD["NAME"],nWName)+" "
   IF hD["ERROR"] == "M"
      cRow += Space(12+1+12+1+10)
   ELSE
      cRow += Str(hD["REB"],12,2)+" "+Str(hD["BOOKED"],12,2)+" "+Str(hD["BOOKED"]-hD["REB"],10,2)
   ENDIF
   RETURN Pad(cRow,MaxCol()-2)
})

oBrowse:bAnyFun := {||
   LOCAL hD := oBrowse:CurrentDataRow()
   LOCAL nX
   @ MaxRow()-5,00 CLEAR TO MaxRow()-2,MaxCol()
   IF hD != NIL
      FOR nX := 1 TO Min(4,Len(hD["DETAIL"]))
         @ MaxRow()-6+nX,00 SAY Pad(hD["DETAIL"][nX],MaxCol())
      NEXT
   ENDIF
   RETURN .T.
}

oBrowse:AddKey(K_ESC,{|| .F. })
oBrowse:AddKey(K_ENTER,{||
   LOCAL hD := oBrowse:CurrentDataRow()
   LOCAL aFiles
   IF hD != NIL
      aFiles := GetArchiveFiles({"ER"=>hD["ID"]})
      ASort(aFiles,,,{|x,y| x[6] < y[6] })
      IF Len(aFiles) == 0
         Tr_MsgBox(t("Keine Rechnungsdatei gefunden"))
      ELSE
         Wapi_ShellExecute(,"open",ATail(aFiles)[6])
      ENDIF
   ENDIF
   RETURN .T.
})
oBrowse:AddKey(K_CTRL_ENTER,{||
   LOCAL hD := oBrowse:CurrentDataRow()
   LOCAL nNew,nOld
   IF hD == NIL
      RETURN .T.
   ENDIF
   IF ! hD["ERROR"] $ "D0"      //nur hier gibt es einen Buchungsbetrag als Sollwert
      Tr_MsgBox(t("Hier gibt es keinen ¸bernehmbaren Buchungsbetrag"))
      RETURN .T.
   ENDIF
   nNew := hD["BOOKED"]
   IF Tr_MsgBox({t("Betrag im Rechnungseingangsbuch anpassen?"),;
                 "Index "+LTrim(Str(hD["ID"],9))+"  "+Trim(hD["BELEG"]),;
                 t("bisher")+": "+LTrim(Str(hD["REB"],14,2)),;
                 t("neu")+":    "+LTrim(Str(nNew,14,2))},,{"Nein","Ja"}) != 2
      RETURN .T.
   ENDIF
   reb->(dbSetOrder( 1 ))
   IF ! reb->(dbSeek( Str(hD["ID"],9) ))
      Tr_MsgBox(t("Beleg nicht gefunden"))
      RETURN .T.
   ENDIF
   nOld := reb->Betrag
   LETO_BEGINTRANSACTION()
   BEGIN SEQUENCE
      reb->(Rec_Lock())
      reb->Betrag := nNew
      rebp->(Add_Rec())
      rebp->ID       := hD["ID"]
      rebp->DateTime := TtoS(DateTime())
      rebp->Type     := "BETR"
      rebp->Person   := Tr_Getini(28)
      rebp->Rev      := reb->Rev
      rebp->Grund    := Left(LTrim(Str(nOld,12,2))+" > "+LTrim(Str(nNew,12,2)),20)
      __FixProjectCost(hD["ID"],nNew)
      LETO_COMMITTRANSACTION()
   RECOVER
      LETO_ROLLBACK()
      Tr_MsgBox(t("Fehler beim Speichern"))
      RETURN .T.
   END
   HB_ADel(aList,oBrowse:CurrentRow(),.T.)
   RETURN .T.
})
oBrowse:AddKey(K_DEL,{|| HB_ADel(aList,oBrowse:CurrentRow(),.T.) })
oBrowse:AddKey(K_ALT_C,{||
   LOCAL cData := "Fehler;Index;Beleg;Lieferant/Konto;REB;Gebucht;Differenz"+CRLF
   LOCAL hD
   FOR EACH hD IN aList
      cData += hErrors[hD["ERROR"]]+";"+LTrim(Str(hD["ID"],9))+";"+Trim(hD["BELEG"])+";"+Trim(hD["NAME"])+";"
      cData += LTrim(Str(hD["REB"],14,2))+";"+LTrim(Str(hD["BOOKED"],14,2))+";"+LTrim(Str(hD["BOOKED"]-hD["REB"],14,2))+CRLF
   NEXT
   gtSetClipBoard(HB_OemToAnsi(cData))
   Tr_MsgBox(t("In die Zwischenablage kopiert"))
   RETURN .T.
})
oBrowse:AddKey(K_CTRL_P,{||
   LOCAL aEnv := SaveEnv()
   LOCAL hD,cX
   StartPrint(,,"PDF")
   oPdf := GetCurrentPrinterObject():Data
   oPdf:SetFont("COURIER")
   oPdf:NewPage("A4","L")
   oPdf:AtSay(HB_OemToAnsi("BetragsprÅfung Rechnungseingangsbuch "+LTrim(Str(nYear,4))+" - "+DtoC(Date())))
   oPdf:NewLine()
   oPdf:AtSay(HB_OemToAnsi(LTrim(Str(nChecked))+" Belege geprÅft, "+LTrim(Str(Len(aList)))+" Abweichungen, Summe "+LTrim(Str(nSumDiff,14,2))+" EUR"))
   oPdf:NewLine()
   oPdf:AtSay(Pad("Fehler",18)+" "+Pad("Index",9)+" "+Pad("Beleg",18)+" "+Pad("Lieferant/Konto",30)+" "+;
              "         REB"+" "+"     Gebucht"+" "+"      Diff")
   FOR EACH hD IN aList
      oPdf:NewLine()
      oPdf:AtSay(HB_OemToAnsi(Pad(hErrors[hD["ERROR"]],18)+" "+Str(hD["ID"],9)+" "+Pad(hD["BELEG"],18)+" "+Pad(hD["NAME"],30)+" "+;
                 Str(hD["REB"],12,2)+" "+Str(hD["BOOKED"],12,2)+" "+Str(hD["BOOKED"]-hD["REB"],10,2)))
      FOR EACH cX IN hD["DETAIL"]
         oPdf:NewLine()
         oPdf:AtSay(HB_OemToAnsi("   "+cX))
      NEXT
   NEXT
   CopyPrint()
   RestEnv(aEnv,.T.)
   RETURN .T.
})

oBrowse:aData := aList
oBrowse:EventLoop()

RETURN

/*----------------------------------------------------------------------------
   Projektkosten nachziehen. GetProjectCostValue() liefert fÅr Typ "ER"
   unverÑndert pjcst->Summe zurÅck - der Wert ist eine Kopie von reb->Betrag
   und muss mitgepflegt werden. projcost hat keinen Index auf Rebid, daher
   ein Durchlauf in natÅrlicher Satzreihenfolge. LÑuft innerhalb der
   Transaktion - das Entsperren macht der Commit.
----------------------------------------------------------------------------*/
STATIC FUNCTION __FixProjectCost(nID,nNew)
LOCAL nOrder := pjcst->(IndexOrd())
pjcst->(dbSetOrder( 0 ))
pjcst->(dbGoTop())
DO WHILE ! pjcst->(EOF())
   IF Trim(pjcst->Typ) == "ER" .AND. pjcst->Rebid == nID
      pjcst->(Rec_Lock())
      pjcst->Summe := nNew
   ENDIF
   pjcst->(dbSkip())
ENDDO
pjcst->(dbSetOrder( nOrder ))
RETURN NIL

/*----------------------------------------------------------------------------
   Datensatz fÅr die Liste aufbauen (arbeitet auf dem aktuellen reb-Satz)
----------------------------------------------------------------------------*/
STATIC FUNCTION __NewRow(cError,nReb,nBooked,aDetail)
LOCAL cName
Default(@aDetail,{})
IF reb->Liefnr == 0
   cName := LTrim(Str(reb->Konto))+" "+Trim(reb->Name)
ELSE
   cName := Trim(reb->Name)
ENDIF
RETURN {"ERROR" =>cError,;
        "ID"    =>reb->ID,;
        "BELEG" =>Trim(reb->Beleg),;
        "NAME"  =>cName,;
        "REB"   =>nReb,;
        "BOOKED"=>nBooked,;
        "DETAIL"=>aDetail}

/*----------------------------------------------------------------------------
   Summe der Brutto-BetrÑge einer Seite (lHaben = Kreditor im Haben).
   aDetail wird um eine Zeile je Buchung ergÑnzt, nCount zÑhlt die
   gewerteten Buchungen beider Seiten.
----------------------------------------------------------------------------*/
STATIC FUNCTION __SumSide(aBookings,hCreditors,hIgnore,aTexts,lHaben,aDetail,nCount,nStapel)
LOCAL hBooking,nSum := 0
LOCAL nKonto,nGegen,nGross
LOCAL aSplits,hSplit
LOCAL cSplit
LOCAL cMark

FOR EACH hBooking IN aBookings
   nKonto := IF(lHaben,hBooking["HABEN"],hBooking["SOLL"])
   nGegen := IF(lHaben,hBooking["SOLL"],hBooking["HABEN"])
   IF nKonto == 0 .OR. ! HHasKey(hCreditors,nKonto)
      LOOP                                            //andere Seite oder Splitzeile
   ENDIF

   nGross := hBooking["NETTO"]+hBooking["UST"]
   cMark  := IF(lHaben,"+","-")
   cSplit := ""

   IF __IsIgnoredText(hBooking["TEXT"],aTexts)
      cMark := "."                                    //WÑhrungsdifferenz
   ELSEIF nGegen == 0                                 //Splitbuchung
      aSplits := LX_GetSplitBooking(hBooking["NR"],hBooking["JAHR"],IF(lHaben,"S","H"),hBooking["STAPEL"])
      cSplit  := __SplitInfo(aSplits)
      //Nur im Soll kann sich hinter einem Split eine Zahlung verbergen. Steht der
      //Kreditor im Haben, ist es die Rechnung selbst und die Splitzeilen sind
      //Aufwandskonten - ein Ausschluss wÑre dort immer falsch.
      IF ! lHaben .AND. AScan(aSplits,{|x| __IsIgnored(x["KONTO"],hIgnore,.T.) }) != 0
         cMark := "."                                 //Zahlung in einer der Splitzeilen
      ELSEIF Empty(nGross)                            //Sammelzeile fÅhrt keinen Betrag
         FOR EACH hSplit IN aSplits
            nGross += hSplit["NETTO"]+hSplit["UST"]
         NEXT
      ENDIF
   ELSEIF __IsIgnored(nGegen,hIgnore)
      cMark := "."                                    //Zahlung / ausgeschlossenes Konto
   ENDIF

   IF cMark != "."
      nSum += nGross
      nCount++
      IF hBooking["STAPEL"]
         nStapel++
      ENDIF
   ENDIF

   Aadd(aDetail,DtoC(hBooking["DATUM"])+" "+Str(hBooking["SOLL"],6)+" "+Str(hBooking["HABEN"],6)+" "+;
                Str(nGross,13,2)+" "+cMark+IF(hBooking["STAPEL"],"*"," ")+" "+cSplit+Trim(hBooking["TEXT"]))
NEXT

RETURN nSum

/*  Buchungstexte, die nicht zur Rechnung selbst gehoeren - vor allem die
    Waehrungsdifferenz. Der Umlaut bleibt aussen vor, weil der Text als OEM
    zurueckkommt; "HRUNGDIFF" ohne "s" faengt den Schreibfehler aus
    lex_wahrungsdiff.prg mit ab. Erweiterbar ueber REBCHK_IGNTEXT.          */
STATIC FUNCTION __IsIgnoredText(cText,aTexts)
LOCAL cU := Upper(cText)
LOCAL cFind
FOR EACH cFind IN aTexts
   IF ! Empty(cFind) .AND. AT(Upper(AllTrim(cFind)),cU) != 0
      RETURN .T.
   ENDIF
NEXT
RETURN .F.

/*  Die Konten der Splitzeilen fÅr die Anzeige - macht nachvollziehbar,
    warum eine Splitbuchung gewertet oder ausgeschlossen wurde.           */
STATIC FUNCTION __SplitInfo(aSplits)
LOCAL cInfo := ""
LOCAL nX
FOR nX := 1 TO Min(4,Len(aSplits))
   cInfo += IF(Empty(cInfo),""," ")+LTrim(Str(aSplits[nX]["KONTO"]))
NEXT
IF Len(aSplits) > 4
   cInfo += "..."
ENDIF
RETURN IF(Empty(cInfo),"(Split leer) ","(Split "+cInfo+") ")

/*  lInSplit == .T. prÅft eine Splitzeile. Dort zÑhlen nur die Konten, die
    eine Zahlung kennzeichnen - ein Nachlass ist als Splitzeile Teil der
    Rechnung und darf sie nicht komplett aus der Wertung nehmen.          */
STATIC FUNCTION __IsIgnored(nKonto,hIgnore,lInSplit)
Default(@lInSplit,.F.)
IF nKonto >= 9000 .OR. (nKonto >= 1200 .AND. nKonto <= 1299) .OR. ;
   nKonto == 1360 .OR. nKonto == 1590 .OR. nKonto == 1591
   RETURN .T.                        //Finanzkonto - immer eine Zahlung
ENDIF
IF ! HHasKey(hIgnore,nKonto)
   RETURN .F.
ENDIF
RETURN hIgnore[nKonto] .OR. ! lInSplit
