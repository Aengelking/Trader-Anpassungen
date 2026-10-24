/**
  * Analyse für die R+V Warenkreditversicherung
  *
  * betrachtet werden die letzten 12 Monate
  *
  **/
PROCEDURE RUN_REPORT_RV_WKV  
  LOCAL nX,nY,nA
  LOCAL hCust
  LOCAL dEnd := StoD(Str(Year(Date())-1,4)+"1231") //Date()
  LOCAL dStart := AddMonth(dEnd,-12)
  LOCAL hBranchen,aBranchen
  LOCAL hBrturn,nValue,nPayAmount,dLastPay,dLastDate,oXML
  LOCAL cMarket,oMainActivity,oActivityCode,nBranche,cScr  
  LOCAL cBranch
  LOCAL nTurnOver,cKunde,aInvoices,nOpen,nMaxOpen,nTurntotal
  LOCAL nI,oGet
  LOCAL nInl_120,nInl_120_Offen,nInl_20,nInl_20_Offen,nInl_3,nInl_3_Offen
  LOCAL nAus_120,nAus_120_Offen,nAus_20,nAus_20_Offen,nAus_3,nAus_3_Offen
  LOCAL nTurn_3,nTurn_20,nTurn_120
  LOCAL Getlist := {}

  MEMVAR c_five,c_one

Head("Analyse für die R+V Warenkreditversicherung")

NetUse("englsre","re",.F.,0)
NetUSe("enras","ras",.F.,0)
NetUse("engkund","ku",.F.,0)
NetUse("wz08en","wz")
NetUse("currency","cur")

hCust := {=>} //alle Kunden

hBranchen := GetBranchen()
aBranchen := HGetValues(hBranchen)

hBrTurn   := {=>}

TxtBox("Bitte warten...")

ras->(dbSetOrder( 2 ))  //rechnr

re->(dbSetORder(8)) //str(reposnr)+str(rechnr)
re->(dbGoTop())

//collect invoices
Do While ! re->(Eof()) .AND. re->reposnr == 0
   If re->Rechdat >= dStart .AND. re->Rechdat <= dEnd //letzte 12 Monate
      @ 01,00 SAY re->Rechnr
      nValue := ( re->poswt - re->preis ) * If(re->rate!=0,re->rate,If(!Empty(re->money).AND.re->Money!="E",Currate(re->Money,"V"),1))

      If ! HHasKey(hCust,re->Kunde)
         hCust[re->Kunde] := { "match"=>re->Kunde,"turnover"=>0,"invoices"=>{=>},"max_open"=>0 }
      Endif
      hCust[re->Kunde]["turnover"] += nValue

      dLastPay   := StoD("")
      nPayAmount := 0

      If ras->(dbSeek( re->Rechnr ))
         Do While ras->Rechnr == re->Rechnr
            dLastPay   := ras->paydate
            nPayAmount += ras->Skonto
            ras->(dbSkip())
         Enddo
      Endif

      hCust[re->Kunde]["invoices"][re->Rechnr] := {"netto"=>nValue,"total"=>re->Poswt,"date"=>re->rechdat,"pay_date"=>dLastPay,"payed"=>re->Poswt==nPayAmount,"open"=>0 }

   Endif
   re->(dbSkip())
Enddo

nInl_3 := 0
nInl_3_Offen := 0
nInl_20 := 0
nInl_20_Offen := 0
nInl_120 := 0
nInl_120_Offen := 0

nAus_3 := 0
nAus_3_Offen := 0
nAus_20 := 0
nAus_20_Offen := 0
nAus_120 := 0
nAus_120_Offen := 0

nTurnOver := 0
nTurn_3 := 0
nTurn_20 := 0
nTurn_120 := 0

nX := 1
@ 02,13 SAY "/"+LTrim(Str(Len(hCust)))
Do While nX <= Len(hCust)
   @ 02,00 SAY nX
   cKunde := HGetKeyAt(hCust,nX)
   //Alert(ValToPrg( hCust[cKunde]["invoices"] ))
   aInvoices := HGetValues( hCust[cKunde]["invoices"] )
   ASort(aInvoices,,,{|x,y| x["date"] < y["date"] .OR. (x["date"] == y["date"] .AND. x["total"] < y["total"]) })

   nI := 1
   dLastPay := SToD("")
   dLastDate := SToD("")
   nOpen := 0
   nMaxOpen := 0
   nTurntotal := 0
   Do While nI <= Len(aInvoices)
      If aInvoices[nI]["date"] >= dLastPay
         nOpen := 0
      Endif

      nOpen += aInvoices[nI]["total"]
      dLastPay := aInvoices[nI]["pay_date"]
      aInvoices[nI]["open"] := nOpen
      nMaxOpen := Max(nOpen,nMaxOpen)
      nTurnTotal += aInvoices[nI]["netto"]
      nI++
   Enddo

