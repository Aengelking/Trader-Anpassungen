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
LOCAL cNumFormat := "@E 9,999,999"
LOCAL cDecNumFormat := cNumFormat+".99"
LOCAL bShowCreditLimit
LOCAL hTurnOver
LOCAL cType,nYear
LOCAL nRec
LOCAL oExtra
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
//LOCAL oUsr := SystemUser()

MEMVAR mlShowInvoiceList,c_five,MSB,trVer,hmtx_busy
PUBLIC mlShowInvoiceList,hmtx_busy

IF Type("hmtx_busy") != "U"
   IF ! hb_mutexLock(hmtx_busy)
      RETURN
   ELSE
      ? "TEST"
      hb_mutexUnLock(hmtx_busy)
      RETURN
   ENDIF
ENDIF

oExtra := ku->(ExtraData():New( ku->Nummer ))
lFin := AScan({9,34},Tr_Getini(28)) != 0

/*IF oUsr:HasPermission("VIEW","ADR")
   RETURN
ENDIF*/
pClientData := hb_mutexCreate()

NetUse("angebot","ang",.F.,0)
NetUse("engauf","auf")
ang->(dbSetOrder( 7 ))
NetUse("notes","nts",.F.,0)
NetUse("contacts","conts",.F.,0)
conts->(dbSetOrder(1))
NetUse("artikel","art")

//hTurnover := If(ku->Group=="K",GetCustomerTurnover(ku->kunde),{"open"=>ku->open,"current"=>ku->Turnover,"last"=>ku->turnoverol,"last3"=>0,"total"=>ku->turnoverto})
//aAngebot := GetCustomerOpenEnquiries(ku->Kunde) 

SetColor(c_five)

IF ku->Group == "K"
   nHeight := IF(lFin,47,45)
ELSE
   nHeight := 26
ENDIF

nLeft := 03
nRight := 81
nTop := MaxRow()/2-nHeight/2
nBottom:= nTop+nHeight

//TxtClear()
@ nTop,nLeft CLEAR TO nBottom,nRight
@ nTop,nLeft TO nBottom,nRight

If ! Empty(ku->KuSchutz)
   lBlink := SetBlink(.T.)
   nRec := ku->(Recno())
   nOrder := ku->(dbSetOrder( 8 ))
   If ku->(dbSeek( Str( ku->KuSchutz ,6) ))
      DispBox(nTop,nLeft,nBottom,nRight,Replicate(Chr(219),4),"GR+")
      @ nBottom,nLeft+1 SAY Pad(" "+t("GESCHÜTZT FÜR:")+" "+Trim(ku->Name1)+" "+ku->Name2,nRight-nLeft-1) COLOR "N/GR*"
   Endif
   ku->(dbSetOrder( nOrder ))
   ku->(dbGoTo( nRec ))
Endif

IF oExtra:Nda
   cColor := SetColor("R/GR*")
   @ nTop,nRight+1 CLEAR TO nBottom,nRight+3
   nRow := IF(nBottom<nTop+36,nTop,nTop+10)
   FOR EACH cLetter IN "GEHEIMHALTUNGSVEREINBARUNG"
      @ nRow,nRight+2 SAY cLetter
      nRow++
   NEXT
   SetColor(cColor)
ENDIF



@ nTop,nLeft+2 SAY "[" + ku->kunde + "]"
@ nTop,nRight-Len(LTrim(Str(ku->Nummer,6)))-3 SAY "[" + LTrim(Str(ku->Nummer,6)) + "]"

IF(ku->group == "K", bold( nTop+1,nLeft+2,msb[4],0 ),IF(ku->group == "L", bold( nTop+1,nLeft+2,msb[5],0 ),bold( nTop+1,7,msb[6]+ku->group+"    ",0 )))
ku->( yesnotes() )
//notiz := .T.


//Top Left
DevPos( nTop+2, nLeft+2 )
DevOut( ku->name1 )
DevPos( nTop+3, nLeft+2 )
DevOut( ku->name2 )
DevPos( nTop+4, nLeft+2 )
DevOut( ku->Street )
DevPos( nTop+5, nLeft+2 )
DevOut( TRIM( ku->plz ) + " " + ku->town )
DevPos( nTop+6, nLeft+2 )
DevOut( GetCountryName(ku->CountryIso) )

