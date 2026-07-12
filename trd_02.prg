#ifndef __XHARBOUR__
   #xtranslate ShellExecute([<x,...>])        => Wapi_ShellExecute(<x>)
#endif
#include 'inkey.ch'

STATIC pClientData

PROC TRD_ADDRESS(nContactID)

LOCAL lFin
LOCAL oReport
LOCAL aBrowse := {},nActiveBrowse := 1,oBrowse
LOCAL aButtons := {}
LOCAL cKunde
LOCAL cTitleColor := "R+/R"
LOCAL cHiliteColor := "R/GR*"
LOCAL cNumFormat := "@E 9,999,999"
LOCAL cDecNumFormat := cNumFormat+".99"
LOCAL bShowCreditLimit
LOCAL hTurnOver
LOCAL cType,nYear
LOCAL nRec
LOCAL oExtra,oAdresse
LOCAL cColor,nRow,cLetter
LOCAL aAngebot
LOCAL nHeight,nLeft,nRight,nTop,nBottom
LOCAL lBlink,nOrder
LOCAL aCompGroups,nX,aGroup,hGroup,hTurn2,nY,aYears,nMonth,cBook,cBill,nCur
LOCAL bDispTurnover,nOpenOrders,lPrePay,lShowList
LOCAL oButton,nAgedTime,nDays,hAct
LOCAL oIter,oNode,cStatus,hStatus
LOCAL bDisplayCreditWorth,oSOAP
LOCAL nP,nW,hC,cData,nB,aRegex
LOCAL bChangeBrowse
LOCAL nKey
LOCAL hData
LOCAL cAngFilter
LOCAL cTimeStamp := "",nHistPos := 0
LOCAL lExit := .F.
LOCAL oTeam
LOCAL cPermGroup
LOCAL lBig := MaxCol() >= 160 .AND. (SystemUser():HasRole(1) .OR. SystemUser():HasRole(14)) //Nur fÅr den Vertrieb und Projektmanagement
LOCAL oNoCrm,nLead
LOCAL lWinOnly := ValType(nContactID) == "N"
LOCAL cKSMatch := Space(25)
LOCAL oArtikel
LOCAL oArtBrowse
LOCAL oArtFilter
LOCAL bGetFreigabe,bGetLastShip 
LOCAL oAufBrowse
LOCAL cFilter,nR,nCount,cName,hField,cLang
LOCAL aKeys := {}
LOCAL oPortalButton
//LOCAL oUsr := SystemUser()

MEMVAR mlShowInvoiceList,c_five,MSB,trVer,hmtx_busy
PUBLIC mlShowInvoiceList,hmtx_busy

cPermGroup := IF(ku->Group=="K".OR. (ku->Group>="1" .AND. ku->Group <= "9"),"CUSTOMER",IF(ku->Group=="L","SUPPLIER","OTHER"))

IF ! SystemUser():HasPermission("READ","ADR_"+cPermGroup)
   RETURN
ENDIF

IF ValType(hmtx_busy) == "P"
   IF ! hb_mutexLock(hmtx_busy)
      RETURN
   ELSE
      
   ENDIF
ENDIF

NetUse("portalusr","pusr")

oAdresse := Adresse():New()
oAdresse:Load(ku->Nummer)

oExtra := ku->(ExtraData():New( ku->Nummer ))
lFin := SystemUser():HasPermission("UPDATE","ADR_CUSTOMER_CREDITLIMIT") //AScan({9,34},Tr_Getini(28)) != 0

pClientData := hb_mutexCreate()

NetUse("angebot","ang",.F.,0)
NetUse("engauf","auf")
ang->(dbSetOrder( 7 ))
NetUse("notes","nts",.F.,0)
NetUse("contacts","conts",.F.,0)
conts->(dbSetOrder(1))
NetUse("artikel","art")
NetUse("dblog","dblog")
NetUse("viewlog","vlog")
NetUse("engabg","abg")

vlog->(Add_Rec(0))
vlog->Nummer := oAdresse:Nummer
vlog->Datum  := Date()
vlog->Time   := Time()
vlog->TimeStamp  := TtoS(DateTime())
vlog->Type   := "V"
vlog->User   := Tr_Getini(28)
vlog->(dbUnLock())

SetColor(c_five)

IF ku->Group == "K"
   nHeight := 56 //IF(lFin,52,50)
ELSE
   nHeight := 27
ENDIF

IF lWinOnly
   nLeft := 0
   nTop  := 0
   nRight := IF(ku->Group=="K",159,78)
   nBottom := nHeight
   SetMode(nHeight+1,nRight+1)
   //CreateMainWindow()      
   SetColor(c_five)   
   //Alert("Here")   
ELSE
   nLeft := 03
   nRight := IF(lBig .AND. ku->Group == "K",162,81)
   nTop := MaxRow()/2-nHeight/2
   nBottom:= nTop+nHeight
ENDIF

