#include 'y:\hb32\include\inkey.ch'
#include 'y:\hb32\include\hbgtinfo.ch'

#define LX_CAT_KREDITOR         256
#define LX_CAT_DEBITOR          128

#define WVT_BLOCK_IMAGE                           1
//if this is active no DB operations or files will be saved
//#define TEST

#define GS_EXE '"C:\Program Files\gs\gs9.22\bin\gswin64c.exe"'
#define ZBAR_EXE '"C:\Program Files (x86)\ZBar\bin\zbarimg.exe"'
//#define GS_EXE '"C:\Program Files (x86)\gs\gs9.14\bin\gswin32c.exe"'

#define P_SIGRID 34
#define P_DANIEL IF(Date()>=Stod("20220701").AND.Date()<=StoD("20220707"),9,57)
#define P_DANIELA IF(Date()>=StoD("20251604"),66,50)
#define P_AMOS 9
#define P_LISA 64

PROCEDURE Run_Invoice_Beleg(cType,cMsgPath)

LOCAL cBeleg := Space(30)
LOCAL cBelegKurz
LOCAL cLiefma := Space(8)
LOCAL nKonto := 0
LOCAL cKonto := Space(100)
LOCAL nLiefnr
LOCAL getlist := {}
LOCAL lFound,lBooked
LOCAL nType,dEingang,nYear := Year(Date())
LOCAL nID
LOCAL oAccount,oArchive,cArchive
LOCAL nAtt,lOneDocOnly,nDocAtt,oAtt
LOCAL cFileName := GetConfigValue("attachfile")
LOCAL cGSExe,cZBar,nStdOut,cData,aData
LOCAL cArchiveTime
LOCAL lError,aBookings,nX,cText,oMsg
LOCAL oGet,hAccounts
LOCAL cTempPath
LOCAL aText
LOCAL bBelegLen,cSearchBeleg
LOCAL nRev
LOCAL cImageFile
LOCAL bDrawImage
LOCAL aPaint := {}
LOCAL nScale := 1
LOCAL aList,hEntry,cYearPre,aChoice
LOCAL nPersTrader := IF(Date()<=StoD("20210813"),P_SIGRID,P_DANIELA)  //Person die für Trader Rechnungen verantwortlichist
LOCAL nPersGenehm := IF(Date()<=StoD("20210813"),P_SIGRID,P_AMOS)   //Person die für Genehmigungen zuständig ist
LOCAL hLiefPerson := {=>}
LOCAL hKontoGenehm := {=>} //bestimmte Kreditoren einer Person zuweisen
LOCAL nImageTop := 0,nImageRight := 0,nImageBottom := 0
LOCAL nImageTopDiff:= 0,nImageRightDiff := 0
LOCAL lAuto := .F.
LOCAL nBetrag := 0
LOCAL bDisplayButtons,nPage := 1
LOCAL nPersOnApprove := P_SIGRID //automatically assign to this person on approval
LOCAL dNext,lApprove,lRepeat
LOCAL oExtra

MEMVAR c_two,c_one

SetKey(1014,{||
   nScale++
   Eval(bDrawImage)
   Eval(bDisplayButtons)
   RETURN NIL
})

SetKey(1015,{||
   IF nScale>1
      nScale--
      @ 10,00 CLEAR
      Eval(bDrawImage)
      Eval(bDisplayButtons)
   ENDIF
   RETURN NIL
})

SetKey(K_LBUTTONDOWN,{||
   IF Mrow() == 09 .AND. ! Empty(cImageFile)
      IF MCol() >= 50 .AND. MCol() <= 54
         nScale += .5     
         Eval(bDrawImage)
      ELSEIF MCol() >= 56 .AND. MCol() <= 60 .AND. nScale > 1
         nScale -= .5
         @ 10,00 CLEAR
         Eval(bDrawImage)
      ELSEIF MCol() >= 62 .AND. MCol() <= 70 //.AND. nImageTopDiff*-1 < MaxRow()-30 
         nImageTopDiff -= 20
         @ 10,00 CLEAR
         Eval(bDrawImage)
      ELSEIF MCol() >= 71 .AND. MCol() <= 82 .AND. nImageTopDiff < 0
         nImageTopDiff += 20
         @ 10,00 CLEAR
         Eval(bDrawImage)
      ELSEIF MCol() >= 83 .AND. mCol() <= 99 .AND.  (nScale > 1 .OR.nImageTopDiff < 0)
         nScale := 1
         nImageTopDiff := 0
         @ 10,00 CLEAR
         Eval(bDrawImage)
      ELSEIF MCol() >= 100 .AND. MCol() <= 106 .AND. nPage > 1
         nPage--         
         nImageTopDiff := 0
         @ 10,00 CLEAR
         Eval(bDrawImage)
      ELSEIF MCol() >= 108 .AND. MCol() <= 114 .AND. File(StrTran(cImageFile,"%d",LTrim(str(npage+1))))
         nPage++         
         nImageTopDiff := 0
         @ 10,00 CLEAR
         Eval(bDrawImage)
      ENDIF
   Eval(bDisplayButtons)   
   ENDIF
RETURN NIL
})
/*
   LOCAL nKey
   LOCAL nMRow,nMCol
   LOCAL cScreen := SaveScreen()
   IF MRow() >= nImageTop .AND. MCol() <= nImageRight  
      nMRow := MRow()
      nMCol := MCol()
      DO WHILE (nKey := Inkey(0)) != K_LBUTTONUP
         DO WHILE nKey != 0
            nImageTopDiff += (MRow()-nMRow)/10
            nKey := Inkey()
         ENDDO
         //nImageRightDiff += MCol()-nMCol         
         Eval(bDrawImage)
         @ 00,00 CLEAR TO nImageTop+nImageTopDiff-1,MaxCol() //clear top of image
         //@ 00,00 CLEAR TO MaxRow(),nImageRightDiff-1 //clear left of image
         @ nImageBottom+1,00 CLEAR TO MaxRow(),MaxCol() //clear bottom of image
         //@ 00,nImageRight+nImageRightDiff+1 CLEAR TO MaxRow(),MaxCol() //clear right of image
      ENDDO
      nImageTopDiff:= 0
      nImageRightDiff := 0
      RestScreen(,,,,cScreen)
      RETURN .T. //stop processing in getlist
   ENDIF
   RETURN .F.
})*/

