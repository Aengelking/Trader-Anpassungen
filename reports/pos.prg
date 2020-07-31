#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
;
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)

FUNCTION Bericht_Pos(nType,nYear,nMonth,nManu,nArt,cLang,lCSV,nData)

LOCAL cYear
LOCAL cManuMatch,cMatchcode,nX
LOCAL hCustomer := {=>}
LOCAL hProducts :={=>}
LOCAL aManu
LOCAL getlist := {}
LOCAL nOldTot,nNewTot,nTotQty,hCust,hArt
LOCAL hBranch
LOCAl nCount,lSetup := .T.,hLang := {"DE"=>"Deutsch","EN"=>"Englisch"}
LOCAL oMonthGet
LOCAL oExtra,dYtdDate,nY,cKunde,cMarket,oXml,oMainActivity,oActivityCode,cCode,cMatch,cCountry,hCountry,bPrint
LOCAL aData,hData :=  {=>}


Default(@nType,2)
Default(@nYear,Year(Date()))
Default(@nMonth,Month(Date())-1)
Default(@nManu,0)
Default(@nArt,1)
Default(@cLang,"EN")
Default(@lCSV,.T.)
Default(@nData,0)  //0=all reports as hash,1=customer report, if set > 0 only this data will be generated


nManu++ //as the first entry is "ALL suppliers"

Head("Generate POS Reporting")

NetUse("englsre","re")
NetUse("engauf","auf")
NetUse("manufact","manu")
NetUse("artikel","art")
NetUse("engkund","ku")
NetUse("artlief","ali")



aManu := GetManufacturerArray()
HB_AIns(aManu[2],1,"ALLE",.T.)
HB_AIns(aManu[1],1,0,.T.)

IF ! GetConfigValue("BATCHMODE")

@ 01,00 SAY "Berichtstyp" 
@ 01,12,04,40 GET nType LISTBOX {"Jahresbericht","Monatsbericht"} STATE {||
   LOCAL nVal := nType
   IF GetActive() != NIL .AND. GetActive():Name == "nType"
      nVal := GetActive():Control:Buffer
   ENDIF
   IF nVal == 1 //nType != 1 .AND. ! lSetup //changing to one
      @ 05,00 SAY Pad("ab Jahr",11)
      //@ 05,18 CLEAR TO 05,26
      @ 05,18 SAY "Monat"
      @ 05,28 SAY "fr YTD, 0=aktuelles Datum"
      //lSetup := .F.
      nMonth := 0
      IF VaLType(oMonthGet) == "O"         
         // oMonthGet:row := -1
         oMonthGet:Display()
      ENDIF
   ELSE
      lSetup := .F.      
      @ 05,00 SAY Pad("Jahr",11)
      @ 05,18 SAY "Monat"
      @ 05,28 CLEAR TO 05,28+26
      IF nMonth == 0
         nYear := Year(Date())
         nMonth := Month(Date())-1      
      ENDIF
      // oMonthGet:Row := 05
      IF VaLType(oMonthGet) == "O"   
         oMonthGet:Display()
      ENDIF
   ENDIF
   RETURN .T.
}
@ 05,12 GET nYear PICTURE "9999" VALID nYear >= 2000
@ 05,24 GET nMonth PICTURE "99" VALID (nType == 1 .AND. nMonth == 0) .OR. nMonth >= 1 .AND. nMonth <= 12 // WHEN nType == 2
oMonthGet := ATail(getlist)
//@ 05,24 CLEAR TO 05,26
@ 06,00 SAY "Hersteller "
@ 06,12,23,40 GET nManu LISTBOX aManu[2] DROPDOWN
@ 07,00 SAY "Ziel"
@ 07,12,10,20 GET nArt LISTBOX {"extern","intern"} STATE {|| 
   /*LOCAL oGet := GetActive()
   LOCAL nVal := nArt
   IF oGet != NIL .AND. oGet:Name =="nArt"
      nVal := oGet:Control:Buffer
   ENDIF
   IF nVal == 1
      cLang := "EN"
   ELSE
      cLang := "DE"
   ENDIF
   Alert(Str(Len(getlist)))
   IF Len(getlist) >= 6      
      getlist[6]:VarPut(cLang)  
      getlist[6]:Control:Display()
   ENDIF*/
}
@ 11,00 SAY "Sprache"
@ 11,12,15,20 GET cLang LISTBOX hLang ASSOCIATIVE
READ
ENDIF