bold(nTop+8,nLeft+2,msb[7] + ku->telefon,0)

@ nTop+9, nLeft+2 SAY "EMAIL    " + Pad(ku->Email,27)
@ nTop+10, nLeft+2 SAY msb[9] + ku->telefax

@ nTop+35-19,nLeft+2 SAY Pad(SKONTVA(ku->Skonto,"D",,,.F.),nRight-nLeft-2)

DevPos( nTop+1, 44 )
DevOut( if(ku->group = "L",msb[10] + ku->kundennr,msb[11] + ku->kundennr) )
//DevPos( nTop+2, 44 )
//DevOutPict( msb[12] + ku->bank, "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" )
//DevPos( nTop+3, 44 )
//DevOut( msb[13] + ku->konto )
DevPos( nTop+2, 44 )
DevOut( msb[14] + STR( ku->charge ) )

@ nTop+5,44 SAY "Umsatz abfragen mit >LEER<"

@ nTop+35-17, nLeft+1 TO nTop+35-17,nRight-1 //divider
@ nTop+35-17, nLeft+2 SAY " "+t("Kontaktpersonen")+" " COLOR cTitleColor

IF ku->Group == "K"
   @ nTop+35-9, nLeft+1 TO nTop+35-9,nRight-1 //divider
   @ nTop+35-9, nLeft+2 SAY " "+t("Aufträge")+" " COLOR cTitleColor

   @ nTop+35, nLeft+1 TO nTop+35,nRight-1 //divider
   @ nTop+35, nLeft+2 SAY " "+t("Angebote")+" " COLOR cTitleColor
   @ nTop+43, nLeft+1 TO nTop+43,nRight-1 //divider
ENDIF


@ nTop+3,44 TO nTop+3,76
@ nTop+3,45 SAY " Umsatz " COLOR cTitleColor