/************** FRACHT ***************/
hKontoGenehm[70062] := P_SIGRID
hKontoGenehm[70887] := P_SIGRID
hKontoGenehm[70814] := P_SIGRID //Fedex
hKontoGenehm[76393] := P_SIGRID //Fedex Deutschland
hKontoGenehm[70911] := P_SIGRID //FET
hKontoGenehm[70302] := P_SIGRID 
hKontoGenehm[76236] := P_SIGRID //Wackler
hKontoGenehm[76056] := P_SIGRID //Dachser
hKontoGenehm[76254] := P_SIGRID //ITC
hKontoGenehm[76239] := P_SIGRID //Sch„flein
hKontoGenehm[76269] := P_SIGRID //HBH Maghreb
hKontoGenehm[70866] := P_SIGRID //Khne+Nagel
hKontoGenehm[71804] := P_SIGRID //Baar Express
/************************************/

hKontoGenehm[76126] := P_SIGRID
hKontoGenehm[76168] := P_SIGRID  //Reisekosten Sammelkonto
hKontoGenehm[76019] := P_SIGRID  //Fundflow
hKontoGenehm[74245] := P_SIGRID  //Allianz
hKontoGenehm[76218] := P_SIGRID  //LeasePlan
hKontoGenehm[74930] := P_SIGRID  //Payrexx
hKontoGenehm[76157] := P_SIGRID  //Conrad - Webhelp
hKontoGenehm[72031] := P_SIGRID  //DKV
hKontoGenehm[70171] := P_SIGRID  //EON (Strom Johannes)

hKontoGenehm[70423] := P_DANIEL
hKontoGenehm[76167] := P_DANIEL  //Amazon Marketplace
hKontoGenehm[74222] := P_DANIEL  //Zisch Frisch

hKontoGenehm[77511] := P_LISA  //intoCommerce

//hLiefPerson[35279] := P_AMOS //Softcom

aList := {;
   {"EMAIL"=>"@techno\.it$","MATCH"=>"TECHNO"},;
   {"EMAIL"=>"@scolmore\.com$","MATCH"=>"SCOLMORE","AUTO"=>.T.},;
   {"EMAIL"=>"@bulgin\.com$","MATCH"=>"BULGIN"},;
   {"EMAIL"=>"@elektron-technology\.com$","MATCH"=>"BULGIN","AUTO"=>.T.},;
   {"EMAIL"=>"@itw.*\.com$","MATCH"=>"ITW"},;
   {"EMAIL"=>"waldom(?:emea)?\.com$","MATCH"=>"WALDOM","AUTO"=>.T.},;
   {"EMAIL"=>"emons-spedition.de$","KONTO"=>74186},;
   {"EMAIL"=>"schenker-invoice@bt-asp\.de$","KONTO"=>70887},;
   {"EMAIL"=>"@tme-germany\.de$","MATCH"=>"TME"},;   
   {"EMAIL"=>"@eu.edac\.net$","MATCH"=>"EDAC","AUTO"=>.F.},;   
   {"EMAIL"=>"@df\.eu$","KONTO"=>70298,"AUTO"=>.T.},;  
   {"EMAIL"=>"@wh-tech\.pl$","MATCH"=>"WHTECH","AUTO"=>.F.},;     
   {"EMAIL"=>"rechnung@winsim\.de$","KONTO"=>74232,"AUTO"=>.F.},;    
   {"EMAIL"=>"service@invoicefetcher\.com$","BETREFF"=>"-ups-united-parcel-service","KONTO"=>70062,"AUTO"=>.F.},;   
   {"EMAIL"=>"service@invoicefetcher\.com$","BETREFF"=>"-amazon-deutschland-aeu-inv","KONTO"=>70423,"AUTO"=>.F.}; //durch AEU-INV nur Rechnungen von Amazon EU und z.B. nicht Marketplace
}


NetUse("reb","reb")
NetUse("rebprot","rebp")
NetUse("idx","idx")
NetUse("engkund","ku")
NetUse("engrech","rech")
NetUse("fibu","fibu")
NetUse("contacts","conts")
NetUse("rerepeat","rerep")

LX_Start()
hAccounts := LX_GetAccountsInCat(LX_CAT_KREDITOR,.T.)