IF LastKey() == 27
 RETURN NIL
ENDIF

dYtdDate := Date()
IF nType == 1 .AND. nMonth != 0
   dYtdDate :=  EoM(AddMonth(Date(),nMonth-Month(Date())))
ENDIF
re->(dbSetOrder(9))
re->(dbSeek( Str(nYear,4)+StrZero(IF(nType==1,1,nMonth),2)+"01" ,.T. ))

IF aManu[1,nManu] != 0
   manu->(dbSeek( Str(aManu[1,nManu],5) ))
   ku->(dbSetOrder(8))
   ku->(dbSeek( Str(manu->Address,6) ))
   cManuMatch := ku->Kunde
ENDIF

ali->(dbSetOrder( 1 ))

Select("re")
SET FILTER TO re->reposnr != 0 .AND. re->AoQty != 0 .AND. ! re->Folge
//SET RELATION TO re->Matchcode INTO art

TxtBox("Daten werden gesammelt    ")
nCount := 0

DO WHILE IF(nType==1,Year(re->Rechdat) >= nYear,Year(re->Rechdat) == nYear .AND. Month(re->Rechdat) == nMonth) .AND. re->Rechdat < dYtdDate .AND. ! re->(EOF())
   IF nCount%250 == 0
       @ MaxRow()/2,MaxCol()/2+10 SAY Pad(Replicate(".",(nCount/250) % 4),3) COLOR c_five
   ENDIF
   cYear := Str(Year(re->Rechdat),4)
   IF Year(re->Rechdat) == Year(Date())
     cYear += "YTD"
   ENDIF
   //IF re->reposnr != 0 .AND. re->AoQty != 0 .AND. ! re->Folge
      art->(dbSeek( re->Matchcode ))
      IF (aManu[1,nManu] == 0 .OR. art->Manufactur == aManu[1,nManu]) //.AND. (nArt == 2 .OR. art->LagerArt)  //this also excludes parts with folgeartikel (e.g. KS14696/59-xxx)
         IF nArt == 1 .AND. aManu[1,nManu] != 0 .AND. ali->(dbSeek( cManuMatch+Str(art->Artikelnr,6) )) .AND. ! Empty(ali->Artlief)
            cMatchcode := Trim(ali->Artlief)
         ELSE
            cMatchcode := Trim(re->Matchcode)
         ENDIF
         IF ! HHAsKey(hCustomer,re->Kunde)
            hCustomer[re->Kunde] := {"ART"=>{=>},"TOTALS"=>{=>}}
         ENDIF
         IF ! HHasKey(hProducts,cMatchcode)
            hProducts[cMatchcode] :={=>}
         ENDIF

         FOR nX := 1 TO IF(Year(re->Rechdat) == Year(Date())-1 .AND. re->Rechdat <= AddMonth(dYtdDate,-12),2,1)
            IF nX == 2
               cYear += "YTD"
            ENDIF

            IF ! HHasKey(hCustomer[re->Kunde]["ART"],cMatchcode)
                   hCustomer[re->Kunde]["ART"][cMatchcode] := {=>}
            ENDIF
            IF ! HHasKey(hCustomer[re->Kunde]["ART"][cMatchcode],cYear)
               hCustomer[re->Kunde]["ART"][cMatchcode][cYear] := {"QTY"=>0,"PRICE"=>0}
            ENDIF
            IF ! HHasKey(hCustomer[re->Kunde]["TOTALS"],cYear)
               hCustomer[re->Kunde]["TOTALS"][cYear] := 0
            ENDIF

            nOldTot := hCustomer[re->Kunde]["ART"][cMatchcode][cYear]:price*hCustomer[re->Kunde]["ART"][cMatchcode][cYear]:qty
            nNewTot := re->AoQty*re->Preis/Max(1,re->PE)*re->Rate
            nTotQty := hCustomer[re->Kunde]["ART"][cMatchcode][cYear]:qty+re->AoQty

            IF nTotQty != 0
               hCustomer[re->Kunde]["ART"][cMatchcode][cYear]:price := (nOldTot+nNewTot)/nTotQty
            ENDIF
            hCustomer[re->Kunde]["ART"][cMatchcode][cYear]:Qty   += re->AoQty

            hCustomer[re->Kunde]["TOTALS"][cYear] += nNewTot

            IF ! HHAsKey(hProducts[cMatchcode],cYear)
               hProducts[cMatchcode][cYear] := {"QTY"=>0,"PRICE"=>0}
            ENDIF
            nOldTot := hProducts[cMatchcode][cYear]:price*hProducts[cMatchcode][cYear]:qty
            nNewTot := re->AoQty*re->Preis/Max(1,re->PE)*re->Rate
            nTotQty := hProducts[cMatchcode][cYear]:qty+re->AoQty

            IF nTotQty != 0
               hProducts[cMatchcode][cYear]:price := (nOldTot+nNewTot)/nTotQty
            ENDIF
            hProducts[cMatchcode][cYear]:Qty   += re->AoQty
         NEXT
         //? re->Kunde,re->Matchcode,re->AoQty
         //re->Rate AoQty pe preis

      //ENDIF
   ENDIF
   nCount++
   re->(dbSkip())
