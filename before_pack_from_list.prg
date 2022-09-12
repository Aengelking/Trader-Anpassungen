FUNCTION Hook_Before_Pack_From_List( nNr,lRech,lInUse )

LOCAL lAutoPrint := Tr_Getini(28) != 9
LOCAL oRechnung
LOCAL cEtiPath,aOptions,aState,nChoice,lAusland,lEG,lAtlas,cNewState
LOCAL cFile,nStickqty,nX,cEti,nLate,dJitTag,aShipWith
LOCAL lRet := .T.

MEMVAR mcHookName,mirpt,mibesnr

#ifndef __XHARBOUR__
	#xtranslate ShellExecute([<x,...>])        => Wapi_ShellExecute(<x>)
#endif

NetUse("engkund","ku")
netUse("engbes","bes")

mcHookName := "BEFORE_PACK_FROM_LIST"

cEtiPath := "\\EK-SERVER4\Data\Dokumente und Einstellungen\All Users\Dokumente\Aufkleber\"

aOptions := {"Buchen","Drucken"}
aState := {}
If lRech
	re->(dbsetorder(4))
	re->(dbSeek(STR(nNr,6)))

   oRechnung := Rechnung():New()
   oRechnung:Load(nNr)

	If re->State != "COLL"
		If re->Taxcode == 0 .AND. re->State != "ZOLL"
			Aadd(aOptions,"Zollanmeldung")
			Aadd(aState,"ZOLL")
		Endif
		Aadd(aOptions,"Abholung")
		Aadd(aState,"COLL")
	Endif
	IF re->State != "PICK"
      Aadd(aOptions,t("Zurücksetzen"))
      Aadd(aState,IF(re->Termin==0,"","PICK"))
   ENDIF
Else
	lne->(dbSetORder(1))
	lne->(dbSeek( nNr ))
	If lne->State != "COLL"
		Aadd(aOptions,"Abholung")
		Aadd(aState,"COLL")
	Endif
	IF lne->State != "PICK"
      Aadd(aOptions,t("Zurücksetzen"))
      Aadd(aState,IF(lne->PickNum==0,"","PICK"))
   ENDIF
Endif

nChoice := 2

If ! lInUse .OR. (nChoice := Tr_MsgBox("Dieser Vorgang wird bereits bearbeitet",,aOptions)) >= 2
	If lRech
		If nChoice == 2
			lAusland := re->taxcode == 0
			lEG      := re->TaxCode == 3
			lAtlas := lAusland .AND. re->poswt-re->ofqty-re->preis > 1000

         IF oRechnung:State != "FINA"
            oRechnung:State := "PRIN"
            oRechnung:Save()
         ENDIF
/*			re->(Rec_Lock(0))
			re->State := "PRIN"
			re->(dbUnLock())*/

			NetUse("engkund","ku",.F.,0)
         ku->(dbSeek(re->Kunde+"K"))

			If oRechnung:State != "FINA" .AND. (! lAtlas .OR. (lAtlas .AND. ! lInUse))
				UpdateInvoiceDate(nNr,Date())
			Endif
         IF lAutoPrint
   			SetPrinterMethodType(1) //print
   		ENDIF
			@ MaxRow(),00 CLEAR
			If ! lAtlas .OR. (lAtlas .AND. ! lInUse)
			   SET DEVICE TO SCREEN
            TxtBox("Packzettel")
            
            engexpr(nNr)
            
				TxtClear()
			Endif

			If ! lAtlas .OR. (lAtlas .AND. lInUse)
			   SET DEVICE TO SCREEN
            TxtBox("Lieferschein")
            
            englipr(nNr,Max(1,ku->ls))
            
				TxtClear()
			Endif
			re->(dbsetorder(4))
			re->(dbSeek(STR(nNr,6)))

         IF lEG
			   GotoRechAddress(.T.) //goto delivery address
			   IF ku->CountryIso == "DE" //delivered within Germany,but is on taxcode EG
               englipr(nNr,1,,.T.)  //print a "Gelangensbestätigung"
            ENDIF
         ENDIF

			GotoRechAddress()
			//If (del_ad == 0 .AND. Trim(ku->Re_via) == "BOX" .AND. re->poswt < 1500 ) .OR. lAusland
			If lAusland
			   SET DEVICE TO SCREEN
            TxtBox("Rechnung")
            
				If ! lAtlas .OR. (lAtlas .AND. lInUse)
					engrepr("",0,nNr,.F.,If(lAusland,3,ku->re),0) //print original(s), if foreign then print 3 copies for customs
				Else
					engrepr("",0,nNr,.F.,0,1) //print one copy for customs declaration
            Endif
            
				TxtClear()
			Endif
         IF lAutoPrint
   			SetPrinterMethodType(0)
         ENDIF

			NetUse("artikel","art",.F.,0)
			art->(dbSetOrder( 1 ))
			re->(dbSetOrder( 4 ))
			re->(dbSeek( Str(nNr,6) ))

         If Empty(re->Termin) .AND. (! lAtlas .OR. (lAtlas .AND. ! lInUse)) //Not on picklist and no customs preperation
            TxtBox("Etiketten")
            Do While re->Rechnr == nNr               
               art->(dbSeek( re->Matchcode ))               
               If re->RePosnr > 0 .AND. re->AoQty > 0 .AND. art->Lagerart                  
					   IF lAutoPrint
   						SetPrinterMethodType(5) //stickers
   					ENDIF
						StickPrint("WARE",1)
						IF lAutoPrint
   						SetPrinterMethodType(0)
   					ENDIF
					Endif

					re->(dbSkip())
            Enddo
            TxtClear()
			Endif
		Else // nChoice > 2
			cNewState := aState[nChoice-2]
			IF aState[nChoice-2] == "PICK" .AND. Tr_MsgBox("In Zustand",,{"Wird gepickt","Keine Versandfreigabe"}) == 2
				cNewState := ""
			ENDIF
			oRechnung:State := cNewState

			/*re->(Rec_Lock(0))
			re->State := cNewState*/
			IF oRechnung:State == "PICK" // .OR. (Trim(re->State) == "" .AND. re->Code == 2)