//TxtClear()
DO WHILE ! lExit
   @ nTop,nLeft CLEAR TO nBottom,nRight
   @ nTop,nLeft TO nBottom,nRight

   If ! Empty(oAdresse:KuSchutz)
      lBlink := SetBlink(.T.)
      nRec := ku->(Recno())
      nOrder := ku->(dbSetOrder( 8 ))
      If ku->(dbSeek( Str( oAdresse:KuSchutz ,6) ))
         DispBox(nTop,nLeft,nBottom,nRight,Replicate(Chr(219),4),"GR+")
         @ nBottom,nLeft+1 SAY Pad(" "+t("GESCH‹TZT F‹R:")+" "+Trim(ku->Name1)+" "+ku->Name2,nRight-nLeft-1) COLOR "N/GR*"
      Endif
      ku->(dbSetOrder( nOrder ))
      ku->(dbGoTo( nRec ))
   Endif

   IF oExtra:Nda
      cColor := SetColor(cHiliteColor)
      @ nTop,nRight+1 CLEAR TO nBottom,nRight+3
      nRow := IF(nBottom<nTop+36,nTop,nTop+10)
      FOR EACH cLetter IN "GEHEIMHALTUNGSVEREINBARUNG"
         @ nRow,nRight+2 SAY cLetter
         nRow++
      NEXT
      SetColor(cColor)
   ENDIF

   IF SystemUser():HasRole(9) .AND. (oExtra:EmpB .OR. oExtra:Get("EmpB-MAT"))
      @ nTop-2,nLeft TO nTop,nRight
      @ nTop,nLeft SAY Chr(195)
      @ nTop,nRight SAY Chr(180)
      cColor := SetColor(cHiliteColor)
      @ nTop-1,nLeft+1 CLEAR TO nTop-1,nRight-1
      nRow := IF(nBottom<nTop+36,nTop,nTop+10)      
      @ nTop-1,nLeft+1 SAY IF(oExtra:Empb,"VollstÑndiger EMPB (Vorlagestufe 2)","")+IF(oExtra:Get("Empb-MAT"),IF(oExtra:Empb," und","")+" Materialnachweis","")
      SetColor(cColor)
   ENDIF

   IF ! Empty(oExtra:AgorumID)
      oButton := HBPushButton():New(nTop,nLeft+16,"Ablage&ordner")
      oButton:sBlock := {||
         WAPI_ShellExecute(,"open","\\engelking.intern.agorumcloud.com\files\Engelking Elektronik GmbH\"+IF(ku->Group=="K","Kunden","Lieferanten")+"\"+Left(ku->Kunde,1)+"\"+Left(ku->Kunde,2)+"\"+Trim(ku->Kunde)+" ("+Trim(Trim(ku->Name1)+" "+ku->Name2)+")")

         RETURN NIL
      }
      Aadd(aButtons,oButton)
   ENDIF

   IF oAdresse:Group == "K" .AND. SystemUser():HasPermission("R","PORTAL_CUSTOMER")      
      oButton := HBPushButton():New(nTop,nLeft+16,"&Kundenportal")
      oButton:sBlock := {||
         NetUse("portalusr","pusr")
         pusr->(dbSetOrder(1))
         IF ! pusr->(dbSeek( Lower(SystemUser():Email) ))
            Tr_MsgBox("Bitte zuerst im Portal registrieren.")
         ELSE
            pusr->(Rec_Lock())
            pusr->Address := ku->Nummer
            pusr->(dbUnLock())            
            WAPI_ShellExecute(,"open","https://portal.engelking.com")
         ENDIF
         pusr->(dbCloseArea())

         RETURN NIL
      }
      Aadd(aButtons,oButton)

   ENDIF



   @ nTop,nLeft+2 SAY "[" + oAdresse:kunde + "]"
   IF ! Empty(cTimeStamp)
      @ nTop,nLeft+13 SAY "[" + Left(TtoC(StoT(cTimeStamp)),17) + "]" COLOR "R/GR*"
   ENDIF
   @ nTop,nRight-Len(LTrim(Str(ku->Nummer,6)))-3 SAY "[" + LTrim(Str(ku->Nummer,6)) + "]"

   IF(ku->group == "K", bold( nTop+1,nLeft+2,msb[4],0 ),IF(ku->group == "L", bold( nTop+1,nLeft+2,msb[5],0 ),bold( nTop+1,7,msb[6]+ku->group+"    ",0 )))
   //ku->( yesnotes() )
   //notiz := .T.


   //Top Left
   DevPos( nTop+2, nLeft+2 )
   DevOut( oAdresse:name1 )
   DevPos( nTop+3, nLeft+2 )
   DevOut( oAdresse:name2 )
   DevPos( nTop+4, nLeft+2 )
   DevOut( oAdresse:Street )
   DevPos( nTop+5, nLeft+2 )
   DevOut( TRIM( oAdresse:plz ) + " " + oAdresse:town )
   DevPos( nTop+6, nLeft+2 )
   DevOut( GetCountryName(oAdresse:CountryIso) )

   bold(nTop+8,nLeft+2,msb[7] + oAdresse:telefon,0)

   @ nTop+9, nLeft+2 SAY "EMAIL    " + Pad(oAdresse:Email,27)
   @ nTop+10, nLeft+2 SAY msb[9] + oAdresse:telefax

   @ nTop+35-19,nLeft+2 SAY Pad(SKONTVA(oAdresse:Skonto,"D",,,.F.),nRight-nLeft-2)

   DevPos( nTop+1, 44 )
   DevOut( if(oAdresse:group = "L",msb[10] + oAdresse:kundennr,msb[11] + oAdresse:kundennr) )
   //DevPos( nTop+2, 44 )
   //DevOutPict( msb[12] + ku->bank, "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" )
   //DevPos( nTop+3, 44 )
   //DevOut( msb[13] + ku->konto )
   DevPos( nTop+2, 44 )
   DevOut( msb[14] + STR( ku->charge ) )


   @ nTop+35-17, nLeft+1 TO nTop+35-17,80 //divider
   @ nTop+35-17, nLeft+2 SAY " "+t("Kontaktpersonen")+" " COLOR cTitleColor

   IF oAdresse:Group == "K"
      IF SystemUser():HasPermission("READ","SALESORDER")         
         @ nTop+35-9, nLeft+1 TO nTop+35-9,80 //divider
         @ nTop+35-9, nLeft+2 SAY " "+t("Auftr‰ge")+" " COLOR cTitleColor

         /*oButton := HBCHeckBox():New(nTop+35-9, nLeft+13,"Nur Rahmen")
         oButton:sBlock := {||
            oAufBrowse:cFor := 'Right(Str(auf->DTerm,4),2) == "99"'
            oAufBrowse:Display()
         }
         
         Aadd(aButtons,oButton)*/
      ENDIF


      @ nTop+35, nLeft+1 TO nTop+35,80 //divider
      IF SystemUser():HasPermission("READ","SALESQUOTES")         
         @ nTop+35, nLeft+2 SAY " "+t("Angebote")+" " COLOR cTitleColor         
      ENDIF
      @ nTop+43, nLeft+1 TO nTop+43,80 //divider
      IF SystemUSer():HasPermission("READ","PROJECTS")
         @ nTop+43, nLeft+2 SAY " "+t("Projekte")+" " COLOR cTitleColor
      ENDIF
      @ nTop+51, nLeft+1 TO nTop+51,80 //divider

      IF lBig
         @ nTop,85 SAY " "+t("Kundenspezifische Artikel")+" " COLOR cTitleColor

         @ nTop+1,82 TO nBottom-1,82
         IF SystemUser():HasRole(1) //Vertrieb
            @ nTop+18,83 TO nTop+18,nRight-1 //divider
            @ nTop+18,85 SAY " "+t("Leads")+" " COLOR cTitleColor
            @ nTop+26,83 TO nTop+26,nRight-1 //divider
         ENDIF

         @ nBottom-10,83 TO nBottom-10,nRight-1
         @ nBottom-10,85 SAY " "+t("Kurzinfo")+" " COLOR cTitleColor

      ENDIF
   ENDIF
   
   //UmsÑtze anzeigen
   IF SystemUser():HasPermission("READ","ADR_"+cPermGroup+"_TURNOVER")
      @ nTop+5,44 SAY "Umsatz abfragen mit >LEER<"

      @ nTop+3,44 TO nTop+3,76
      @ nTop+3,45 SAY " Umsatz " COLOR cTitleColor

      @ nTop+8,44 TO nTop+8,76
      //@ nTop+5,44 SAY "Daten werden gesammelt...  " COLOR "W+/R*"
      bDispTurnover := {|hTurnover|

         @ nTop+4,44 CLEAR TO nTop+7,81
         @ nTop+5,44 SAY "Daten werden gesammelt...  " COLOR "W+/R*"
         hTurnover := If(oAdresse:Group=="K",GetCustomerTurnover(oAdresse:kunde),GetSupplierTurnover(oAdresse:Kunde))

         aCompGroups := {}
         IF oAdresse:Group == "K"
            Aadd(aCompGroups,{"BACHMANG","BACHMANR","BACHMANN"})
            Aadd(aCompGroups,{"FP","FRANCOTY","FPINOVO"})
            Aadd(aCompGroups,{"STORZ","STORZSCH","STORZIMG"})
            Aadd(aCompGroups,{"VARTA","VARTAR"})
         ELSEIF oAdresse:Group == "L"
            Aadd(aCompGroups,{"ITW","ITWMETAL","ITWAPPLI"})
         ENDIF



         @ nTop+5,44 CLEAR TO nTop+5,81

         DevPos( nTop+4, 44 )
         DevOut( "Aktuell:" +" EUR "+ (Transform( hTurnover["current"],cNumFormat)) )
         DevPos( nTop+5, 44 )
         DevOut( "Vorjahr:" +" EUR "+(Transform( hTurnover["last"],cNumFormat )) )
         @ nTop+6,44 SAY "3-Jahre: EUR "+(Transform(hTurnover["last3"],cNumFormat))
         
         @ nTop+7,44 SAY "Gesamt : EUR "+(Transform(hTurnover["total"],cNumFormat))

         nX := AScan(aCompGroups,{|x| Trim(oAdresse:Kunde) $ x })
         IF nX != 0
            @ nTop+3,44+23 SAY " Gruppe "
            aGroup := aCompGroups[nX]
            hGroup := {"current"=>hTurnover["current"],"last"=>hTurnover["last"],"last3"=>hTurnover["last3"],"total"=>hTurnover["total"]}
            nRec := ku->(Recno())
            FOR EACH cKunde IN aGroup
               IF cKunde != Trim(ku->Kunde)
                  hTurn2 := If(ku->Group=="K",GetCustomerTurnover(Pad(cKunde,8)),GetSupplierTurnover(Pad(cKunde,8)))
                  ku->(dbGoto(nRec))
                  hGroup["current"] += hTurn2["current"]
                  hGroup["last"]    += hTurn2["last"]
                  hGroup["last3"]   += hTurn2["last3"]
                  hGroup["total"]   += hTurn2["total"]
               ENDIF
            NEXT
            @ nTop+4,44+23 SAY Transform( hGroup["current"],cNumFormat)
            @ nTop+5,44+23 SAY Transform( hGroup["last"],cNumFormat)
            @ nTop+6,44+23 SAY Transform( hGroup["last3"],cNumFormat)
            @ nTop+7,44+23 SAY Transform( hGroup["total"],cNumFormat)
         ENDIF


         If oAdresse:Group == "K"
         @ nTop+10, 44 SAY "Offen  EUR: " + Transform(hTurnover["open"],cDecNumformat)

            cType := ""
            If hTurnover["current"]+hTurnover["last"] > 0
               cType := "KUNDE"
            Elseif hTurnover["total"] > 0
               cType := "EHEMALIGER KUNDE"
            Elseif ang->(dbSeek( ku->Kunde ))
               cType := "INTERESSENT"
            Elseif nts->(dbSeek(ku->Kunde+ku->Group,.T.))
               cType := "KONTAKTIERT"
            Else
               cType := "KEIN KONTAKT"
            Endif
            @ nTop,44 SAY "[ "+cType+" ]"



         ELSEIF ku->Group == "L"
            @ nTop+9,44 SAY  "Offene Best.: EUR "+(Transform(hTurnover["open"],cNumFormat))
            @ nTop+10,44 SAY "WE ohne Rechnung"
            @ nTop+11,44 SAY "     Aktuell: EUR "+(Transform(hTurnover["unbilled_current"],cNumFormat))
            @ nTop+12,44 SAY "     Vorjahr: EUR "+(Transform(hTurnover["unbilled_last"],cNumFormat))

            IF HHasKey(hTurnover,"months") //.AND. Tr_Getini(28) == 9 .AND. Tr_MsgBox("Save data?",,{"Yes","No"}) == 1
               SET PRINTER TO (Trim(Tr_Getini(1))+"\export\"+Trim(ku->kunde)+"_turnover.csv")
               SET PRINTER ON
               SET CONSOLE OFF
               nY := 1
               FOR EACH cType IN {"bookings","billings"}
                  ?? cType
                  aYears := HGetKeys(hTurnover["months"])
                  ASort(aYears)
                  FOR EACH nYear IN aYears
      //            Do While nY <= Len(hTurnover["months"])
                     //nYear := HGetKeyAt(hTurnover["months"],nY)
                     nMonth := 1
                     cBook := ""
                     cBill := ""
                     ? Str(nYear,4)
                     FOR nMonth := 1 TO 12
         //               nCur := Currate(ku->Money,"E",StoD( EoM(Str(nYear,4)+StrZero(nMonth,2)+"01") ) )
                        nCur := 1
                     // cBook += Chr(59)+StrTran(Ltrim(Str(hTurnover["months"][nYear][nMonth]["bookings"]/nCur,12,2)),".",",")
                     // cBill += Chr(59)+StrTran(Ltrim(Str(hTurnover["months"][nYear][nMonth]["billings"]/nCur,12,2)),".",",")
                        ?? Chr(59)+StrTran(Ltrim(Str(hTurnover["months"][nYear][nMonth][cType+"SC"],12,2)),".",",")
                     NEXT
                        //? str(nYear,4)+" bookings"+cBook
                        //? str(nYear,4)+" billings"+cBill
                     //nY++
                  //Enddo
                  NEXT
                  ? ""
               NEXT
               SET PRINTER TO
               SET PRINTER OFF
               SET CONSOLE ON
            ENDIF
         ENDIF
         RETURN NIL
      }
   ELSE
      bDispTurnover := {|| .T. }
   ENDIF

   //@ nTop+35-22,nLeft+2 SAY "Angelegt am: "+DToC(ku->K_Seit)
   IF Tr_Getini(28) == 9
      @ nTop,nLeft+33 SAY "[ "+DToC(ku->K_Seit)+" ]"
   ENDIF

   If ku->Group == "K"
      IF SystemUser():HasPermission("READ","ADR_CUSTOMER_TURNOVER")
         nOpenOrders := GetCustomerOpenOrders(ku->kunde)
         @ nTop+26,51 SAY " Gesamt EUR "+(Transform(nOpenOrders,cDecNumFormat))+" "
      ELSE
         nOpenOrders := 0
      ENDIF

      IF SystemUser():HasPermission("READ","ADR_CUSTOMER_CREDITLIMIT")
         NetUse("skontoa","sk")
         lPrePay := sk->(IsPrePay(ku->skonto))

         bShowCreditLimit := {||
            LOCAL nCreditLimit
                        
            //IF nOpenOrders > 0 .OR. hTurnover["current"]+hTurnover["last"] > 0  //Kreditlimit nur bei aktiven Kunden anzeigen, vermeidet die Abfrage bei Creditsafe
               nCreditLimit := GetCustomerCreditLimit(ku->Kunde)
               IF ! lPrePay
                  
                  IF nCreditLimit == 0.2
                     @ nTop+09,44+12 SAY "0 (Keine Auskunft)"
                  ELSEIF nCreditLimit == 0.1
                     @ nTop+09,44+12 SAY "0 (Rechtsform fehlt)"
                  ELSEIF nCreditLimit == 0.5
                     @ nTop+09,44+12 SAY "0 (Rating schlecht)"
                  ELSEIF nCreditLimit == -2
                     @ nTop+09,44+12 SAY "0 (Nicht aktiv)"
                  ELSEIF nCreditLimit == -3
                     @ nTop+09,44+12 SAY "0 (Kein Limit festgelegt)"
                  ELSEIF nCreditLimit == -4
                     @ nTop+09,44+12 SAY "0 (Kein Rating gefunden)"
                  ELSEIF nCreditLimit == -5
                     @ nTop+09,44+12 SAY "0 (Land nicht gedeckt)"               
                  ELSEIF nCreditLimit == -6
                     @ nTop+09,44+12 SAY "0 (Zu spÑt bezahlt)"   
                  ELSE
                     @ nTop+09,44+12 SAY LTrim(Transform(nCreditLimit,cNumFormat))
                  ENDIF
               ENDIF
            //ENDIF
            RETURN NIL
         }

         IF ! lPrePay
            @ nTop+09, 44 SAY "Limit  EUR: "
         ELSE
            @ nTop+09, 44 SAY "Kredit "+Currate(ku->Money,"X")+": " + LTRIM(Transform(GetCustomerCredit(ku->Kunde),cDecNumFormat))
         ENDIF
      ELSE
         
         bShowCreditLimit := {|| .F. }
         lPrePay := .F.
      ENDIF

      IF lFin
         oButton := HBPushButton():New(nBottom,nLeft+1,"Rechnungs&historie anzeigen")
         oButton:sBlock := {||
            mlShowInvoiceList := .T.
            Eval(bShowCreditLimit)
            mlShowInvoiceList := .F.
            RETURN NIL
         }
         Aadd(aButtons,oButton)

         
      ENDIF
      nAgedTime := 0
      nDays := GetCustomerPayTime(ku->Kunde,@nAgedTime)
      IF SystemUser():HasPermission("READ","ADR_"+cPermGroup+"_TURNOVER")
         @ nTop+35-18, nLeft+2 SAY "Durchschnittliche gewichtete Zahldauer: "+LTrim(Str(nDays,3,0))+" Tag"+If(nDays!=1,"e","")
         If ValType(nAgedTime) == "N"
            ?? " (Vorhersage: "+LTrim(Str(nAgedTime,3,0))+")"
         Endif
      ENDIF
      IF oAdresse:Team != 0
         oTeam := Team():New()
         oTeam:Load(oAdresse:Team)
         @ nTop+35-22,nLeft+2 SAY t("Innendienst")+": "+oTeam:Name COLOR IF(oAdresse:TeamPrime,"GR+/R",c_five)
      ENDIF
      If ku->rep !=0
         @ nTop+35-21,nLeft+2 SAY t("Auﬂendienst")+": "+RepGetName(oAdresse:Rep) COLOR IF(oAdresse:Team!=0 .AND. !oAdresse:TeamPrime,"GR+/R",c_five)
      Endif

      bDisplayCreditWorth := {||
         oReport := CS_GetCompanyReportFromArchive(ku->Nummer)
         IF oReport != NIL .AND. oReport:oRoot != NIL
            oIter := TXmlIteratorScan():New(oReport:oRoot)
            IF ku->CountryIso == "DE"
               oNode := oIter:Find("DECurrentRating")
            ELSE
               oNode := TXmlIteratorScan():New(oIter:Find("CurrentCreditRating")):Find("CommonValue")
            ENDIF
            @ nTop+11, 44 SAY "Rating    : "+IF(oNode!=NIL,oNode:cData,"-")
            @ nTop+12,44  SAY "Status    : "
            oIter:Rewind()
            oNode := oIter:Find("CompanyStatus")
            IF oNode != NIL
               cStatus := oNode:GetAttribute("Code")
               hStatus := {"Active"=>"aktiv","NonActive"=>"nicht aktiv","Pending"=>"schwebend"}
               IF HHasKey(hStatus,cStatus) //.AND. oNode:cData $ "active aktiv Active"
                  @ nTop+12,56 SAY hStatus[cStatus]+IF(Tr_Getini(28)==9.AND.ValType(oNode:cData)=="C"," ("+Lower(oNode:cData)+")","")
               ELSE
                  @ nTop+12,56 SAY "unbekannt"
               ENDIF
            ENDIF
         ELSEIF oReport != NIL
            Alert("Report not readable")
         ENDIF
         RETURN NIL
      }
      Eval(bDisplayCreditWorth)

      
   ENDIF

   IF lFin      
      LoadPrg(Path("run\creditsafe_search.prg"))
      oButton := HBPushButton():New(nBottom-1,nLeft+30,"&Creditsafe Nr. bearbeiten")
         oButton:sBlock := {|| 
            LOCAL cID 
            NetUse("creditsafe","cs")               
            IF cs->(dbSeek( Str(ku->Nummer,6) ))
               Tr_MsgBox("Creditsafe Nummer: "+cs->ID,6)
            ENDIF
            cID := hb_ExecFromArray({"CS_Search",oAdresse:Name1,oAdresse:CountryIso,,40})
            IF cID == NIL
               IF LastKey() == 27
                  RETURN NIL
               ENDIF
               EditCSNumber()
            ELSE
               TxtBox("Auskunft wird geladen")
               oSOAP := CreditSafe()
               oReport := CS_GetCompanyReport(oSoap,cID,3)               
               IF oReport == NIL
                  Tr_MsgBox("Fehler beim laden...")
               ELSE
                  IF cs->(dbSeek( Str(ku->Nummer,6) ))
                     cs->(Rec_Lock())
                  ELSE
                     cs->(Add_Rec())
                     cs->Kunde := ku->Nummer
                  ENDIF
                  cs->Id := cID
                  cs->(dbUnlock())
                  CS_SaveReport(ku->Nummer,oReport)
               ENDIF
               TxtClear()
            ENDIF
            Eval(bShowCreditLimit) 
            RETURN NIL
         }

         Aadd(aButtons,oButton)

         IF lFin .AND. oReport != NIL
            oButton := HBPushButton():New(nBottom-3,nLeft+54,"Auskunft akt&ualisieren")
            oButton:sBlock := {||
               NetUse("creditsafe","cs")
               IF cs->(dbSeek( Str(ku->Nummer,6) )) .AND. ! Empty(cs->ID)
                  TxtBox("Auskunft wird aktualisiert")
                  oSOAP := CreditSafe()
                  oReport := CS_GetCompanyReport(oSoap,cs->ID,3)
                  IF oReport == NIL
                     Tr_MsgBox("Fehler beim laden...")
                  ELSE
                     IF Empty(CS_SaveReport(ku->Nummer,oReport))
                        Tr_MsgBox("Keine neuen Daten vorhanden")
                     ELSE
                        Tr_MsgBox("Daten aktualisiert")
                     ENDIF
                  ENDIF
                  TxtClear()
                  IF ku->Group == "K"
                     Eval(bShowCreditLimit)
                     Eval(bDisplayCreditWorth)
                  ENDIF
               ENDIF
               RETURN NIL
            }
            Aadd(aButtons,oButton)
   
            oButton := HBPushbutton():New(nBottom-3,nLeft+34,"&Auskunft anzeigen")
            oButton:sBlock := {||
               LOCAL aFiles := GetArchiveFiles({"KA"=>ku->Nummer})
               IF Len(aFiles) > 0
                  WAPI_ShellExecute(,"open",Atail(aFiles)[6])
               ENDIF
               RETURN NIL
            }
            Aadd(aButtons,oButton)
         ENDIF
      ENDIF
   
   conts->(dbSetORder( 1 ))
   conts->(dbSeek( Str(ku->Nummer,6),.T. ))
   IF conts->address == ku->Nummer .AND. conts->Active
      /*oButton := HBPushButton():New(nBottom-1,nLeft+58,"&Emails anzeigen")
      oButton:sBlock := {||
         LOCAL aEmails := {}
         LOCAL aDomains := {}
         TxtBox({"Suche...",""})
         conts->(dbSeek( Str(ku->Nummer,6),.T. ))
         DO WHILE  conts->address == ku->Nummer .AND. conts->Active
            IF ! Empty(conts->Email)
               Aadd(aEmails,Trim(conts->Email))
               Aadd(aDomains,"%"+Trim(SubStr(conts->Email,AT("@",conts->Email))))
            ENDIF
            conts->(dbSkip())
         ENDDO
         IF ! DV_Search("",IF(Len(aEmails)>1.AND.Len(aEmails)!=Len(aDomains),aDomains,aEmails),{"TO","FROM"},,MaxRow()/2,MaxCol()/2-4)
            Alert("Kein gefunden")
         ENDIF
         TxtClear()
         RETURN NIL
      }
      Aadd(aButtons,oButton)*/

      oBrowse := conts->(TBrowseTr():New(nTop+35-16,nLeft+2,nTop+35-10,nLeft+30))   
      oBrowse:ColorSpec := "W+/R,GR+/BR,GR+/R,N/GR*"
      oBrowse:HeadSep := ""

      oBrowse:NewColumn( Nil, {|| Pad(conts->Name,36) }, {|| IF(ValType(nContactID)=="N" .AND. conts->Number==nContactID,{3,4},{1,2}) } )
      oBrowse:lBox := .F.
      oBrowse:lArrow := .F.
      oBrowse:WhileBlock := {|| conts->address == ku->Nummer .AND. conts->Active}

      oBrowse:AddKey(K_ENTER,{|| 
         LOCAL cLink      
         LOCAL nChoice
         LOCAL cNumber

         LOCAL aChoice := {}
         LOCAL hC := GetContact(conts->Number)
   //Alert(Trim(conts->name)+" "+Trim(conts->Telephone)+" "+Trim(conts->Email))
         IF ! Empty(conts->Email)         
            Aadd(aChoice,"Email")
            Aadd(aChoice,"Email Zwischenablage")
         ENDIF
         IF ! Empty(conts->Telephone) .OR. ! Empty(conts->Mobile)
            Aadd(aChoice,"Anruf")
         ENDIF
         
         Aadd(aChoice,"Brief")         
         Aadd(aChoice,"abbrechen")      
         nChoice := Tr_MsgBox("Bitte auswÑhlen",,aChoice)
         IF nChoice == 0
            RETURN .T.
         ENDIF         
            
         
         IF aChoice[nChoice] == "Email"
            cLink := If(!Empty(conts->Email),"tic4:/"+"/message?to="+Trim(conts->Email),"")
            gtSetClipboard(cLink)
            IF ! Empty(cLink)
               ShellExecute(NIL, "Open", cLink, "", "", 1)
            ENDIF
         ELSEIF aChoice[nChoice] == "Email Zwischenablage"
            gtSetClipboard(Trim(conts->Email))
         ELSEIF aChoice[nChoice] == "Anruf"
            nChoice := 1
            IF ! Empty(conts->Telephone) .AND. ! Empty(conts->Mobile)
               nChoice := Tr_MsgBox("Bitte Nummer wÑhlen",,{"Telefon","Handy"})
               IF nChoice == 0
                  RETURN .T.
               ENDIF            
            ELSEIF ! Empty(conts->Mobile)
               nChoice := 2
            ENDIF
            IF nChoice == 2               
               cNumber := StrTran(Trim(hC["mobile"])," ","")
            ELSE
               cNumber := StrTran(Trim(hC["fullphone"])," ","")
            ENDIF                        
            //WAPI_ShellExecute(,"open",'"C:\Program Files (x86)\innovaphone\myPBX\myPBXDial.exe"','"'+cNumber+'"')
            //gtSetClipboard('tel:"'+cNumber+'"')
            WAPI_ShellExecute(,"open",'tel://"'+cNumber+'"')
         ELSEIF aChoice[nChoice] == "Brief"
            _OpenLetterTemplate(Trim(conts->Name))
         ENDIF
         RETURN .T. 
      })
      oBrowse:bRestFun := {|| .F. }


      nP := nLeft+32
      nW := 81-nP-9

      oBrowse:bAnyFun := {||
         hC := GetContact(conts->Number)
         @ nTop+35-16,nP SAY "Telefon "+Pad(hC["fullphone"],nW)
         @ nTop+35-15,nP SAY "Handy   "+Pad(conts->Mobile,nW)
         @ nTop+35-14,nP SAY "Fax     "+Pad(hC["fullfax"],nW)
         @ nTop+35-13,nP SAY "Email   "+Pad(conts->Email,nW)
         @ nTop+35-12,nP SAY "Abt.    "+Pad(conts->Department,nW)

         conts->(dbSetOrder( 1 ))        //GetContact changes the indexorder
         NetUse("portalusr","pusr")
         
         IF ku->Group == "K"
            IF !Empty(conts->Email) .AND. pusr->(dbSeek( Lower(Trim(conts->Email)) ))      
               oPortalButton:row := -1
               @ nTop+35-11,nP CLEAR TO nTop+35-11,nP+nW
               @ nTop+35-11,nP SAY "Portal Zugang" COLOR "R/GR*"            
            else            
               oPortalButton:row := nTop+35-11
               oPortalButton:col := nP
               oPortalButton:Display()
            ENDIF
         ENDIF
         
         RETURN .T.
      }
      IF ku->Group == "K"
         //@ nTop+35-11,nP SAY Pad(" ",nW)
         oPortalButton := HBPushButton():New(nTop+35-11,nP,"zum &Portal einladen")
         oPortalButton:sBlock := {||
               LOCAL aEmails := {}
               LOCAL cText,cSubject
               LOCAL hC := GetContact(conts->Number)

               NetUse("portalusr","pusr")

               IF !Empty(conts->Email) .AND. ! pusr->(dbSeek( Lower(Trim(conts->Email)) )) .AND.; //noch kein Portalbenutzer
                     Tr_MsgBox("Einladung versenden?",,{"Ja","Nein"}) == 1
                  Aadd(aEmails,{hC["email"],hC["name"]})
                  //Aadd(aEmails,{"amos.engelking@engelking.de","Amos Engelking"})
                  
                  LoadEmailTemplate("portal_invite",ku->Language,.F.,@cText,hC,{;
                     "email"=>Trim(hC["email"]);
                  },,"UTF-8")

                  IF ku->Language != "D"
                     cSubject := "Invitation to our customer portal"
                  ELSE
                     cSubject := "Einladung zu unserem Kundenportal"
                  ENDIF
                  
                  SendMail(aEmails,cSubject,cText,{{"x:\images\engelking-logo-white.png","cid:engelking-logo"}},,,.T.,,.F.,.F.)   
               ELSEIF Empty(conts->Email)
                  Tr_MsgBox("Keine gÅltige Emailadresse hinterlegt.")
               ENDIF
            RETURN .T.
         }              
         Aadd(aButtons,oPortalButton)
      ENDIF

      IF ValType(nContactID) == "N"
         IF ! conts->(dbSeek(Str(ku->Nummer,6)+"0"+Str(nContactID,4)))
            conts->(dbSeek( Str(ku->Nummer,6),.T. ))
         ENDIF   
      ENDIF
      oBrowse:Display()
      
      
      Aadd(aBrowse,{oBrowse,SaveEnv()})
      
   ELSE
      @ nTop+35-16,38 SAY "---"
   ENDIF

   IF ku->Group == "K"
      IF SystemUser():HasPermission("READ","SALESORDER")         
         auf->(dbSetOrder(2))
         IF auf->(dbSeek( ku->Kunde )) .AND. auf->Bestat < 3
            oAufBrowse := auf->(TBrowseTr():new(nTop+35-8,nLeft+2,nTop+34,80))
            oAufBrowse:HeadSep := ""
            oAufBrowse:NewColumn( Pad("AB-Nr",6)+" "+"Pos "+Pad("Auftragsnr.",20)+" "+Pad("Artikel",25)+" Termin   "+PadL("Offen",8),{||
               IF auf->Kundma == ku->Kunde
                  art->(dbSetOrder( 2 ))
                  art->(dbSeek( Str(auf->Artikelnr,6) ))
                  RETURN Str(auf->Abnr,6)+" "+Str(auf->Itmnr,3)+" "+auf->Aufnr+" "+auf->Matchcode+" "+IF(Right(Str(auf->DTerm,4),2)=="99",NiceWeek(auf->WTerm),If(ku->JustInTime,DToC(auf->BDatum),NiceWeek(auf->DTerm)))+" "+PadL(Transform(auf->VkQty-auf->GelQty,Me(art->Me)),8)
               ENDIF
               RETURN Pad("Keine Auftr‰ge vorhanden",oAufBrowse:nRight-oAufBrowse:nLeft+1)         
            })
            oAufBrowse:WhileBlock := {|| auf->Kundma == ku->Kunde .AND. auf->Bestat < 3 }
            oAufBrowse:AddKey(K_ENTER, {|| Engauft(auf->Abnr) })
            oAufBrowse:lBox := .F.
            oAufBrowse:lArrow := .F.
            oAufBrowse:goTop()
            oAufBrowse:Display()
            oAufBrowse:deHilite()
            Aadd(aBrowse,{oAufBrowse,SaveEnv()})
         ELSE
            @ nTop+35-8,38 SAY "---"
         ENDIF
      ENDIF
      IF SystemUser():HasPermission("READ","SALESQUOTES")
         ang->(dbSetOrder( 7 ))
         cAngFilter := 'bestat < 3 .AND. AT("TEXT",matchcode) != 1'
         ang->(dbSetFilter({|| ang->(&(cAngFilter)) },cAngFilter))
         IF ang->(dbSeek( ku->Kunde ))  //.AND. ang->Bestat < 3
            ang->(dbClearFilter())
            oBrowse := ang->(TBrowseTr():new(nTop+36,nLeft+2,nTop+42,76))
            oBrowse:HeadSep := ""
            oBrowse:cFor := 'bestat < 3 .AND. AT("TEXT",matchcode) != 1'
            oBrowse:ForBlock := {|| ang->(&(cAngFilter)) } //{|| ang->Bestat < 3 .AND. AT("TEXT",ang->matchcode) != 1 }
            oBrowse:NewColumn( Pad("Datum",8)+" "+Pad("Nr.",6)+" "+"Pos "+Pad("Artikel",25)+PadL("Menge",12)+" "+PadL("Preis",12), {|oBrowse|
               LOCAL cLastMatch,nLastAng
               art->(dbSetOrder( 2 ))
               art->(dbSeek( Str(ang->Artikelnr,6) ))
               ang->(dbSkip(-1))
               IF Eval(oBrowse:WhileBlock)
                  cLastMatch := ang->Matchcode
                  nLastAng   := ang->Angnr
               ELSE
                  cLastMatch :=""
                  nLastAng  := 0
               ENDIF
               ang->(dbSkip())
               IF cLastMatch == art->Matchcode .AND. ang->Angnr == nLastAng
                  cData := Space(45)
               ELSE               
                  cData := DToC(ang->Besda)+" "+Str(ang->Angnr,6)+" "+Str(ang->Itmnr,3)+" "
                  IF ! art->PrMatch //AT("@",ang->Matchcode) == 1
                     cData += Pad(ang->Artikel,25)
                  ELSE
                     cData += ang->Matchcode
                  ENDIF
               ENDIF

               cData += PadL(Transform(ang->VkQty,Me(art->me)),12)+" "+Str(ang->VkPr/ang->pe,12,IF(ang->Pe>=1000,5,IF(ang->Pe>=100,4,IF(ang->Pe>=10,3,2))))
               cLastMatch := art->Matchcode
               RETURN cData
            })
            oBrowse:WhileBlock := {|| ang->Kundma == ku->Kunde .AND. ang->Bestat < 3 }
            //oBrowse:ForBlock := {|| AT("TEXT",ang->matchcode) != 1 }
            oBrowse:AddKey( K_ENTER, {|| 
               Enquiry(ang->angnr)
               IF ang->Bestat >= 3
                  ang->(dbSeek( ku->Kunde ))
                  IF ang->Bestat >= 3
                     RETURN .F.
                  ENDIF
               ENDIF
               RETURN .T.
            })
            oBrowse:lBox := .F.
            oBrowse:lArrow := .F.
            oBrowse:goTop()
            oBrowse:Display()
            oBrowse:deHilite()
            oBrowse:goTop()
            Aadd(aBrowse,{oBrowse,SaveEnv()})

         ELSE
            @ nTop+36,38 SAY "---"
         ENDIF
         ang->(dbClearFilter())
      ENDIF

      IF SystemUser():HasPermission("READ","PROJECTS")
         NetUse("projekte","pj")
         pj->(dbSetOrder( 2 ))
         pj->(dbSeek( ku->Kunde ))
         oBrowse := pj->(TBrowseTr():New(nTop+44,nLeft+2,nTop+50,76))
         oBrowse:lBox := .F.
         oBrowse:OneColumn := .T.
         oBrowse:HeadSep := ""
         oBrowse:NewColumn("Nummer",{|| Str(pj->Nummer) })
         oBrowse:NewColumn("Beschreibung",{|| Pad(pj->Beschreibu,60) })
         oBrowse:WhileBlock := {|| pj->Kundma == ku->Kunde }
         oBrowse:AddKey(K_ENTER,{|| Project_edit(pj->Nummer)  })
         
         oBrowse:ForBlock := {|| pj->Status <= 1 }
         DO WHILE ! Eval(oBrowse:ForBlock) .AND. Eval(oBrowse:WhileBlock) .AND. ! pj->(EOF())
            pj->(dbSkip())
         ENDDO
         oBrowse:Display()
         oBrowse:deHilite()
         Aadd(aBrowse,{oBrowse,SaveEnv()})
      ENDIF

      IF SystemUser():HasPermission("READ","ADR_CUSTOMER_REPORT")
         oButton := HBPushButton():New(nBottom-IF(lFin,3,1),nLeft+1,t("Kunden&bericht ˆffnen"))
         oButton:sBlock := {|| MBaseRun(Trim(Tr_Getini(1))+"\run\bericht") }
         Aadd(aButtons,oButton)
      ENDIF

      IF ku->Nummer $ {14696,25778} .AND. SystemUser():HasPermission("READ","SALESORDER")  //Gessmann
         oButton := HBPushButton():New(0,0,IF(ku->Nummer==14696,"&Mengen 59-Serie","&Rahmenmengen"))
         oButton:sBlock := {|| MBaseRun(Trim(Tr_Getini(1))+"\run\gessmann_dyn") }
         Aadd(aButtons,oButton)
      ENDIF

   ENDIF

   oButton := HBPushButton():New(nBottom-IF(ku->Group=="K".AND.lFin,3,1),nLeft+IF(ku->Group=="K",24,32),"&RÅckruf")
   oButton:sBlock := {||
      LOCAL hContact
      LOCAL cSubject,aEmail
      LOCAL aEmails := {}
      LOCAL aRcvs := {}
      LOCAL cMessage := ""
      LOCAL cPhoneNo,cName := ""
      IF oBrowse != NIL .AND. nActiveBrowse == 1 .AND. Upper(oBrowse:Alias) == "CONTS"
         hContact := GetContact(conts->Number)
      ELSEIF nContactID != 0
         hContact := GetContact(nContactID)
      ENDIF

      cPhoneNo := ku->Telefon
      IF hContact != NIL   .AND. hContact["id"] != 0
         cName := hContact["name"]+" / "
         IF ! Empty(hContact["fullphone"])
            cPhoneNo := hContact["fullphone"]
         ENDIF
      ENDIF
      cName += Trim(Trim(ku->Name1)+" "+ku->Name2)
      cSubject := "RÅckruf: "+cName
      SendMailDlg(aEmails,@cSubject,@cMessage)
      IF Empty(aEmails[1,2]) .OR. (LastKey() == 27 .AND. Tr_MsgBox("Nachricht versenden?",,{"Ja","Nein"}) != 1)
         RETURN Nil
      ENDIF
      FOR EACH aEmail IN aEmails
         Aadd(aRcvs,{aEmail[2],"",aEmail[1]})
      NEXT
      
      cMessage := '<p><a href="'+TraderUrl('MBaseRun(Path('+"'"+'run\ShowAdrInfo'+"'"+'),{'+LTrim(Str(ku->Nummer))+","+Ltrim(Str(IF(hContact==NIL,0,hContact["id"]) ))+'})')+'">'+cName+'</a><br />'+;
                  'Telefonnummer: <a href="tel:'+cPhoneNo+'">'+cPhoneNo+'</a></p>'+cMessage
      SendMail(aRcvs,cSubject,cMessage,,,,.T.)
      //cLink := 'tic://message?to='+Trim(conts->Email)+'&subject='+cSubject
      //ShellExecute(NIL, "Open", cLink, "", "", 1)
      RETURN NIL
   }
   Aadd(aButtons,oButton)

   IF ! Empty(oExtra:Website)
      oButton := HBPushButton():New(nBottom-IF(ku->Group=="K",3,1),nLeft+1,"&Website")
      oButton:sBlock := {|| 
         LOCAL cLink
         cLink := oExtra:Website
         IF ! Empty(cLink)
            ShellExecute(NIL, "Open", cLink, "", "", 1)
         ENDIF
         RETURN NIL
      }
      Aadd(aButtons,oButton)
   ENDIF


   oButton := HBPushButton():New(nBottom-IF(ku->Group=="K".AND.lFin,3,1),nLeft+IF(ku->Group=="K",32,40),"Brie&f")
   oButton:sBlock := {|| _OpenLetterTemplate("") }
   Aadd(aButtons,oButton)
   oButton := HBPushButton():New(nBottom-IF(ku->Group=="K".AND.lFin,3,1),nLeft+IF(ku->Group=="K",44,52),"Audit &Trail")
   oButton:sBlock := {|| ShowAuditOverlayAdr(oAdresse) }
   Aadd(aButtons,oButton)

   nL := nLeft+1
   nT :=  nBottom-IF(ku->Group=="K",3,1)
   AEval(aButtons,{|x|   
      IF x:ClassName != "CHECKBOX"
         x:ColorSpec := "N/W,N/W,GR+/RB,R+/W"
      ENDIF
      IF StrTran(Upper(x:Caption),"&","") != "ZUM PORTAL EINLADEN"
         IF nL+Len(StrTran(x:Caption ,"&",""))+2 >= nLeft+79
            nL := nLeft+1
            nT++
         ENDIF
         x:col := nL
         x:row  := nT
         nL += Len(StrTran(x:Caption ,"&",""))+3
      ENDIF
      IF x:ClassName == "CHECKBOX"
         nL++
      ENDIF
      x:Display() 
      RETURN NIL
   })

   IF ku->Group == "K"
      //Eval(bDispTurnover)
      IF ! lPrePay
         Eval(bShowCreditLimit)
      ENDIF

      IF lBig         
         NetUse("kuinfo","kuinfo")
         IF kuinfo->(dbSeek( Str(ku->Nummer,6) ))
            FOR nX := 1 TO MlCount(kuinfo->Info,nRight-1-83)
               @ nBottom-9+nX-1,83 SAY MemoLine(kuinfo->Info,nRight-1-83,nX)
               IF nBottom-9+nX == nBottom
                  EXIT
               ENDIF
            NEXT
         ENDIF
         
      ENDIF
      IF lBig .AND. (SystemUser():HasRole(1) .OR. SystemUser():HasRole(14)) //Vertrieb oder Projektmanagement
         bGetFreigabe := {||
            LOCAL cText
            IF Empty(art->Zeichnung)
               cText := "keine Zeichnung"
            ELSE
               ppf->(dbSetOrder( 1 ))
               ppf->(dbSetFilter( {|| ppf->Freigabe .AND. ! ppf->Sonderfrei  },"Freigabe .AND. ! Sonderfrei" ))
               IF ppf->(dbSeek( Str(art->Artikelnr,6)+art->Zeichnung+art->ZeichIndex ))
                  cText := "abgeschlossen"
               ELSE
                  cText := "OFFEN        "
               ENDIF
               ppf->(dbClearFilter())
            ENDIF
            RETURN Pad(cText,15)
         }

         bGetLastShip := {|| 
            
            LOCAL cDate := Pad("nie",8)
            cFilter := 'Trim(buart) == "RNR"'
            abg->(dbSetOrder( 1 ))
            abg->(dbSetFilter({|| abg->(&(cFilter)) },cFilter))
            IF abg->(dbSeek( Descend(art->Matchcode) ))
               cDate := DtoC(abg->Transdate)
            ENDIF
            abg->(dbClearFilter())
            RETURN cDate
         }

         NetUse("artikel","art")
         NetUse("artlief","ali")
         NetUse("parts","part")
         NetUse("ppf","ppf")
            
         IF ku->Nummer == 34414
            cKSMatch := "KS27732/L"
         ELSEIF ku->Nummer == 25778 //FP
            cKSMatch := "KS17535"
         ELSE
            cKSMatch := "KS"+LTrim(Str(ku->Nummer))
         ENDIF
         
         art->(dbSetOrder( 1 ))
         art->(dbSeek( cKSMatch ,.T. ))

         oArtBrowse := art->(TBrowseTr():New(nTop+1,83,nTop+17,nRight-1))
         oArtBrowse:OneColumn := .T.
         oArtBrowse:lBox := .F.      
         oArtBrowse:HeadSep := ""

         oArtBrowse:cFor := "! obsolete"
         oArtBrowse:WhileBlock := {|| AT(Trim(cKSMatch),art->Matchcode) == 1 }

         oArtBrowse:NewColumn("Matchcode",{|| art->Matchcode })
         oArtBrowse:NewColumn("Freigabe",bGetFreigabe)
         oArtBrowse:NewColumn("AuftrÑge",{|| Transform(art->VkQty,Me(Art->me)) })
         oArtBrowse:NewColumn("Lieferung",bGetLastShip)
               

         oArtBrowse:AddKey(K_ESC,{||.F.})
         //oArtBrowse:AddKey(K_SPACE,{||DispInfo("TRD_01"),.T.}, "Infos anzeigen")
         /*oArtBrowse:AddKey(K_F11,{||
            IF oArtFilter == NIL
               oArtFilter := InteractiveFilter():New(nTop+18,nLeft+83,10,,"ARTIKEL")
               oArtFilter:AddValue("Matchcode",'Upper(matchcode)',Space(25))
               oArtFilter:AddValue("Artikel" ,"Upper(artikel)",Space(35),"@!S25")
            ENDIF
            oArtFilter:Dialog()
            RETURN .T.
         })*/
         oArtBrowse:AddKey(K_F10 ,{||
            LOCAL hFields := {;
               "Artikelnummer"=>{|| art->Artikelnr },;
               "Matchcode"=>{|| art->Matchcode  },;
               "Beschreibung"=>{|| art->Artikel },;
               "Freigabe"=>bGetFreigabe,;
               "Zeichnung"=>{|| art->Zeichnung },;
               "Zeichnungsindex"=>{|| art->ZeichIndex },;
               "VPE"=>{|| art->VPE },;
               "Gewicht"=>{|| art->Gewicht },;
               "Ursprungsland"=>{|| art->Ursprung },;
               "Zolltarifnummer"=>{|| art->KnCode },;
               "Letzte Lieferung"=>bGetLastShip;
            }

            Hook("before_export_artikel",{hFields})

            oArtBrowse:SaveAsCSV(hFields)
            RETURN .T.
         },"Daten exportieren")

         oArtBrowse:goTop()
         oArtBrowse:Display()
         oArtBrowse:deHilite()

         Aadd(aBrowse,{oArtBrowse,SaveEnv()})
      ENDIF
      
      //noCrm
      IF lBig .AND. nHistPos == 0 .AND. SystemUser():HasRole(1)
         @ nTop+19,83 SAY "Werden geladen...." COLOR cHiliteColor
         nR := 1
         oNoCrm := NoCrmAPi():New()
         IF oNoCrm:Connect()
         
            //Altd()
         oBrowse := auf->(TABrowse():new(nTop+19,83,nTop+25,nRight-1))
         
         oBrowse:HeadSep := ""
         
         oBrowse:NewColumn( NIL ,{|oBrowse|
            LOCAL cName,cRet
            LOCAL aMatches
            IF ValType(oBrowse:CurrentDataRow()) == "H" .AND. Len(oBrowse:CurrentDataRow()) > 0
               cName := oBrowse:CurrentDataRow()["title"]
               cName := hb_utf8tostr(cName)
               aMatches := HB_Regex("#[0-9]+",cName)         
               IF Len(aMatches) > 0
                  cName := StrTran(cName,aMatches[1],"")
               ENDIF
               cRet := Pad(cName,nRight-84-8)+" "+Pad(oBrowse:CurrentDataRow()["status"],7)
            ELSE
               cRet := Pad("Keine",nRight-84)
            ENDIF
            RETURN cRet
         })
         //oBrowse:WhileBlock := {|| auf->Kundma == ku->Kunde .AND. auf->Bestat < 3 }
         oBrowse:AddKey(K_ENTER, {|oBrowse| 
            LOCAL cLink := "https://engelking.nocrm.io/leads/"+Ltrim(Str(oBrowse:CurrentDataRow()["id"]))
            ShellExecute(NIL, "Open", cLink, "", "", 1)
            RETURN 0
         })
         
         oBrowse:aData := oNoCrm:Execute("leads","GET",{"status"=>"todo,standby",/*"limit"=>"2",*/"field_key"=>"Kunde (Matchcode)","field_value"=>HB_StrToUtf8(Trim(ku->Kunde)),"order"=>"next_action"})  //only receives 100 leads
         oBrowse:lBox := .F.
         oBrowse:lArrow := .F.
         oBrowse:bAnyFun := {|oBrowse|            
            LOCAL aComments
            LOCAL nR := 0,nX := 1
            LOCAL nY,cContent
            LOCAL nB := nBottom-11
            IF ValType(oBrowse:CurrentDataRow()) == "H" .AND. nLead != oBrowse:CurrentDataRow()["id"] .AND. aBrowse[nActiveBrowse,1] == oBrowse
               aComments := oNoCrm:Execute("leads/"+Ltrim(Str(oBrowse:CurrentDataRow()["id"]))+"/comments","GET",{"direction"=>"desc"})            
               @ nTop+27,83 CLEAR TO nB,nRight-1
               DO WHILE nX <= Len(aComments) .AND. nR <= nB
                  IF ValType(aComments[nX]["content"]) == "C"
                     cContent := HB_Utf8ToStr( aComments[nX]["content"] )
                  ELSE
                     cContent := ""
                  ENDIF
                  FOR nY := 1 TO MLCount(cContent,nRight-84-9)
                     @ nTop+27+nR++,83 SAY IF(nY==1,DtoC(noCRM_DateConv(aComments[nX]["created_at"])),Space(8))+" "+MemoLine(cContent,nRight-84-9,nY)
                     IF nTop+27+nR >= nB
                        EXIT
                     ENDIF
                  NEXT
                  nX++
                  IF nTop+27+nR >= nB
                     EXIT
                  ENDIF
               ENDDO
               nLead := oBrowse:CurrentDataRow()["id"]
            ENDIF
            RETURN .T.
         }
         oBrowse:goTop()
         oBrowse:Display()
         oBrowse:deHilite()
         
         Aadd(aBrowse,{oBrowse,SaveEnv()})
         
         ELSE
            @ nTop+19,83 SAY "Fehler bei der Verbindung zu noCRM"
         ENDIF

      ENDIF
      //end noCRM

      

      IF SystemUser():HasPermission("READ","SALESQUOTES")
         
         @ nTop+35,51 SAY " Summe wird errechnet... " COLOR cHiliteColor
         
         aAngebot := GetCustomerOpenEnquiries(ku->Kunde)
         @ nTop+35,51 SAY " Gesamt EUR "+(Transform(aAngebot[1],cDecNumformat))+" "
      ENDIF
   ENDIF


   bChangeBrowse := {|nNew|
      oBrowse:deHilite()
      aBrowse[nActiveBrowse,2] := SaveEnv()
      nActiveBrowse := nNew
      oBrowse := aBrowse[nActiveBrowse,1]
      RestEnv(aBrowse[nActiveBrowse,2],.F.)
      oBrowse:Display()
      RETURN NIL
   }

   IF Len(aBrowse) > 0 .AND. nActiveBrowse <= Len(aBrowse)
      oBrowse := aBrowse[nActiveBrowse,1]      
      RestEnv(aBrowse[nActiveBrowse,2],.F.)
      oBrowse:Display()
   ELSE
      oBrowse := NIL
   ENDIF

   hData := NIL
   DO WHILE .T.
      /*IF hData == NIL
         //hb_mutexSubscribe( pClientData, , @hData )
         IF hData != NIL
            @ nTop+35,51 SAY " Gesamt EUR "+(Transform(hData["ang"][2],cDecNumformat))+" "
            Eval(bDispTurnover,hData["turn"])
            Alert("Data received")
         ENDIF
      ENDIF*/
      IF oBrowse == NIL .OR. oBrowse:Stable
         IF ValType(hmtx_busy) == "P"
            hb_mutexUnlock(hmtx_busy)
         ENDIF
         nKey := Inkey(0)
         IF ValType(hmtx_busy) == "P"
            hb_mutexlock(hmtx_busy)
         ENDIF
         IF nKey == K_SPACE // .AND. ku->Group == "L"
            Eval(bDispTurnover)      
         ELSEIF nKey == K_CTRL_DOWN .AND. nHistPos == 1            
            cTimeStamp := ""
            oAdresse:Discard() //this removes all temporary data set with SetCurrentFieldValues
            @ 00,nRight+1 CLEAR TO MaxRow(),MaxCol()
            nHistPos := 0
            EXIT
         ELSEIF nHistPos >= 0 .AND. (nKey == K_CTRL_UP .OR. nKey == K_CTRL_DOWN)
            IF ! Empty(cTimeStamp)
               //dblog->(dbSetFilter({|| dblog->DateTime < cTimeStamp },"DateTime < '"+cTimeStamp+"'"))
            ENDIF
            IF dblog->(dbSeek( Pad("KU",5)+Str(oAdresse:Nummer,12) ))
               nCount := 0
               //go to the most current one
               DO WHILE Trim(dblog->Alias) == "KU" .AND. Val(dblog->ID) == oAdresse:Nummer .AND. ! dblog->(EOF())
                  dblog->(dbSkip())
                  nCount++
               ENDDO                    
               
               IF nCount >= nHistPos 
                  IF nKey == K_CTRL_DOWN
                     nHistPos--
                  ELSE
                     nHistPos++
                  ENDIF
                  //nHistPos++
                  dblog->(dbSkip((nHistPos)*-1))

                  

                  hData := HB_DeSerialize(dblog->Data)

                  nR := 0
                  @ 00,nRight+1 CLEAR TO MaxRow(),MaxCol()
                  @ nR++,nRight+1 SAY nHistPos
                  @ nR++,nRight+1 SAY "User: "+Str(dbLog->User)
                  IF hData != NIL 
                     IF HHasKey(hData,"DATA")
                        FOR nX := 1 TO Len(hData["DATA"])
                           cName := HGetKeyAt(hData["DATA"],nX)                  
                           IF oAdresse:GetField(cName) != HGetValueAt(hData["DATA"],nX)
                              @ nR++,nRight+1 SAY cName
                           ENDIF
                           //hData["DATA"][cName] := ::SetField(cName,HGetValueAt(hData["DATA"],nX))         
                        NEXT
                     ENDIF
                     IF HHasKey(hData,"MLDATA")
                        FOR nX := 1 To Len(hData["MLDATA"])
                           cName := HGetKeyAt(hData["MLDATA"],nX)
                           hField := HGetValueAt(hData["MLDATA"],nX)
                           FOR nY := 1 TO Len(hField)
                              cLang := HGetKeyAt(hField,nY)
                              //::SetMLField(cName,cLang,hGetValueAt(hField,nY))
                              IF oAdresse:GetMLField(cName,cLang) != hGetValueAt(hField,nY)
                                 @ nR++,nRight+1 SAY cName+" "+cLang
                              ENDIF
                           NEXT
                        NEXT
                     ENDIF                 

                     oAdresse:SetCurrentFieldValues(hData)
                  ENDIF

                  cTimeStamp := dblog->DateTime                        
                  dblog->(dbClearFilter())
               ENDIF
               EXIT
            ENDIF
            
         ELSEIF nKey == K_ESC
            lExit := .T.
            EXIT
         ELSEIF (nKey == K_LBUTTONDOWN .AND. (nB := AScan(aButtons,{|oButton|oButton:HitTest(MRow()+1,MCol()) != 0})) != 0) .OR.;
            (! Empty(Chr(nKey)) .AND. (nB := AScan(aButtons,{|oButton| aRegex:= HB_Regex("\&([A-Za-z÷‹ƒˆ¸‰])",oButton:Caption), Len(aRegex) > 0 .AND. Upper(aRegex[2]) == Upper(Chr(nKey))} )) != 0)
            oButton := aButtons[nB]
            oButton:setFocus()
            oButton:select()
            oButton:killFocus()
         ELSEIF oBrowse != NIL
            IF nKey == K_TAB
               IF nActiveBrowse < Len(aBrowse)
                  Eval(bChangeBrowse,nActiveBrowse+1)
               ELSE
                  Eval(bChangeBrowse,1)
               ENDIF
            ELSEIF nKey == K_SH_TAB .AND. nActiveBrowse > 1
               Eval(bChangeBrowse,nActiveBrowse-1)
            ELSEIF nKey == K_LBUTTONDOWN .AND. ((oBrowse:ClassName == "TBROWSETR" .AND. ! oBrowse:HitTest()) .OR. (oBrowse:ClassName == "TABROWSE" .AND. oBrowse:HitTest(mRow()+1,mcol()) == 0))
               FOR nX := 1 TO Len(aBrowse)
                  IF nX != nActiveBrowse .AND. ((aBrowse[nX,1]:ClassName == "TBROWSETR" .AND. aBrowse[nX,1]:HitTest()) .OR. (aBrowse[nX,1]:ClassName == "TABROWSE" .AND. aBrowse[nX,1]:HitTest(mrow()+1,mcol()) != 0))
//                     aBrowse[nX]:HitTest()
                     Eval(bChangeBrowse,nX)
                  ENDIF
               NEXT
               LOOP
            ENDIF
            
            oBrowse:Event({nKey})
            
         ELSE
            //EXIT
         ENDIF
      ELSE
         oBrowse:Display()
      ENDIF
   ENDDO
ENDDO
IF ValType(hmtx_busy) == "P"
   hb_mutexUnlock(hmtx_busy)
ENDIF




/*
      ::Display()
   while ! ::lExit  // = .F.
   //::Display()

      if (::stable)
         Do While nKey == 0 .AND. ! ::lExit
            //@ MaxRow(),00 SAY ::nLastKeyTick ; ?? "",GetIdleTick()
            If ::nLastKeyTick == 0 .OR. GetIdleTick() - ::nLastKeyTick >= 5 //Secs(ElapTime(::cLastKeyTime,DateTime())) >= 1
               ::RefreshDisplay()
               nTime := 0
            Endif
            nKey := Inkey(nTime) //A_INKEY(0.1)
         Enddo
         ::Event({nKey})
         nKey := 0
         nTime := 0.1
      else
         ::Display()
      endif
   enddo*/


/*
DevPos( nBottom-6, 38 )
DevOut( "1: "+TRIM(ku->person)+" "+TRIM(ku->telefon1) )
DevPos( nBottom-5, 38 )
DevOut( "2: "+TRIM(ku->person2)+" "+TRIM(ku->telefon2) )
DevPos( nBottom-4, 38 )
DevOut( "3: "+TRIM(ku->person3)+" "+TRIM(ku->telefon3) )
DevPos( nBottom-3, 38 )
DevOut( "4: "+TRIM(ku->person4)+" "+TRIM(ku->telefon4) )
DevPos( nBottom-2, 38 )
DevOut( "5: "+TRIM(ku->person5)+" "+TRIM(ku->telefon5) )
//DISPEND()
SInkey(0,128)*/

#include 'X:\run\creditsafe.prg'
#include 'x:\run\nocrm.prg'
STATIC FUNCTION ShowAuditOverlayAdr(oAdresse)
   LOCAL cScreen := SaveScreen()
   LOCAL nTop := 02
   LOCAL nLeft := 02
   LOCAL nBottom := MaxRow()-2
   LOCAL nRight := MaxCol()-2
   LOCAL oBrowse
   LOCAL nKey := 0
   LOCAL cAlias := "KU"
   LOCAL cId := Str(oAdresse:Nummer,12)

   @ nTop,nLeft CLEAR TO nBottom,nRight
   @ nTop,nLeft TO nBottom,nRight
   @ nTop,nLeft+2 SAY "Audit Trail"

   oBrowse := BuildAuditBrowseAdr(nTop+1,nLeft+1,nBottom-1,nRight-1,cAlias,cId,oAdresse)
   oBrowse:lBox := .F.
   oBrowse:Display()

   DO WHILE nKey != 27 .AND. Upper(Chr(nKey)) != "A"
      IF oBrowse:Stable
         nKey := Inkey(0)
         oBrowse:Event({nKey})
      ELSE
         oBrowse:Display()
      ENDIF
   ENDDO

   RestScreen(,,,,cScreen)
RETURN NIL

STATIC FUNCTION BuildAuditBrowseAdr(nTop,nLeft,nBottom,nRight,cAlias,cId,oAdresse)
   LOCAL oBrowse
   LOCAL cWhen
   LOCAL cUser
   LOCAL hData
   LOCAL aLogEntries := {},aFields
   LOCAL nX,nY
   LOCAL aRaw := {}
   LOCAL hSnapshot := {"DATA"=>{=>},"MLDATA"=>{=>}}

   NetUse("dblog","dblog")
   dblog->(dbSetOrder(1))
   dblog->(dbSeek(Pad(cAlias,5)+cId,.T.))

   DO WHILE Trim(dblog->Alias) == Trim(cAlias) .AND. dblog->ID == cId
      hData := NIL
      BEGIN SEQUENCE
         hData := HB_DeSerialize(dblog->Data)
      RECOVER
      END SEQUENCE
      Aadd(aRaw,{dblog->DateTime,dblog->User,hData})
      dblog->(dbSkip())
   ENDDO

   FOR nX := Len(aRaw) TO 1 STEP -1
      cWhen := Left(TtoC(StoT(aRaw[nX,1])),17)
      cUser := Left(Buy(aRaw[nX,2],.T.),10)
      aFields := FormatAuditFieldsAdr(aRaw[nX,3],oAdresse,hSnapshot)
      IF Len(aFields) == 0
         Aadd(aFields,"-")
      ENDIF
      FOR nY := 1 TO Len(aFields)
         IF nY == 1
            Aadd(aLogEntries,cWhen+" "+cUser+" "+aFields[nY])
         ELSE
            Aadd(aLogEntries,Space(29)+aFields[nY])
         ENDIF
      NEXT
   NEXT

   oBrowse := dblog->(TABrowse():New(nTop,nLeft,nBottom,nRight))
   oBrowse:lBox := .F.
   oBrowse:OneColumn := .T.
   oBrowse:MultipleRows := .T.
   oBrowse:NoRefreshBug := .T.
   oBrowse:aData := aLogEntries
   oBrowse:ColorSpec := c_five
   oBrowse:WhileBlock := {|| Trim(dblog->Alias) == Trim(cAlias) .AND. dblog->ID == cId }

   oBrowse:NewColumn(Pad("Datum/Zeit       Benutzer   énderung",nRight-nLeft+1),{||
      IF oBrowse:CurrentDataRow() == NIL
         RETURN Pad("Keine Eintraege",nRight-nLeft+1)
      ENDIF

      RETURN Pad(oBrowse:CurrentDataRow(),oBrowse:nRight-oBrowse:nLeft+1)
   })

RETURN oBrowse

STATIC FUNCTION FormatAuditFieldsAdr(hData,oAdresse,hSnapshot)
   LOCAL aFields := {}
   LOCAL cField,nX,nY
   LOCAL cCur,cPrev
   LOCAL hField

   IF ValType(hData) != "H"
      RETURN {}
   ENDIF

   IF HB_HHasKey(hData,"DATA")
      FOR nX := 1 TO Len(hData["DATA"])
         cField := HGetKeyAt(hData["DATA"],nX)
         IF cField $ {"LASTCHANGE","CHANGED"}
            LOOP
         ENDIF
         cPrev := hData["DATA"][cField]
         IF HB_HHasKey(hSnapshot["DATA"],cField)
            cCur := hSnapshot["DATA"][cField]
         ELSE
            cCur := oAdresse:GetField(cField)
         ENDIF
         IF HB_ValToStr(cCur) != HB_ValToStr(cPrev)
            Aadd(aFields,cField+": "+AllTrim(HB_ValToStr(cPrev))+" -> "+AllTrim(HB_ValToStr(cCur)))
         ENDIF
         hSnapshot["DATA"][cField] := cPrev
      NEXT
   ENDIF

   IF HB_HHasKey(hData,"MLDATA") .AND. Len(hData["MLDATA"]) > 0
      FOR nX := 1 TO Len(hData["MLDATA"])
         cField := HGetKeyAt(hData["MLDATA"],nX)
         hField := HGetValueAt(hData["MLDATA"],nX)
         IF ! HB_HHasKey(hSnapshot["MLDATA"],cField)
            hSnapshot["MLDATA"][cField] := {=>}
         ENDIF
         FOR nY := 1 TO Len(hField)
            cPrev := HGetValueAt(hField,nY)
            IF HB_HHasKey(hSnapshot["MLDATA"][cField],HGetKeyAt(hField,nY))
               cCur := hSnapshot["MLDATA"][cField][HGetKeyAt(hField,nY)]
            ELSE
               cCur := oAdresse:GetMLField(cField,HGetKeyAt(hField,nY),.T.)
            ENDIF
            IF HB_ValToStr(cCur) != HB_ValToStr(cPrev)
               Aadd(aFields,cField+"["+HGetKeyAt(hField,nY)+"]: "+AllTrim(HB_ValToStr(cPrev))+" -> "+AllTrim(HB_ValToStr(cCur)))
            ENDIF
            hSnapshot["MLDATA"][cField][HGetKeyAt(hField,nY)] := cPrev
         NEXT
      NEXT
   ENDIF

RETURN aFields

STATIC Function _OpenLetterTemplate(cPerson)
   OpenOOWriterTemplate('Y:\Dokumente und Einstellungen\All Users\Dokumente\Vorlagen\240822_Digitaler_Briefbogen_Engelking_mit_Felder.ott',{;
      'Firma'=>Trim(Trim(ku->Name1)+" "+ku->Name2),;
      'Ansprechpartner'=>cPerson,;
      'Strasse'=>Trim(ku->Street),;
      'Stadt'=>Trim(ku->Plz)+" "+Trim(ku->Town),;
      'Land'=>Trim(GetCountryName(ku->CountryIso));
   })
RETURN .T.