ENDDO

re->(dbClearFilter())
re->(dbClearRelation())

//@ 12,22 CLEAR TO 12,25
TxtClear()

IF cLang == "DE"
   hBranch := GetBranchen()
ELSE
   hBranch := {;
      "SANI   "=>"Sanitary",;
      "DIEN   "=>"CEM",;
      "SOLA   "=>"Renable Energy",;
      "AUTO   "=>"Automotive",;
      "MATE   "=>"Vending machines",;
      "KLIN   "=>"Door bells",;
      "UNTH   "=>"Audio",;
      "MEDI   "=>"Medical",;
      "ILUM   "=>"Illumiation",;
      "MILI   "=>"Military",;
      "TELE   "=>"Telematic",;
      "MARI   "=>"Marine",;
      "FOER   "=>"Pumps",;
      "IT     "=>"IT",;
      "ELEG   "=>"Distribution",;
      "MESS   "=>"Measuring equipment",;
      "STEU   "=>"Controls",;
      "MASC   "=>"Machines",;
      "ELEK   "=>"electronic equipment",;
      "ARCH   "=>"?",;
      "SICH   "=>"Saftey",;
      "VERK   "=>"trafic controls",;
      "REIN   "=>"Cleaning equipment";
   }
   NetUse("wz08en","wz")

ENDIF