//			   re->Code := 1  //not printed
			   oRechnung:Gedruckt := .F.
			ELSEIF Empty(oRechnung:State) // == ""
//			   re->Code := 0
            IF oRechnung:Bezahlt
               oRechnung:Bezahlt := .F.
            ENDIF
			   oRechnung:Gedruckt := .F.
			   oRechnung:Ready   := .F.
			ENDIF
			IF re->State == ""
//				re->Termin := 0
            oRechnung:PNum := 0
			ENDIF
//			re->(dbUnLock())
			oRechnung:Save()

			IF re->State == ""
//				ShipInvoice(re->Rechnr,.F.)
			ENDIF
			mcHookName := ""
			Return .F.
		Endif
	Else
		If nChoice == 2
         IF LockEntity("LNE",nNr)
            IF lAutoPrint
               SetPrinterMethodType(1) //print
            ENDIF
            lne->(dbSetORder(1))
            lne->(dbSeek( nNr ))
            ku->(dbSetOrder( 1 ))
            ku->(dbSeek(lne->Kunde+lne->Gruppe))
            If lne->Werkstatt
               NetUse("werkauf","wer",.F.,0)
               wer->(dbSetOrder( 8 ))
               wer->(dbSeek( Str(nNr,6) ))
               WERKPRIN(.F.)
               mirpt := wer->besnr
               mibesnr := wer->besnr
               IF ! Empty(wer->Liefma)
                  enbedr(wer->besnr,,.F.)

                  bes->(dbSeek( Str(wer->besnr,6)+Str(1,3) ))
                  art->(dbSetOrder( 1 ))
                  art->(dbSeek( bes->Matchcode ))
                  cFile := MBAseRun(Trim(Tr_Getini(1))+"\run\getdrawing")
                  IF ! Empty(cFile)
                     StartPrint(,,"PDF")
                     CopyPrint(,cFile)
                     Alert("Bitte Arbeitsanweisung und Bestellung der Sendung beilegen!")
                  ELSE
                     Alert("Bitte Bestellung der Sendung beilegen!")
      //                 Alert("Keine Arbeitsanweisung gefunden! "+art->Matchcode+bes->Matchcode)
                  ENDIF
               ELSE  //interner Auftrag
                  art->(dbSetOrder( 2 ))
                  art->(dbSeek( Str(wer->Artno,6) ))
                  IF HB_regexMatch(".*\.LP\.BS\.[0-9]+",art->Matchcode) //bestckte Leiterplatte
                     StartPrint(,,"PDF")
                     CopyPrint(,"\\EK-SERVER4\Data\Technik\Prozessdoku\05724_Leiterplattenbestckung.pdf")   
                  ENDIF
               ENDIF
               art->(dbSetOrder( 2 ))
               art->(dbSeek( Str(wer->Artno,6) ))

               nStickQty := Round(wer->Qty+Min(wer->Qty*0.01,1),0)
               nX := 0
               DO WHILE .T.
                  cEti := LTrim(Str(wer->Artno,6))
                  IF nX > 0
                     cEti += "_"+LTrim(Str(nX))
                  ENDIF
                  cEti += ".lbex"
                  IF File(cEtiPath+cEti)
                        IF Tr_MsgBox(HB_AnsiToOem("Etikettendruck ("+LTrim(Str(nStickQty,12,0))+" Stück) starten"),cEti,{"OK","abbrechen"}) == 1
                           MBaseRun(Trim(Tr_getini(1))+"\run\labelstar2",{cEtiPath+cEti,nStickQty})
                        ENDIF
                        nX++
                  ELSE
                     EXIT
                  ENDIF
               ENDDO
               cEti := LTrim(Str(wer->Artno,6))+"_VPE"+".lbex"
               IF File(cEtiPath+cEti)
                     IF Tr_MsgBox(HB_AnsiToOem("Etikettendruck ("+LTrim(Str(Max(1,nStickQty/art->Vpe),12,0))+" Stück) starten"),cEti,{"OK","abbrechen"}) == 1
                        MBaseRun(Trim(Tr_getini(1))+"\run\labelstar2",{cEtiPath+cEti,Max(1,Int(nStickQty/art->Vpe))})
                     ENDIF
               ENDIF
           Else
              PrintLag(nNr,IF(ku->TaxCode==0,4,1))
           Endif
           IF lAutoPrint
            SetPrinterMethodType(0)
           ENDIF
           UnlockEntity("LNE",nNr)
         ELSE
            mcHookName := ""
            SET DEVICE TO SCREEN
            Return .T.
  		   ENDIF
		Else
			lne->(dbSetORder(1))
			lne->(dbSeek( nNr ))

			lne->(Rec_Lock(0))
			lne->State := aState[nChoice-2]
			IF Trim(lne->State) == "" .OR. lne->State == "PICK"