// hCust[cKunde]["invoices"] := aInvoices
   hCust[cKunde]["max_open"] := nMaxOpen
   nTurnOver                 += nTurnTotal

   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( cKunde+"K" ))

   If ku->CountryIso == "DE" .OR. Empty(ku->CountryIso)
      If nMaxOpen <= 3000
         nInl_3++
         nInl_3_Offen += nMaxOpen
      ELSEIf nMaxOpen <= 20000
         nInl_20++
         nInl_20_Offen += nMaxOpen
      Else
         nInl_120++
         nInl_120_Offen += nMaxOpen
      Endif
   Else
      If nMaxOpen <= 3000
         nAus_3++
         nAus_3_Offen += nMaxOpen
      ELSEIf nMaxOpen <= 20000
         nAus_20++
         nAus_20_Offen += nMaxOpen
      Else
         nAus_120++
         nAus_120_Offen += nMaxOpen
      Endif
   Endif
   
   cMarket := ""
   oXML := CS_GetCompanyReportFromArchive(ku->Nummer)
   IF oXml != NIL
    oMainActivity := TXmlIteratorScan():New(oXML:oRoot):Find("MainActivity")
          IF oMainActivity != NIL

          oActivityCode := TXmlIteratorScan():New(oMainActivity):Find("ActivityCode")
          IF oActivityCode != NIL
             /*cMarket += oActivityCode:cData
             cCode := ""
             FOR nA := 1 TO Len(oActivityCode:cData) STEP 2
                IF nA > 1
                  cCode += "."
                ENDIF
                cCode += SubStr(oActivityCode:cData,nA,2)
             NEXT
             IF wz->(dbSeek( cCode ))
               cMarket := wz->Bezeichnun
             ENDIF*/
             cMarket := Left(oActivityCode:cData,2)
          ENDIF
       ENDIF
   ENDIF

   IF Empty(cMarket) //Market not found, request user to set it
      If ! HHasKey(hBranchen,ku->Branch) .OR. ku->Branch == "AUDI"
         If .F. //nTurnTotal > 2500
            //hBranchen[ku->Branch] := 0
            nBranche := 1
            cScr := SaveScreen()
            SetColor(c_five)
            @ 01,00 CLEAR TO 16,50
            @ 02,01 SAY "Branche ("+ku->Branch+") nicht gefunden fuer "+ku->Kunde
            @ 03,01 SAY ku->Name1
            @ 04,01 SAY ku->Town+" "+GetCountryName(ku->CountryIso)
   //       @ 05,01,15,49 GET nBranche LISTBOX aBranchen
   
            oGet := Get():new(05,01,{|xValue| IIf( xValue==NIL, nBranche, nBranche := xValue ) },"nBranche")
            AAdd(GetList,oGet) //_GET_(nBranche,"nBranche",NIL,,) ) ;
            ATail(GetList):Control := _ListBox_(ATail(Getlist):row,ATail(Getlist):col,15,49,nBranche,aBranchen,,,,,,.F.,.F. )
            ATail(GetList):reader := { | a,b,c,d | GuiReader(a,b,c,d ) } 
            ATail(GetList):Control:Display()
            READ
            RestScreen(,,,,cScr)
            SetColor(c_one)
            If nBranche != 0 .AND. LastKey() != 27
               ku->(Rec_Lock(0))
               ku->Branch := HGetKeyAt(hBranchen,nBranche)
               ku->(dbUnLock())
               cBranch := ku->Branch
            Endif
         Elseif ! Empty(ku->Branch)
            ku->(Rec_Lock(0))
            ku->Branch := ""
            ku->(dbUnLock())
         Endif
      Endif
      cMarket := Left(ku->Branch,2)
   ENDIF

   If ! HHasKey(hBrturn,cMarket)
      hBrTurn[cMarket] := 0
   Endif
   hBrturn[cMarket] += nTurnTotal
   nX++
Enddo

CLEAR
? "GROSSKUNDEN"
? Pad("Kunde",8)+" "+PadL("Umsatz",12)+" "+PadL("Max. Offen",12)
nX := 1
Do While nX <= Len(hCust)
   cKunde := HGetKeyAt(hCust,nX)
   If hCust[cKunde]["max_open"] >= 20000
      ? cKunde,Str(hCust[cKunde]["turnover"],12,2),Str(hCust[cKunde]["max_open"],12,2)
      /*? Pad("Datum",8)+" "+pad("Summe",12)+" "+Pad("Offen",12)
      nI := 1
      Do While nI <= Len(hCust[cKunde]["invoices"])
                  ? hCust[cKunde]["invoices"][nI]["date"],Str(hCust[cKunde]["invoices"][nI]["total"],12,2),Str(hCust[cKunde]["invoices"][nI]["open"],12,2)
         nI++
      Enddo*/
   Endif
   nX++
Enddo

? 
? "Struktur der Forderung"
? "               ","Inland","            ","Ausland"
? "               ","Anzahl","Durch. Offen","Anzahl","Durch. Offen"
? "Bis   3.000 EUR",Str(nInl_3,6),If(nInl_3>0,Str(nInl_3_Offen/nInl_3,12,2),Space(12)),Str(nAus_3,6),If(nAus_3>0,Str(nAus_3_Offen/nAus_3,12,2),Space(12))
? "Bis  20.000 EUR",Str(nInl_20,6),If(nInl_20>0,Str(nInl_20_Offen/nInl_20,12,2),Space(12)),Str(nAus_20,6),If(nAus_20>0,Str(nAus_20_Offen/nAus_20,12,2),Space(12))
? "Bis 120.000 EUR",Str(nInl_120,6),if(nInl_120>0,Str(nInl_120_Offen/nInl_120,12,2),Space(12)),Str(nAus_120,6),If(nAus_120>0,Str(nAus_120_Offen/nAus_120,12,2),Space(12))
?
? "Branchen"
SInkey(0,128)
nX := 1
Do While nX <= Len(hBrTurn)
   cBranch := HGetKeyAt(hBrTurn,nX)
   ? cBranch,Pad(If(HHasKey(hBranchen,cBranch),hBranchen[cBranch],""),60),HGetValueAt(hBrTurn,nX)
   nX++
Enddo
SInkey(0)

#include 'X:\run\creditsafe.prg'