@ nTop+8,44 TO nTop+8,76
//@ nTop+5,44 SAY "Daten werden gesammelt...  " COLOR "W+/R*"
bDispTurnover := {|hTurnover|

   @ nTop+4,44 CLEAR TO nTop+7,nRight-1
   @ nTop+5,44 SAY "Daten werden gesammelt...  " COLOR "W+/R*"
   hTurnover := If(ku->Group=="K",GetCustomerTurnover(ku->kunde),GetSupplierTurnover(ku->Kunde))

   aCompGroups := {}
   IF ku->Group == "K"
      Aadd(aCompGroups,{"BACHMANG","BACHMANR","BACHMANN"})
      Aadd(aCompGroups,{"FP","FRANCOTY","FPINOVO"})
   ELSEIF ku->Group == "L"
      Aadd(aCompGroups,{"ITW","ITWMETAL"})
   ENDIF



   @ nTop+5,44 CLEAR TO nTop+5,nRight-1

   DevPos( nTop+4, 44 )
   DevOut( "Aktuell:" +" EUR "+ (Transform( hTurnover["current"],cNumFormat)) )
   DevPos( nTop+5, 44 )
   DevOut( "Vorjahr:" +" EUR "+(Transform( hTurnover["last"],cNumFormat )) )
   @ nTop+6,44 SAY "3-Jahre: EUR "+(Transform(hTurnover["last3"],cNumFormat))
   //LTrim(STR( ku->turnoverol )) )
   @ nTop+7,44 SAY "Gesamt : EUR "+(Transform(hTurnover["total"],cNumFormat))

   nX := AScan(aCompGroups,{|x| Trim(ku->Kunde) $ x })
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


   If ku->Group == "K"
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

@ nTop+35-21,nLeft+2 SAY "Angelegt am: "+DToC(ku->K_Seit)

If ku->Group == "K"
   //IF oUsr:HasPermission("VIEW","ADR_CUSTTURNOVER")
      nOpenOrders := GetCustomerOpenOrders(ku->kunde)
      @ nTop+26,51 SAY " Gesamt EUR "+(Transform(nOpenOrders,cDecNumFormat))+" "
      //@ nTop+35,51 SAY " Gesamt EUR "+(Transform(aAngebot[2],cDecNumformat))+" "
   /*ELSE
      nOpenOrders := 0
   ENDIF*/
   NetUse("skontoa","sk")
   lPrePay := sk->(IsPrePay(ku->skonto))

   bShowCreditLimit := {||
      LOCAL nCreditLimit
      //IF nOpenOrders > 0 .OR. hTurnover["current"]+hTurnover["last"] > 0  //Kreditlimit nur bei aktiven Kunden anzeigen, vermeidet die Abfrage bei Creditsafe
         nCreditLimit := GetCustomerCreditLimit(ku->Kunde)
         IF ! lPrePay
            
            IF nCreditLimit == 0.2
               @ nTop+09,44+13 SAY "0 (Keine Auskunft)"
            ELSEIF nCreditLimit == 0.1
               @ nTop+09,44+13 SAY "0 (Rechtsform fehlt)"
            ELSEIF nCreditLimit == 0.5
               @ nTop+09,44+13 SAY "0 (Rating schlecht)"
            ELSEIF nCreditLimit == -1
               @ nTop+09,44+13 SAY "0 (Nicht aktiv)"
            ELSEIF nCreditLimit == -3
               @ nTop+09,44+13 SAY "0 (Kein Limit festgelegt)"
            ELSEIF nCreditLimit == -4
               @ nTop+09,44+13 SAY "0 (Kein Rating gefunden)"
            ELSEIF nCreditLimit == -5
               @ nTop+09,44+13 SAY "0 (Land nicht gedeckt)"               
            ELSEIF nCreditLimit == -6
               @ nTop+09,44+13 SAY "0 (Zu sp„t bezahlt)"   
            ELSE
               @ nTop+09,44+13 SAY Transform(nCreditLimit,cNumFormat)
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

   IF lFin
      oButton := HBPushButton():New(nBottom-1,nLeft+1,"Rechnungs&historie anzeigen")
      oButton:sBlock := {||
         mlShowInvoiceList := .T.
         Eval(bShowCreditLimit)
         mlShowInvoiceList := .F.
         RETURN NIL
      }
      Aadd(aButtons,oButton)

      oButton := HBPushButton():New(nBottom-1,nLeft+30,"&Creditsafe Nr. bearbeiten")
      oButton:sBlock := {||
         LOCAL cCSNr := Space(18),oSoap

         NetUse("creditsafe","cs")
         IF cs->(dbSeek( Str(ku->Nummer,6) )) .AND. ! Empty(cs->ID)
            cCSNr := cs->Id
         ENDIF

         cCSNr := GetBox(cCSNr,"Creditsafe Nr.",,,,,{|x|! Empty(x)})
         IF LastKey() == 27 .OR. (cs->(dbSeek( Str(ku->Nummer,6) )) .AND. cs->ID == cCsNr)  //ESC pressed or no change
            RETURN NIL
         ENDIF
         TxtBox("Auskunft wird geladen")
         oSOAP := CreditSafe()
         oReport := CS_GetCompanyReport(oSoap,cCSNr,3)
         IF oReport == NIL
            Tr_MsgBox("Fehler beim laden...")
         ELSE
            IF cs->(dbSeek( Str(ku->Nummer,6) ))
               cs->(Rec_Lock())
            ELSE
               cs->(Add_Rec())
               cs->Kunde := ku->Nummer
            ENDIF
            cs->Id := cCSNR
            cs->(dbUnlock())
            CS_SaveReport(ku->Nummer,oReport)
         ENDIF
         TxtClear()
         Eval(bShowCreditLimit)
         RETURN NIL
      }
      Aadd(aButtons,oButton)
   ENDIF
   nAgedTime := 0
   nDays := GetCustomerPayTime(ku->Kunde,@nAgedTime)
   @ nTop+35-18, nLeft+2 SAY "Durchschnittliche gewichtete Zahldauer: "+LTrim(Str(nDays,3,0))+" Tag"+If(nDays!=1,"e","")
   If ValType(nAgedTime) == "N"
      ?? " (Vorhersage: "+LTrim(Str(nAgedTime,3,0))+")"
   Endif
   If trVer >= "5.07"
      hAct := GetCustomerActivityIndex(ku->Kunde)
      @ nTop+35-22,nLeft+2 SAY "Aktivit„t : "+LTrim(Str(hAct["avg"]*100,5,2))+" "+LTrim(Str(hAct["weighted"]*100,10,2))
   Endif
   If ku->rep !=0
      @ nTop+35-20,nLeft+2 SAY t("Außendienst")+": "+RepGetName(ku->Rep)
   Endif
//   @ nTop+35-21,nLeft+2 SAY "Angelegt am: "+DToC(ku->K_Seit)

   bDisplayCreditWorth := {||
      oReport := CS_GetCompanyReportFromArchive(ku->Nummer)
      IF oReport != NIL .AND. oReport:oRoot != NIL
         oIter := TXmlIteratorScan():New(oReport:oRoot)
         oNode := oIter:Find("DECurrentRating")
         @ nTop+11, 44 SAY "Rating    : "+IF(oNode!=NIL,oNode:cData,"-")
         @ nTop+12,44  SAY "Status    : "
         oIter:Rewind()
         oNode := oIter:Find("CompanyStatus")
         IF oNode != NIL
            cStatus := oNode:GetAttribute("Code")
            hStatus := {"Active"=>"aktiv","NonActive"=>"nicht aktiv","Pending"=>"schwebend"}
            IF HHasKey(hStatus,cStatus) .AND. oNode:cData $ "active aktiv"
               @ nTop+12,56 SAY hStatus[cStatus]
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
            Eval(bShowCreditLimit)
            Eval(bDisplayCreditWorth)
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

conts->(dbSeek( Str(ku->Nummer,6),.T. ))
IF conts->address == ku->Nummer .AND. conts->Active
   oButton := HBPushButton():New(nBottom-1,nLeft+58,"&Emails anzeigen")
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
   Aadd(aButtons,oButton)

   oBrowse := conts->(TBrowseTr():New(nTop+35-16,nLeft+2,nTop+35-10,nLeft+30))   
   oBrowse:ColorSpec := "W+/R,GR+/BR,GR+/R,N/GR*"
   oBrowse:NewColumn( Nil, {|| Pad(conts->Name,36)  }, {|| IF(ValType(nContactID)=="N" .AND. conts->Number==nContactID,{3,4},{1,2}) } )
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
      ENDIF
      IF ! Empty(conts->Telephone) .OR. ! Empty(conts->Mobile)
         Aadd(aChoice,"Anruf")
      ENDIF
      IF Len(aChoice) != 0
         Aadd(aChoice,"abbrechen")      
         nChoice := Tr_MsgBox("Bitte ausw„hlen",,aChoice)
      ELSE
         Tr_MsgBox("Keine Kontaktdaten")
         RETURN .T.
      ENDIF            
      IF ! Empty(conts->Email) .AND. nChoice == 1
         cLink := If(!Empty(conts->Email),"tic:/"+"/message?to="+Trim(conts->Email),"")
         IF ! Empty(cLink)
            ShellExecute(NIL, "Open", cLink, "", "", 1)
         ENDIF
      ELSEIF (! Empty(conts->Telephone) .OR. ! Empty(conts->Mobile)) .AND. (nChoice == 1 .OR. nChoice == 2)
         nChoice := 1
         IF ! Empty(conts->Telephone) .AND. ! Empty(conts->Mobile)
            nChoice := Tr_MsgBox("Bitte Nummer w„hlen",,{"Telefon","Handy"})
            IF nChoice == 0
               RETURN .T.
            ENDIF            
         ELSEIF ! Empty(conts->Mobile)
            nChoice := 2
         ENDIF
         IF nChoice == 2
            cNumber := Trim(hC["mobile"])
         ELSE
            cNumber := Trim(hC["fullphone"])
         ENDIF                 
         WAPI_ShellExecute(,"open",'"C:\Program Files (x86)\innovaphone\myPBX\myPBXDial.exe"','"'+cNumber+'"')
      ENDIF
      RETURN .T. 
   })
   oBrowse:bRestFun := {|| .F. }


   nP := nLeft+32
   nW := nRight-nP-9

   oBrowse:bAnyFun := {||
      hC := GetContact(conts->Number)
      @ nTop+35-16,nP SAY "Telefon "+Pad(hC["fullphone"],nW)
      @ nTop+35-15,nP SAY "Handy   "+Pad(conts->Mobile,nW)
      @ nTop+35-14,nP SAY "Fax     "+Pad(hC["fullfax"],nW)
      @ nTop+35-13,nP SAY "Email   "+Pad(conts->Email,nW)
      @ nTop+35-12,nP SAY "Abt.    "+Pad(conts->Department,nW)

      RETURN .T.
   }
   IF ValType(nContactID) == "N"
      IF ! conts->(dbSeek(Str(ku->Nummer,6)+"0"+Str(nContactID,4)))
         conts->(dbSeek( Str(ku->Nummer,6),.T. ))
      ENDIF   
   ENDIF
   oBrowse:Display()

   Aadd(aBrowse,oBrowse)
ELSE
   @ nTop+35-16,38 SAY "---"
ENDIF

IF ku->Group == "K"
   auf->(dbSetOrder(2))
   IF auf->(dbSeek( ku->Kunde )) .AND. auf->Bestat < 3
      oBrowse := auf->(TBrowseTr():new(nTop+35-8,nLeft+2,nTop+34,nRight-1))
      oBrowse:NewColumn( Pad("AB-Nr",6)+" "+"Pos "+Pad("Auftragsnr.",20)+" "+Pad("Artikel",25)+" Termin   "+PadL("Offen",8),{||
         IF auf->Kundma == ku->Kunde
            art->(dbSetOrder( 2 ))
            art->(dbSeek( Str(auf->Artikelnr,6) ))
            RETURN Str(auf->Abnr,6)+" "+Str(auf->Itmnr,3)+" "+auf->Aufnr+" "+auf->Matchcode+" "+IF(Right(Str(auf->DTerm,4),2)=="99",NiceWeek(auf->WTerm),If(ku->JustInTime,DToC(auf->BDatum),NiceWeek(auf->DTerm)))+" "+PadL(Transform(auf->VkQty-auf->GelQty,Me(art->Me)),8)
         ENDIF
         RETURN Pad("Keine Aufträge vorhanden",oBrowse:nRight-oBrowse:nLeft+1)         
      })
      oBrowse:WhileBlock := {|| auf->Kundma == ku->Kunde .AND. auf->Bestat < 3 }
      oBrowse:AddKey(K_ENTER, {|| Engauft(auf->Abnr) })
      oBrowse:lBox := .F.
      oBrowse:lArrow := .F.
      oBrowse:goTop()
      oBrowse:Display()
      oBrowse:deHilite()
      Aadd(aBrowse,oBrowse)
   ELSE
      @ nTop+35-8,38 SAY "---"
   ENDIF
   ang->(dbSetOrder( 7 ))
   cAngFilter := 'bestat < 3 .AND. AT("TEXT",matchcode) != 1'
   ang->(dbSetFilter({|| ang->(&(cAngFilter)) },cAngFilter))
   IF ang->(dbSeek( ku->Kunde )) //.AND. ang->Bestat < 3
      ang->(dbClearFilter())
      oBrowse := ang->(TBrowseTr():new(nTop+36,nLeft+2,nTop+42,nRight-5))
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
            cData := DToC(ang->Besda)+" "+Str(ang->Angnr,6)+" "+Str(ang->Itmnr,3)+" "+ang->Matchcode
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
      Aadd(aBrowse,oBrowse)

   ELSE
      @ nTop+36,38 SAY "---"
   ENDIF
   ang->(dbClearFilter())
   
   oButton := HBPushButton():New(nBottom-IF(lFin,3,1),nLeft+1,t("Kunden&bericht öffnen"))
   oButton:sBlock := {|| MBaseRun(Trim(Tr_Getini(1))+"\run\bericht") }
   Aadd(aButtons,oButton)

   oButton := HBPushButton():New(nBottom-IF(lFin,3,1),nLeft+24,"&Rckruf")
   oButton:sBlock := {||
      LOCAL hContact
      LOCAL cSubject,aEmail
      LOCAL aEmails := {}
      LOCAL aRcvs := {}
      LOCAL cMessage := ""
      IF oBrowse != NIL .AND. nActiveBrowse == 1 .AND. Upper(oBrowse:Alias) == "CONTS"
         hContact := GetContact(conts->Number)
      ELSEIF nContactID != 0
         hContact := GetContact(nContactID)
      ENDIF
      cSubject := "Rckruf: "
      IF hContact != NIL   .AND. hContact["id"] != 0
         cSubject += hContact["name"]+" / "
      ENDIF
      cSubject += Trim(Trim(ku->Name1)+" "+ku->Name2)
      SendMailDlg(aEmails,@cSubject,@cMessage)
      IF Empty(aEmails[1,2]) .OR. (LastKey() == 27 .AND. Tr_MsgBox("Nachricht versenden?",,{"Ja","Nein"}) != 1)
         RETURN Nil
      ENDIF
      FOR EACH aEmail IN aEmails
         Aadd(aRcvs,{aEmail[2],"",aEmail[1]})
      NEXT
      SendMail(aRcvs,cSubject,cMessage)
      RETURN NIL
   }
   Aadd(aButtons,oButton)

ENDIF

AEval(aButtons,{|x| x:ColorSpec := "N/W,N/W,GR+/RB,R+/W", x:Display() })

IF Len(aBrowse) > 0 .AND. nActiveBrowse <= Len(aBrowse)
   oBrowse := aBrowse[nActiveBrowse]
   oBrowse:Display()
ELSE
   oBrowse := NIL
ENDIF

bChangeBrowse := {|nNew|
   oBrowse:deHilite()
   nActiveBrowse := nNew
   oBrowse := aBrowse[nActiveBrowse]
   oBrowse:Display()
   RETURN NIL
}

IF ku->Group == "K"
   //Eval(bDispTurnover)
   IF ! lPrePay
      Eval(bShowCreditLimit)
   ENDIF
ENDIF

//pThread := HB_ThreadStart(
   EVAL({|cMatch,cGroup|
   LOCAL aAngebot,hTurnover
   IF cGroup == "K"
      aAngebot := GetCustomerOpenEnquiries(cMatch)
      @ nTop+35,51 SAY " Gesamt EUR "+(Transform(aAngebot[1],cDecNumformat))+" "
   ENDIF
   //hTurnover := If(cGroup=="K",GetCustomerTurnover(cMatch),GetSupplierTurnover(cMatch))   
   //Eval(bDispTurnover,hTurnover)
   //hb_mutexNotify(pClientData,{"ang"=>aAngebot,"turn"=>hTurnOver})
   RETURN NIL
},ku->Kunde,ku->Group)

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
      IF Type("hmtx_busy") != "U"
         hb_mutexUnlock(hmtx_busy)
      ENDIF
      nKey := Inkey(0)
       IF Type("hmtx_busy") != "U"
         hb_mutexlock(hmtx_busy)
      ENDIF
      IF nKey == K_SPACE // .AND. ku->Group == "L"
         Eval(bDispTurnover)
      ELSEIF nKey == K_ESC
         EXIT
      ELSEIF (nKey == K_LBUTTONDOWN .AND. (nB := AScan(aButtons,{|oButton|oButton:HitTest(MRow(),MCol()) != 0})) != 0) .OR.;
         (! Empty(Chr(nKey)) .AND. (nB := AScan(aButtons,{|oButton| aRegex:= HB_Regex("\&([A-Za-zÖÜÄöüä])",oButton:Caption), Len(aRegex) > 0 .AND. Upper(aRegex[2]) == Upper(Chr(nKey))} )) != 0)
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
         ELSEIF nKey == K_LBUTTONDOWN .AND. ! oBrowse:HitTest()
            FOR nX := 1 TO Len(aBrowse)
               IF nX != nActiveBrowse .AND. aBrowse[nX]:HitTest()
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