IF nData == 0 .OR. nData == 1

   //SET PRINTER TO (Trim(Tr_Getini(1))+"\export\POS_"+Trim(aManu[2][nManu])+"_"+Str(nYear,4)+IF(nType==1,"","-"+StrZero(nMonth,2))+".csv")
   //SET PRINTER ON
   aData := {{}}
   IF nArt == 2
      //?? "Matchcode;"
      Aadd(aData[1],"Matchcode")
   ELSE
      Aadd(aData[1],"Kunde")
   ENDIF
   IF cLang == "DE"
      //?? "Kunde;Nummer;Land;Branche;Artikel"      
      Aadd(aData[1],"Nummer")
      Aadd(aData[1],"Land")
      Aadd(aData[1],"Branche")
      Aadd(aData[1],"Artikel")
   ELSE
      //?? "Company;No;Country;Sector;Part"
      Aadd(aData[1],"Company")
      Aadd(aData[1],"No")
      Aadd(aData[1],"Country")
      Aadd(aData[1],"Sector")
      Aadd(aData[1],"Part")
   ENDIF
   IF aManu[1,nManu] == 0
      //?? ";Hersteller"
      Aadd(aData[1],"Hersteller")
   ENDIF

   IF nType == 1
      FOR nY := nYear TO Year(Date())+1
         IF nY >= Year(Date())
            cYear := Right(Str(nY-1,4),2)+" YTD"
         ELSE
            cYear := Right(Str(nY,4),2)
         ENDIF
         ///?? ";"+IF(cLang=="DE","Menge","QTY")+" "+cYear+";"+IF(cLang=="DE","VK","Price")+" "+cYear
         Aadd(aData[1],IF(cLang=="DE","Menge","QTY")+" "+cYear)
         Aadd(aData[1],IF(cLang=="DE","VK","Price")+" "+cYear)
         Aadd(aData[1],IF(cLang=="DE","Gesamt","Total")+" "+cYear)
      NEXT
   ELSE
      //?? ";"+IF(cLang=="DE","Menge","QTY")+";"+IF(cLang=="DE","VK","Price")
      Aadd(aData[1],IF(cLang=="DE","Menge","QTY"))
      Aadd(aData[1],IF(cLang=="DE","VK","Price"))
      Aadd(aData[1],IF(cLang=="DE","Gesamt","Total"))
   ENDIF
   FOR EACH hCust IN hCustomer
      cKunde := hCust:__enumKey()
      ? cKunde
      ku->(dbSetOrder(1))
      ku->(dbSeek( cKunde+"K" ))
      oExtra := ku->(ExtraData():new( ku->Nummer ))
      IF HHasKey(hBranch,ku->Branch)
         cMarket := hBranch[ku->Branch]
      ELSEIF Empty(ku->Branch)
   /*
            nBranch := 0
            SAVE SCREEN
            SET PRINTER OFF
            SetColor(c_five)
            @ 10,10 CLEAR TO 21,50
            @ 10,10 TO 14,50
            @ 11,11 SAY "Kunde:   "+ku->Kunde
            @ 12,20 SAY Pad(Trim(ku->Name1)+" "+ku->Name2,49-20)
            @ 13,11 SAY "Branche:"
            @ 13,20,20,49 GET nBranch LISTBOX HGetValues(hBranch) //DROPDOWN
            READ
            SetColor(c_one)
            RESTORE SCREEN
            SET PRINTER ON
            IF LastKey() == 27 .OR. nBranch == 0
               RETURN .F.
            ENDIF
            ku->(dbSeek( cKunde+"K" ))
            ku->(Rec_Lock())
            ku->Branch := HGetKeyAt(hBranch,nBranch)
            ku->(dbUnLock())
            cMarket := hBranch[ku->Branch]*/
            cMArket := ""
      ELSE
         cMarket := "NOT FOUND "+ku->Branch
      ENDIF
      

      IF cLang != "DE"
         oXML := CS_GetCompanyReportFromArchive(ku->Nummer)
         IF oXml != NIL
         cMarket := "CS"
         oMainActivity := TXmlIteratorScan():New(oXML:oRoot):Find("MainActivity")
               IF oMainActivity != NIL

               oActivityCode := TXmlIteratorScan():New(oMainActivity):Find("ActivityCode")
               IF oActivityCode != NIL
                  cMarket += oActivityCode:cData
                  cCode := ""
                  FOR nX := 1 TO Len(oActivityCode:cData) STEP 2
                     IF nX > 1
                        cCode += "."
                     ENDIF
                     cCode += SubStr(oActivityCode:cData,nX,2)
                  NEXT
                  IF wz->(dbSeek( cCode ))
                     cMarket := wz->Bezeichnun
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF

      FOR EACH hArt IN hCust["ART"]
         cMatch := hArt:__enumKey()
         art->(dbSeek(cMatch))
         IF cLang == "DE"
            cCountry := GetCountryName(ku->CountryIso)
         ELSE
         hCountry := {;
            "DE"=>"Germany",;
            "AT"=>"Austria",;
            "CH"=>"Switzerland";
         }
         IF HHasKey(hCountry,ku->CountryIso)
            cCountry := hCountry[ku->CountryIso]
         ELSE
            cCountry := GetCountryName(ku->CountryIso)
         ENDIF

         ENDIF
         //? IF(nArt==2,HB_OemToAnsi(Trim(ku->Kunde))+";","")+IF(nArt==1 .AND. (Trim(ku->CompForm)  $ "GBR EINZE EK PRIVA" .OR. oExtra:Nda),"NDA ENGELKING;",HB_OemToAnsi(Trim(Trim(ku->Name1)+" "+ku->Name2))+";"+LTrim(Str(ku->Nummer)))+";"+HB_OemToAnsi(cCountry)+";"+HB_OemToAnsi(Trim(cMarket))+";"+Trim(cMatch)
         Aadd(aData,{})
         IF nArt==2
            Aadd(Atail(aData),HB_OemToAnsi(Trim(ku->Kunde)))
         ELSEIF nArt == 1
            IF (Trim(ku->CompForm)  $ "GBR EINZE EK PRIVA" .OR. oExtra:Nda)
               Aadd(Atail(aData),"NDA ENGELKING")
            ELSE
               Aadd(Atail(aData),Trim(Trim(ku->Name1)+" "+ku->Name2))
            ENDIF
         ENDIF   
         Aadd(Atail(aData),ku->Nummer)
         Aadd(Atail(aData),(cCountry))
         Aadd(Atail(aData),Trim(cMarket))
         Aadd(Atail(aData),Trim(cMatch))
         IF aManu[1,nManu] == 0
            //?? ";"+aManu[2,art->Manufactur+1]
            Aadd(Atail(aData),aManu[2,art->Manufactur+1])
         ENDIF
         bPrint := {||
            IF HHasKey(hArt,cYear)
               //?? ";"+StrTran(Transform(hArt[cYear]:Qty,Me(art->me)),".",",")+";"+StrTran(Str(hArt[cYear]:Price),".",",")
               Aadd(Atail(aData),Val(Transform(hArt[cYear]:Qty,Me(art->me))))
               Aadd(Atail(aData),Round(hArt[cYear]:Price,2))
               Aadd(Atail(aData),Round(hArt[cYear]:Qty*hArt[cYear]:Price,2))
            ELSE
               //?? ";0;0"
               Aadd(Atail(aData),0)
               Aadd(Atail(aData),0)
               Aadd(Atail(aData),0)
            ENDIF
            RETURN NIL
         }
         IF nType == 1
            FOR nY := nYear TO Year(Date())+1
               IF nY >= Year(Date())
                  cYear := Str(nY-1,4)+"YTD"
               ELSE
                  cYear := Str(nY,4)
               ENDIF

               Eval(bPrint)
            NEXT
         ELSE
            cYear := Str(nYear,4)
            IF nYear == Year(Date())
               cYear += "YTD"
            ENDIF
            Eval(bPrint)
         ENDIF
      NEXT
   NEXT
   IF lCSV
      SaveAsCSV((Trim(Tr_Getini(1))+"\export\POS_"+Trim(aManu[2][nManu])+"_"+Str(nYear,4)+IF(nType==1,"","-"+StrZero(nMonth,2))+".csv"),aData)
   ENDIF
   IF nData == 2
      nManu--
      RETURN aData
   ENDIF
   hData["CUSTOMER"] := aData
   //SET PRINTER OFF
   //SET PRINTER TO