/*				lne->Status := 0
			ELSEIF lne->State == "PICK"*/
				lne->Status := 1
			ENDIF
			lne->(dbUnLock())
			mcHookName := ""
			Return .F.
		Endif
	Endif
Endif

re->(dbsetorder(4))
re->(dbSeek(STR(nNr,6)))

IF lRech

   NetUse("engkund","ku",.F.,0)
   ku->(dbSeek(re->Kunde+"K"))
   IF ku->JustInTime
      //Check to see if the shipment is late
         NetUse("engauf","auf")
         auf->(dbSetOrder( 1 ))
         re->(dbSetOrder( 4 ))
         re->(dbSeek( Str(nNr,6) ))
         nLate := 0
         DO WHILE re->Rechnr == nNr
            IF re->RePosnr > 0 .AND. re->AoQty > 0
               auf->(dbSeek( Str(re->Abnr,6)+Str(re->RePosnr,3) ))
               dJitTag := GetJITLiefertag( auf->BDatum, ku->JIT_LZ )
               IF dJitTag < Date()
                  nLate := Max(Date()-dJitTag,nLate)
               ENDIF
            ENDIF
            re->(dbSkip())
         ENDDO
         IF nLate > 0  //late position found, change shipping method
               IF nLate == 1
                  aOptions := {"UPS","HUGGER"}
                  IF Time() > "11:30"
                     aOptions[2] += " Next Day"
                  ENDIF
                  aShipWith := {2,57}
               ELSE
                  aOptions := {"UPS Express Saver","HUGGER Next Day"}
                  aShipWith := {19,57}
               ENDIF
               nChoice := 0
               DO WHILE nChoice  == 0
                  SET DEVICE TO SCREEN
                  nChoice := Tr_MsgBox({t("Auslieferung erfolgt bereits zu spät."),t("Bitte eine Versandart auswählen")},,aOptions)
               ENDDO
               oRechnung:VersandArt := aShipWith[nChoice]
               oRechnung:Save()

               /*re->(dbSetOrder( 4 ))
               IF re->(dbSeek( Str(nNr,6) ))
                  re->(Rec_LOck())
                  re->VersandArt := aShipWith[nChoice]
                  re->(dbUnLock())
               ENDIF*/
         ENDIF

   ENDIF
ENDIF

//If it is set to collection we do not enter the booking mask, but ask for package size and send this to somebody
IF IF(lRech,oRechnung:Versandart,lne->VersandArt) == 10
   /*Alert("Abholung anmelden")

   IF lRech
      oRechnung:State := "COLL"
      oRechnung:Save()
   ELSE
      lne->(Rec_Lock(0))
      lne->State := "COLL"
      lne->(dbUnLock())
   ENDIF*/
   
   //lRet := .F. //do not enter the booking mask
ENDIF

mcHookName := ""
SET DEVICE TO SCREEN

Return lRet