IF ! Empty(cMsgPath)  //email
   oAccount := DV_GetMailAccount()
   cArchive := SubStr(cMsgPath,1,RAT("\",cMsgPath)-1)
   oArchive := oAccount:GetArchive(cArchive)
   oMsg := oArchive:GetArchiveEntryById(cMsgPath)

   /*IF "airspeed" $ Lower(oMsg:Fields("SRFrom"):Value)
      //Need to add conversion to PDF/A
      //e.g. gs -dPDFA -dBATCH -dNOPAUSE -sProcessColorModel=DeviceRGB -sDEVICE=pdfwrite -sPDFACompatibilityPolicy=1 -sOutputFile=output_filename.pdf input_filename.pdf
      Tr_MsgBox("Archivierung von AIRSPEED Rechnung verursacht Probleme. Bitte an Amos verteilen")
      RETURN
   ELSE*/IF Lower(oMsg:Fields("SRFrom"):Value) == "scanner@engelking.de"
      cType := "SCAN"
   ENDIF
   

   dEingang := FileDate(cFileName) //get the date before we change the file name
   
   //Alert(DtoC(dEingang)+";"+cFileName+SubStr(cFileName,50,1))

   nDocAtt := 0
   lOneDocOnly := .F.
   FOR nAtt := 0 TO oMsg:Attachments:Count-1
      IF HB_RegExMatch("\.((pdf)|(doc)|(xml))$",oMsg:Attachments:Item(nAtt):FileName,.F.)
         IF lOneDocOnly
            lOneDocOnly := .F.
            EXIT
         ELSE
            nDocAtt := nAtt
            lOneDocOnly := .T.
         ENDIF
      ENDIF
   NEXT
   IF lOneDocOnly .AND. (cType == "SCAN" .OR. Tr_MsgBox(t("Email enthält nur ein Dokument, soll lediglich dieses archiviert werden?"),,{"Nein","Ja"}) == 2)
      cTempPath := GetEnv("temp")
      oAtt := oMsg:Attachments:Item(nDocAtt)      
      oAtt:CopyOut(cTempPath,StrTran(oAtt:FileName,"?",""))
      cFileName := cTempPath+"\"+StrTran(oAtt:FileName,"?","")
   ENDIF
   FOR EACH hEntry IN aList      
      IF HB_RegexMatch(hEntry["EMAIL"],Lower(oMsg:Fields("SRFrom"):Value)) .AND. (! HHasKey(hEntry,"BETREFF") .OR. HB_RegexMatch(hEntry["BETREFF"],Lower(oMsg:Fields("Subject"):Value)))
         IF HHasKey(hEntry,"MATCH")
            cLiefma := Pad(hEntry["MATCH"],8)
         ELSEIF HHasKey(hEntry,"KONTO") .AND. HHasKey(hAccounts,hEntry["KONTO"])
            cKonto := Pad(hAccounts[hEntry["KONTO"]],100)
            nKonto := hEntry["KONTO"]
         ENDIF
         lAuto := HHasKey(hEntry,"AUTO") .AND. hEntry["AUTO"]
      ENDIF
   NEXT
ENDIF

IF cType == "SCAN"
   TxtBox("Barcode wird erkannt")
   cTempPath := getEnv("temp")
   //
   IF ! File(&(GS_EXE))
      Tr_MsgBox("Ghostscript nicht gefunden")
      RETURN
   ENDIF
   IF ! File(&(ZBAR_EXE))
      Tr_MsgBox("ZBAR nicht gefunden")
      RETURN
   ENDIF

   cGSExe := GS_EXE+' -sDEVICE=png256 -r300 -q -dBATCH -dNOPAUSE -sOutputFile="'+cTempPath+'\trader_invoice_barcode.png" "'+cFileName+'"' //extract first page from PDF as high res PNG
   HB_OpenProcess(cGSExe,,@nStdOut,,.T.)
   cData:= Space(1000)
   Fread( nStdOUT, @cData, 1000 )
   FClose(nSTdOut)
   IF ! Empty(cData)
      Alert(Trim(cData))
   ENDIF

   cZBar := ZBAR_EXE+' -q --raw "'+cTempPath+'\trader_invoice_barcode.png"'
   //nProc := 
   HB_OpenProcess(cZBar,,@nStdOut,,.T.)
   cData := Space(1000)
   Fread( nStdOUT, @cData, 1000 )
   FClose(nSTdOut)
   TxtClear()

   IF Empty(cData)
      Tr_MsgBox("Kein Barcode gefunden")
      RETURN
   ENDIF
   nID := NIL   
   aData := HB_ATokens(cData,Chr(10)) //one barcode per line
   //Trim(StrTran(StrTran(cData,Chr(13),""),Chr(10),""))
   
   FOR EACH cData IN aData  //look for correct barcode in the found ones      
      cData := StrTran(cData,Chr(13),"")  //remove CR just in case there are any (zbarimg does not return this, but you never know!)

      IF HB_RegExMatch("^ER[1-3][0-9]1[0-9]{6}$",cData)
         nID := Val(SubStr(cData,3))
      ENDIF
   NEXT
   IF nID == NIL
      Tr_MsgBox({"Barcode liefert falsche Nummer",cData})      
      RETURN
   ENDIF
   nYear := 2000+Val(Left(Str(nId,9),2))
   IF reb->(dbSeek(Str(nID,9)))
      Tr_MsgBox("Beleg bereits vorhanden")
      RETURN
   ENDIF
   IF Val(Right(Str(nId,9),6)) != 1 .AND. ! reb->(dbSeek(Str(nID-1,9)))      
      Tr_MsgBox("Vorhergehender Beleg ("+LTrim(Str(nID-1))+") fehlt. Bitte zuerst diesen einscannen.")
      RETURN
   ENDIF
ELSEIF cType == "CONTEXT" .AND. Empty(cMsgPath)
   SetConfigValue("attachfile","") //reset attached file so it does not get deleted if it has come from disk, we have already saved the name to cFileName
ENDIF

IF HB_RegExMatch("\.((pdf)|(doc))$",cFileName,.F.)
   cImageFile := GetEnv("temp")+"\"+SubStr(cFileName,Rat("\",cFileName)+1)+"_%d.jpg"
   cGSExe := GS_EXE+' -sDEVICE=jpeg -r300 -q -dBATCH -dNOPAUSE -sOutputFile="'+cImageFile+'" "'+cFileName+'"' //extract first page from PDF as JPEGs
   HB_ProcessValue(HB_OpenProcess(cGSExe,,@nStdOut,,.T.),.T.) //run GS and wait until it terminates

   IF cType != "SCAN"
      __GetDataFromPDF(cFileName,@cBeleg,@nYear)
   ELSE
      __GetDataFromPDF(cFileName,@cBeleg) //in this case the year comes from the Barcode
   ENDIF
ENDIF

IF lAuto .AND. (Empty(cBeleg) .OR. (Empty(cLiefma) .AND. Empty(cKonto)))
   lAuto := .F.
ENDIF


bDrawImage := {||
   LOCAL nRatio,nWidth
   LOCAL cScreen
   IF ! Empty(cImageFile)
      //A4 = 210x297mm
//      @ 30,60 SAY HB_GTINFO( HB_GTI_FONTWIDTH)
//      @ 31,60 SAy HB_GTINFO( HB_GTI_FONTSIZE)

      /*210/width    x
      ....      ==
      297/size     47  */
      nRatio := (210/HB_GTINFO( HB_GTI_FONTWIDTH))/(297/HB_GTINFO( HB_GTI_FONTSIZE))

      nWidth :=  Int(nRatio*(47-10))  //30

      nImageTop := 10
      nImageBottom := nImageTopDiff+47*nScale
      nImageRight := nWidth*nScale

      IF nImageTopDiff < 0
         cScreen := SaveScreen(00,00,09,MaxCol())
      ENDIF

      Wvt_DrawImage( nImageTop+nImageTopDiff,00+nImageRightDiff,nImageBottom,nImageRight+nImageRightDiff, StrTran(cImageFile,"%d",LTrim(str(nPage))), {00, 00, 00, Mod(nRatio,47-10)*72*nScale } )

      IF nImageTopDiff < 0
         RestScreen(00,00,09,MaxCol(),cScreen)
      ENDIF

   ENDIF
   RETURN NIL
}
//SetKey( 1101, bDrawImage)
Aadd(aPaint,{ "Image" , bDrawImage , { WVT_BLOCK_IMAGE,  10, 00, 47, (210/HB_GTINFO( HB_GTI_FONTWIDTH))/(297/HB_GTINFO( HB_GTI_FONTSIZE))*(47-10) } })
WvtSetPaint(aPaint)

DO WHILE .T.

   Head("Rechnungseingang")

   //Eval(bDrawImage)

   bDisplayButtons := {||
      LOCAL cActive := HB_ColorIndex(SetColor(),4)
      LOCAL cInActive := "N+/W"
      IF ! Empty(cImageFile)
         @ 09,50 SAY "[ + ]" COLOR cActive   
         @ 09,56 SAY "[ - ]" COLOR IF(nScale > 1,cActive,cInActive)      
         @ 09,62 SAY "[ hoch ]" COLOR cActive
         @ 09,71 SAY "[ runter ]" COLOR IF(nImageTopDiff < 0,cActive,cInActive)
         @ 09,82 SAY "[ zurcksetzen ]" COLOR IF(nImageTopDiff<0.OR.nScale>1,cActive,cInActive)
         @ 09,100 SAY "[ << ]" COLOR IF(nPage>1,cActive,cInActive)
         @ 09,108 SAY "[ >> ]" COLOR IF(File(StrTran(cImageFile,"%d",LTrim(str(npage+1)))),cActive,cInActive)
      ENDIF
      RETURN NIL
   }
   Eval(bDisplayButtons)

   cBelegKurz := ""
   IF ! Empty(cLiefma)
      FindAd( cLiefma, "L",01,50 )
   ENDIF

   @ 01,00 SAY Pad("Belegnr.",19) GET cBeleg VALID ! Empty(cBeleg) PICTURE "@!" WHEN ! lAuto
   @ 02,00 SAY Pad("Lieferant",19) GET cLiefma PICTURE "@!" VALID Empty(cLiefma) .OR. FindAd( cLiefma, "L",01,50 ) WHEN Empty(cKonto) .AND. ! lAuto
   IF lAuto
      Eval(ATail(GetList):preBlock)
   ENDIF
   @ 03,00 SAY Pad("Konto",19)
   oGet := GetSuggestions():New(03,20,{|v| IF(v==NIL,cKonto,cKonto:=v) })
   oGet:aValues := HGetValues(hAccounts)
   oGet:Picture := "@S30"
   oGet:Display()
   oGet:preBlock := {|| Empty(cLiefma) .AND. ! lAuto }
   oGet:postBlock := {||
      nKonto := Val(cKonto)
      IF ! HHasKey(hAccounts,nKonto)
         IF LX_HasAccountInCat(nKonto,LX_CAT_DEBITOR) == 1 .AND. Tr_MsgBox("Rechnung einem Debitor zuweisen?",,{"Nein","Ja"}) == 2
            cKonto := LTrim(Str(nKonto))+" "+LX_GetAccountName(nKonto)
         ELSE
            IF LastKey() == K_UP .OR. LastKey() == K_SH_TAB
               cKonto := Space(100)
               oGet:Display()
               RETURN .T.
            ENDIF
            RETURN .F.
         ENDIF
      ELSE
         cKonto := Pad(hAccounts[nKonto],100)
      ENDIF
      oGet:Display()
//      Eval(bDrawImage)
      RETURN .T.
   }
   Aadd(getlist,oGet)
   @ 04,00 SAY Pad("Rechnungssumme",19) GET nBetrag VALID nBetrag != 0 PICTURE "@E 9,999,999.99"
   @ 05,00 SAY Pad("Belegjahr",19) GET nYear VALID nYear >= Year(Date())-1 .AND. nYear <= Year(Date()+31) PICTURE "9999" WHEN cType != "SCAN" .AND. ! lAuto //Belegjahr außer bei Scan's da wird es von der ID entnommen

   IF cType == "SCAN"
      @ 06,00 SAY "Interne Belegnummer "+Str(nID,9)
   ENDIF
   Wvt_Paint()
   READ



   IF LastKey() == 27
      RETURN
   ENDIF

   IF ! Empty(cLiefma) //prfen ob dieser nur ber Lexware gebucht wird
      oExtra := ku->(ExtraData():New(ku->Nummer))
      IF oExtra:NoPo //dieser Lieferant bekommt keine Bestellungen und daher muss dieser direkt in Lexware gebucht werden
         fibu->(dbSetOrder( 1 ))
         IF fibu->(dbSeek( Str(ku->Nummer,6) ))
            nKonto := fibu->Konto
            cLiefma := Space(8)
         ELSE
            Tr_MsgBox("Kein Fibukonto - bitte hinterlegen")
            RETURN
         ENDIF
      ENDIF
   ELSE
      fibu->(dbSetOrder( 2 ))
      ku->(dbSetOrder( 8 ))
      IF fibu->(dbSeek( Str(nKonto,6) )) .AND. ku->(dbSeek( Str(fibu->adresse,6) ))
         oExtra := ku->(ExtraData():New(ku->Nummer))
         IF ! oExtra:NoPo //dieser Lieferant bekommt auch Bestellungen
            cLiefma := ku->Kunde
            nKonto  := 0
         ENDIF
      ENDIF
   ENDIF


   lFound := .F.
   lBooked := .F.
   //aKontos := {}
   
   bBelegLen := {|nMaxLen|
      IF Len(Trim(cBeleg)) > nMaxLen
         cBelegKurz := GetBox(Right(Trim(cBeleg),nMaxLen),"Belegnummer zu lang","@!",,,,{|cBelegKurz| ! Empty(cBelegKurz) })
         IF LastKey() == 27
            RETURN .F.
         ENDIF
      ENDIF
      RETURN .T.
   }

   IF ! Empty(cLiefma)
      cYearPre := Right(Str(nYear,4),2)+"-"
      IF Trim(cLiefma) == "TECHNO" .AND. AT(cYearPre,cBeleg) != 1 //bei Techno das Jahr voranstellen, da ansonsten Belegnummern doppelt vorkommen k”nnen
         cBeleg := Left(cYearPre+cBeleg,30)       
         @ 01,20 SAY cBeleg COLOR HB_ColorIndex(c_one,4)
         WvtSetPaint({})
         //Inkey(0,128)
         Tr_MsgBox("Belegnummer angepasst. Neu: "+cBeleg)
         WvtSetPaint(aPaint)
         Wvt_Paint()
      ENDIF      
      nLiefnr := ku->Nummer
      reb->(dbSetOrder( 6 ))
      IF reb->(dbSeek(Str(nLiefnr,6)+cBeleg))
         //Alert("Found")
         rebp->(dbSetOrder( 2 ))
         DO WHILE reb->Liefnr == nLiefnr .AND. reb->Beleg == cBeleg .AND. rebp->(dbSeek(Str(reb->ID,9)+"STORN"))
            reb->(dbSkip())
         ENDDO
         IF reb->Liefnr == nLiefnr .AND. reb->Beleg == cBeleg
            lFound := .T.
            IF cType != "SCAN"
               nID := reb->ID
            ENDIF
         ENDIF
      ELSE
         //Alert("Not Found")
      ENDIF
      IF ! Eval(bBelegLen,10)
         LOOP
      ENDIF
      IF lFound
         rech->(dbSetOrder( 2 ))
         IF rech->(dbSeek( cLiefma+IF(Empty(cBelegKurz),cBeleg,cBelegKurz) ))
            lBooked := rech->Booked
            aBookings := {}
            fibu->(dbSetOrder( 1 ))
            fibu->(dbSeek( Str(ku->Nummer,6) ))
            cSearchBeleg := Left(IF(Empty(cBelegKurz),cBeleg,cBelegKurz),10)
            DO WHILE ! fibu->(EOF()) .AND. fibu->Adresse == ku->Nummer
               aBookings := AJoin(aBookings,LX_GetBookings("ER",nYear,fibu->Konto, cSearchBeleg ))
               IF fibu->CurKonto != 0
                  aBookings := AJoin(aBookings,LX_GetBookings("ER",nYear,fibu->CurKonto,cSearchBeleg))
               ENDIF
               fibu->(dbSkip())
            ENDDO
         ENDIF
      ENDIF
   ELSE
      IF ! Eval(bBelegLen,10)
         LOOP
      ENDIF
      reb->(dbSetOrder( 7 ))
      IF reb->(dbSeek( Str(nKonto,6)+cBeleg ))
         rebp->(dbSetOrder( 2 ))
         DO WHILE reb->Konto == nKonto .AND. reb->Beleg == cBeleg .AND. rebp->(dbSeek(Str(reb->ID,9)+"STORN"))
            reb->(dbSkip())
         ENDDO
         IF reb->Konto == nKonto .AND. reb->Beleg == cBeleg
            lFound := .T.
            IF cType != "SCAN"
               nID := reb->ID
            ENDIF
         ENDIF
      ENDIF

      IF ! lFound
         aBookings := AJoin(LX_GetBookings(NIL,nYear,nKonto,IF(Empty(cBelegKurz),cBeleg,cBelegKurz)),LX_GetBookings("ER",nYear,nKonto,IF(Empty(cBelegKurz),cBeleg,cBelegKurz)))
         lBooked := Len(aBookings) > 0
      ENDIF
   ENDIF
   /*IF ! lFound
      Alert("Beleg nocht nicht erfasst. "+Str(nID))
      RETURN
   ENDIF*/
   IF lFound
      aChoice := {"OK"}
      IF /*reb->Status < 9 .AND.**/ cType != "SCAN" //noch nicht verbucht und es ist kein scan, dann kann das Dokument ersetzt werden
         Aadd(aChoice,"Beleg ersetzen")
      ENDIF
      IF Tr_MsgBox("Beleg bereits vorhanden",,aChoice) != 2
         LOOP
      ENDIF
//      Eval(bDrawImage)
   ELSEIF lBooked
      WvtSetPaint({})
      aText := {"Beleg noch nicht vorhanden, jedoch ist die Rechnung bereits verbucht"}
      FOR nX := 1 TO Len(aBookings)
         Aadd(aText,Trim(aBookings[nX,"TEXT"])+" | Soll "+LTrim(Str(aBookings[nX,"SOLL"]))+" | Haben "+LTrim(Str(aBookings[nX,"HABEN"])))
      NEXT      
      IF TR_MsgBox(aText,,{"abbrechen","trotzdem erfassen"}) != 2
         WvtSetPaint(aPaint)
         LOOP
      ENDIF
//      Eval(bDrawImage)
      FOR nX := 1 TO Len(aBookings)
         IF HB_RegexMatch("#ER[1-9]{2}[0,1][0-9]{5}[1-9]{1}",aBookings[nX]["TEXT"])
            Tr_MsgBox({"Eine Buchung ist bereits mit Index versehen",Trim(aBookings[nX]["TEXT"])})
//            Eval(bDrawImage)
            RETURN
         ENDIF
      NEXT
      WvtSetPaint(aPaint)
   ENDIF

   IF nYear < 2016 //something must have gone wrong
      Alert("Error saving document")
      RETURN
   ENDIF
   
   IF lBooked .OR. lFound .OR. Tr_MsgBox("Dokument archivieren?",,{"Nein","Ja"}) == 2  //if lBooked or lFound we have already asked above
      IF cType == "CONTEXT" .AND. ! Empty(cMsgPath) //via David

         nType := 0 //digital

         @ 05,00 SAY "Eingangsdatum       "+DtoC(dEingang)
         IF Empty(dEingang) //something must have gone wrong
            Alert("Kein Eingangsdatum")
            RETURN
         ENDIF
         //nYear := Year(dEingang)
      ELSE
         IF cType $ {"CONTEXT","MONITOR"} //Directory
            nType := 0 //digital
            dEingang := FileDate(cFileName)
         ELSE //Scanner
            nType := 1 //scanned paper document
            dEingang := Date()
         ENDIF
         @ 05,00 SAY "Eingangsdatum      " GET dEingang VALID ! Empty(dEingang) .AND. dEingang <= Date()
         READ
      ENDIF

      IF LastKey() == 27
         LOOP
      ENDIF

      lError := .F.
      //nYear := Year(dEingang)
      #ifndef TEST
      LETO_BEGINTRANSACTION()
      #endif
      BEGIN SEQUENCE
         #ifndef TEST

         IF ! lFound //if lFound then we are just adding the new document, so no new ID or record
            IF nType == 0  //generate ID if have a no barcode
               IF ! idx->(dbSeek(Pad("REB",5)+Right(Str(nYear,4),2)+Str(nType,1)))
                  idx->(Add_Rec(0))
                  idx->Alias := "REB"
                  idx->Type := nType
                  idx->Year := nYear
               ELSE
                  idx->(Rec_Lock())
               ENDIF
               idx->ID++
               nID := Val( Right(Str(nYear,4),2)+Str(nType,1)+StrZero(idx->ID,6) )
            ENDIF

            reb->(Add_Rec(0))
            reb->ID := nID
            IF ! Empty(cLiefma)
               reb->Liefnr := nLiefnr
               reb->Name   := Trim(ku->Name1)+" "+Trim(ku->Name2)
            ELSE
               reb->Konto := nKonto
               reb->Name  := SubStr(cKonto,AT(" ",cKonto)+1)
            ENDIF
            reb->Beleg := cBeleg
            IF ! Empty(cBelegKurz)
               reb->Beleg_Kurz := cBelegKurz
            ENDIF
            reb->Status := IF(lBooked,9,0)
            IF ! lBooked
               IF Empty(cLiefma)
                  IF nKonto $ hKontoGenehm
                     reb->Person := hKontoGenehm[nKonto]
                  ELSE
                     reb->Person := nPersGenehm
                  ENDIF
               ELSE
                  IF nLiefnr $ hLiefPerson
                     reb->Person := hLiefPerson[nLiefnr]
                  ELSE
                     reb->Person := nPersTrader
                  ENDIF
               ENDIF
            ENDIF
            nRev := 0
         ELSE  //existing document
            reb->(Rec_Lock(0))
            reb->Rev++

            nRev := reb->Rev

            rebp->(Add_Rec(0))
            rebp->ID := nID
            rebp->Type := "NEW"
            rebp->DateTime := TtoS(DateTime())
            rebp->Person  := Tr_Getini(28)
            rebp->Rev     := nRev
         ENDIF
         
         reb->Betrag := nBetrag

         //reb->(dbUnLock()) //this causes it to crash

         rebp->(Add_Rec(0))
         rebp->ID := nID
         rebp->DateTime := DtoS(dEingang)
         rebp->Type := "RECV"
         rebp->Person := Tr_Getini(28)
         rebp->Rev    := nRev

         cArchiveTime := TtoS(DateTime())
         
         rebp->(Add_Rec(0))
         rebp->ID := nID
         rebp->DateTime := cArchiveTime
         rebp->Type := IF(nType==1,"SCAN","ARCHIV")
         rebp->Person := Tr_Getini(28)
         rebp->Rev    := nRev
         #endif

         IF lBooked //.AND. (Len(aBookings := LX_GetBookings("ER",2017,nKonto,cBeleg)) != 0 .OR. Len(aBookings := LX_GetBookings(NIL,2017,nKonto,cBeleg)) != 0)
            FOR nX := 1 TO Len(aBookings)
               cText := Trim(HB_RegexReplace("#[1-9]{2}[0,1][0-9]{5}[1-9]{1}",aBookings[nX]["TEXT"],"")) //replace any old ID
               cText := cText+" #ER"+LTrim(Str(nId,9))
               //? cText
               #ifndef TEST
               LX_UpdateText(aBookings[nX]["NR"],nYear,aBookings[nX]["STAPEL"],cText)
               #endif
            NEXT
         ENDIF
         
         #ifndef TEST
         
         IF ! LETO_COMMITTRANSACTION() //this also unlocks the records
            LETO_ROLLBACK()
            lError := .T.
         ELSE     
            lApprove := .F. 
            lRepeat  := .F.

            AddFileToArchive("ER",nID,cFileName)
            IF nKonto == 70423 .AND. nBetrag <= 500  //special for Amazon
               lApprove := .T.
            ELSEIF Empty(cLiefma) .AND. rerep->(dbSeek( Str(nKonto,6)+Str(nBetrag*100,14,0) )) 
               //check to see if this invoice is a reoccuring invoice which can be automatically released         
               DO WHILE rerep->Konto == nKonto .AND. rerep->Betrag == nBetrag  //there can be multiple entries
                  IF Empty(rerep->End) .OR. rerep->End > dEingang
                     IF rerep->Intervall=="M" 
                        dNext := AddMonth(rerep->Last,1)-5 //5 Tage Toleranz
                     ELSEIF rerep->Intervall=="H" 
                        dNext := AddMonth(rerep->Last,6)-15 //15 Tage Toleranz               
                     ELSEIF rerep->Intervall=="J"
                        dNext := AddMonth(rerep->Last,12)-30 //30 Tage Toleranz               
                     ELSE
                        dNext := StoD("")
                     ENDIF               
                     IF dNext <= dEingang 
                        lApprove := .T.     
                        lRepeat  := .T.             
                        EXIT           
                     ENDIF            
                  ENDIF
                  rerep->(dbSkip())
               ENDDO
               IF ! lApprove
                  Sendmail({{"amos.engelking@engelking.de","Amos"}},"Keine Wiederholungsrechnung gefunden - Eintr„ge stimmen nicht berein",Str(nid)+Chr(13)+Chr(10)+Str(nKonto)+Chr(13)+Chr(10)+Str(nBetrag,14,2))  
               ENDIF
            ENDIF
            
            IF lApprove //invoice has been auto approved            
               LETO_BEGINTRANSACTION()
               BEGIN SEQUENCE
                  IF lRepeat
                     rerep->(Rec_Lock(0))
                     rerep->Last := dEingang    
                  ENDIF

                  reb->(dbSetOrder( 1 ))
                  reb->(dbSeek(Str(nID,9)))

                  //reb->(dbGoto(nRec))
                  reb->(Rec_Lock())
                  reb->Status := 8
                  reb->Person := nPersOnApprove

                  rebp->(Add_Rec())
                  rebp->ID := nID
                  rebp->DateTime := TtoS(DateTime())
                  rebp->Type     := "APR"
                  rebp->Person   := -1  //we use -1 for automatic
                  rebp->Rev      := nRev
                  LETO_COMMITTRANSACTION()
               RECOVER
                  LETO_ROLLBACK()
               END
               /*Sendmail({{"amos.engelking@engelking.de","Amos"}},"Wiederholungsrechnung gefunden",;
                  "REB-ID: "+lTrim(Str(nid)+Chr(13))+Chr(10)+;
                  "Konto:  "+LTrim(Str(nKonto))+Chr(13)+Chr(10)+;
                  "Betrag: "+LTrim(Str(nBetrag,14,2));                     
               )*/ 
            ENDIF    
            #endif
         ENDIF
      RECOVER
         #ifndef TEST
         LETO_ROLLBACK()
         #endif
         lError := .T.
      END
      IF lError         
         Tr_MsgBox("Fehler bei der Verarbeitung des Dokuments")
      ENDIF
      EXIT
   ENDIF
ENDDO
//WVTSetPaint(aOldPaint)

FUNCTION AJoin(aOne,aTwo)
   LOCAL nLen := Len(aOne)
   ASize(aOne,nLen+Len(aTwo))
   ACopy(aTwo,aOne,,,nLen+1)
RETURN aOne

STATIC FUNCTION __GetDataFromPDF(cFile,cNo,nYear)
   LOCAL cGSExe := GS_EXE+' -sDEVICE=txtwrite -q -dBATCH -dNOPAUSE -sOutputFile=- '
   LOCAL nStdOut
   LOCAL nProc := HB_OpenProcess(cGSExe+' "'+cFile+'"',,@nStdOut,,.T.)
   LOCAL cTxt := "",cData
   LOCAL aRegex,nX
   LOCAL lNoFound := .F.,lYearFound := .F.

   LOCAL aSearch := { ;
      {"REGEX"=>"(Invoice|Credit)[\s\t]*(#|No|Number)[\s:\.\t]*([A-Z0-9\-\/\\]{3,})","NO"=>4},;
      {"REGEX"=>"(Rechnungs?|Gutschrifts?|Beleg)[\s\-\t]*(Nr|Nummer)[\s\t:\.]*([A-Z0-9\-\/\\]{3,}).*vom[0-9\.-\/]{4,}(?:20)?([1-2][0-9])","NO"=>4,"YEAR"=>5},;
      {"REGEX"=>"(Rechnungs?|Gutschrifts?|Beleg)[\s\-\t]*(Nr|Nummer)[\s\t:\.]*([A-Z0-9\-\/\\]{3,})","NO"=>4},;
      {"REGEX"=>"(Rechnung|Beleg)\s*:\s*([A-Z0-9\-\/\\]{3,})","NO"=>3},;
      {"REGEX"=>"(Rechnung|Beleg)[\s:]*([0-9\-\/\\]{3,})","NO"=>3},;
      {"REGEX"=>"Date[\s:]{1,}.*(?:20)?([1-2][0-9])","YEAR"=>2},;
      {"REGEX"=>"Datum[\s:]{1,}.*(?:20)?([1-2][0-9])","YEAR"=>2};
   }

//      {"REGEX"=>"(Invoice|Credit)[\s:\.\t]*([A-Z0-9\-\/\\]{3,})","NO"=>3},;
   IF nProc < 0
      ? "Error executing exe"
      //Sinkey(0)
      RETURN NIL
   ENDIF

   DO WHILE HB_ProcessValue(nProc,.F.) == -1
      cData := Space( 1000 )
      Fread( nStdOUT, @cData, Len(cData) )
      cTxt += Trim(cData)
   ENDDO
   
   FOR nX := 1 TO Len(aSearch)
      aRegex := HB_Regex(aSearch[nX,"REGEX"],cTxt,.F.) //not case sensitive
      IF ! lNoFound .AND. HHasKey(aSearch[nX],"NO") .AND. Len(aRegex) >= aSearch[nX,"NO"]
         cNo := Pad(aRegex[aSearch[nX,"NO"]],30)
         lNoFound := .T.
      ENDIF
      IF ! lYearFound .AND. HHasKey(aSearch[nX],"YEAR") .AND. Len(aRegex) >= aSearch[nX,"YEAR"]
         nYear := 2000+Val(aRegex[aSearch[nX,"YEAR"]])
         IF nYear >= Year(Date())-1 .AND. nYear <= Year(Date())
            lYearFound := .T.
         ELSE
            nYear := Year(Date())
         ENDIF
      ENDIF

   NEXT
RETURN NIL