ENDIF

IF nData == 0 .OR. nData == 2
   //SET PRINTER TO (Trim(Tr_Getini(1))+"\export\POS_"+Trim(aManu[2][nManu])+"_"+Str(nYear,4)+IF(nType==1,"","-"+StrZero(nMonth,2))+"_TOTALS.csv")
   //SET PRINTER ON
   aData := {{}}
   IF nArt == 2
      //?? "Matchcode;"
      Aadd(aData[1],"Matchcode")
      Aadd(aData[1],"Nummer")
   ELSE
      Aadd(aData[1],"Kunde")
   ENDIF
   //?? "Kunde;Branche"
   
   Aadd(aData[1],"Branche")
   FOR nY := nYear TO Year(Date())+1
      IF nY >= Year(Date())
         cYear := Right(Str(nY-1,4),2)+" YTD"
      ELSE
         cYear := Right(Str(nY,4),2)
      ENDIF
      //?? ";Summe "+cYear
      Aadd(aData[1],"Summe "+cYear)
   NEXT
   ku->(dbSetOrder(1))
   FOR EACH hCust IN hCustomer
      cKunde := hCust:__enumKey()
      @ MaxRow(),00 SAY cKunde
      ku->(dbSeek( cKunde+"K" ))
      IF HHasKey(hBRanch,ku->Branch)
         cMarket := hBRanch[ku->Branch]
      ELSEIF Empty(ku->Branch)
         cMArket := ""
      ELSE
         cMarket := "NOT FOUND"
      ENDIF
      //? IF(nArt==2,HB_OemToAnsi(Trim(ku->Kunde))+";","")+HB_OemToAnsi(Trim(Trim(ku->Name1)+" "+ku->Name2))+";"+HB_OemToAnsi(Trim(cMarket))
      Aadd(aData,{})
      IF nArt==2
         //Aadd(Atail(aData),HB_OemToAnsi(Trim(ku->Kunde)))
         Aadd(Atail(aData),Trim(ku->Kunde))
         Aadd(Atail(aData),ku->Nummer)
      ELSE
         Aadd(Atail(aData),Trim(Trim(ku->Name1)+" "+ku->Name2))
      ENDIF
      Aadd(Atail(aData),Trim(cMarket))
      bPrint := {||
         IF HHasKey(hCust["TOTALS"],cYear)
            //?? ";"+StrTran(Str(hCust["TOTALS"][cYear]),".",",")
            Aadd(Atail(aData),hCust["TOTALS"][cYear])
         ELSE
            //?? ";0"
            Aadd(Atail(aData),0)
         ENDIF
         RETURN NIL
      }
      IF nType == 1
         FOR nY := nYear TO Year(Date())+1
               IF nY >= Year(Date())
                  cYear := Str(nY-1,4)+"YTD"
               ELSE
                  cYear := Str(nY,4)
               ENDIF
               Eval(bPrint)
         NEXT
      ELSE
         cYear := Str(nYear,4)
         IF nYear == Year(Date())
            cYear += "YTD"
         ENDIF
         Eval(bPrint)
      ENDIF
   NEXT
   IF lCSV
      SaveAsCSV(Trim(Tr_Getini(1))+"\export\POS_"+Trim(aManu[2][nManu])+"_"+Str(nYear,4)+IF(nType==1,"","-"+StrZero(nMonth,2))+"_TOTALS.csv",aData)
   ENDIF
   IF nData == 2
      nManu--
      RETURN aData
   ENDIF
   hData["TOTALS"] := aData
   //SET PRINTER OFF
   //SET PRINTER TO
ENDIF   

//SET PRINTER TO (Trim(Tr_Getini(1))+"\export\POS_"+Trim(aManu[2][nManu])+"_"+Str(nYear,4)+IF(nType==1,"","-"+StrZero(nMonth,2))+"_PRODUCTS.csv")
//SET PRINTER ON
aData := {{}}
//?? "Artikel"
Aadd(aData[1],"Artikel")

IF aManu[1,nManu] == 0
   //?? ";Hersteller"
   Aadd(aData[1],"Hersteller")
ENDIF

FOR nY := nYear TO Year(Date())+1
   IF nY >= Year(Date())
      cYear := Right(Str(nY-1,4),2)+" YTD"
   ELSE
      cYear := Right(Str(nY,4),2)
   ENDIF
   //?? ";Menge "+cYear+";VK "+cYear
   Aadd(aData[1],"Menge "+cYear)
   Aadd(aData[1],"VK "+cYear)
NEXT

FOR EACH hArt IN hProducts
   cMatch := hArt:__enumKey()
   ? cMatch
   art->(dbSeek(cMatch))
   //? Trim(cMatch)
   Aadd(aData,{Trim(cMatch)})
   
   IF aManu[1,nManu] == 0
      //?? ";"+aManu[2,art->Manufactur+1]
      Aadd(Atail(aData),aManu[2,art->Manufactur+1])
   ENDIF

   bPrint := {||
      IF HHasKey(hArt,cYear)
         //?? ";"+StrTran(Transform(hArt[cYear]:Qty,Me(art->me)),".",",")+";"+StrTran(Str(hArt[cYear]:Price),".",",")
         Aadd(Atail(aData),Val(Transform(hArt[cYear]:Qty,Me(art->me))))
         Aadd(Atail(aData),hArt[cYear]:Price)
      ELSE
         //?? ";0;0"
         Aadd(Atail(aData),0)
         Aadd(Atail(aData),0)
      ENDIF
      RETURN NIL
   }
   IF nType == 1
      FOR nY := nYear TO Year(Date())+1
         IF nY >= Year(Date())
            cYear := Str(nY-1,4)+"YTD"
         ELSE
            cYear := Str(nY,4)
         ENDIF
         Eval(bPrint)
      NEXT
   ELSE
      cYear := Str(nYear,4)
      IF nYear == Year(Date())
         cYear += "YTD"
      ENDIF
      Eval(bPrint)
   ENDIF
NEXT
IF lCSV
   SaveAsCSV(Trim(Tr_Getini(1))+"\export\POS_"+Trim(aManu[2][nManu])+"_"+Str(nYear,4)+IF(nType==1,"","-"+StrZero(nMonth,2))+"_PRODUCTS.csv",aData)
ENDIF
IF nData == 3
   nManu--
   RETURN aData
ENDIF
hData["PRODUCTS"] := aData
//SET PRINTER OFF
//SET PRINTER TO



//Tone(700,10);Tone(900,10);Tone(1100,10)
RETURN hData

#include 'X:\run\creditsafe.prg'
