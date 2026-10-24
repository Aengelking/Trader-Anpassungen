PARAMETERS nInvNr

LOCAL getlist := {}
LOCAL nDist := 6
Head(t("Z‰hlblatt drucken"))

Default(@nInvNr,0)

@ 01,00 SAY "Belegnr." GET nInvNr PICTURE "999999" WHEN nInvNr == 0
READ

IF LastKey() == 27
   RETURN
ENDIF
NetUse("lagerort","lago")
lago->(dbSetOrder( 2 ))
lago->(dbSeek( Str(nInvNr,6) ))
StartPrint(,,"PDF")
oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data
oPdf:NewPage()
Conv("\arialb,14\Inventur Nr. "+Ltrim(Str(nInvNr)),oPrinter)
oPdf:NewLine(1)
Conv("\arialb,10\Von Lagerort:\x,25\"+Trim(lago->Lagerort),oPrinter)
oPdf:NewLine(1)
DO WHILE lago->InvNr == nInvNr .AND. ! lago->(EOF())
   lago->(dbSkip())
ENDDO
lago->(dbSkip(-1))
Conv("Bis Lagerort:\x,25\"+Trim(lago->Lagerort),oPrinter)
oPdf:NewLine(nDist)
Conv("\arial,10\Belegnummer \x,50\\code128,'"+LTrim(Str(nInvNr))+"',20\",oPrinter)
oPdf:NewLine(nDist)
Conv(t("N‰chster Lagerort \x,50\\code128,'####NEX####',20\"),oPrinter)
oPdf:NewLine(nDist)
Conv(t("Mengenkorrektur \x,50\\code128,'####COR####',20\"),oPrinter)
oPdf:NewLine(nDist)
Conv(t("Normaler Z‰hlmodus \x,50\\code128,'####ADD####',20\"),oPrinter)
oPdf:NewLine(nDist)
Conv(t("Etiketten \x,50\\code128,'####ETI####',20\"),oPrinter)
oPdf:NewLine(nDist)
Conv(t("Z‰hlung anzeigen \x,50\\code128,'####SHO####',20\"),oPrinter)
oPdf:NewLine(nDist)
Conv(t("Z‰hlung abschlieﬂen \x,50\\code128,'####END####',20\"),oPrinter)
oPdf:NewLine(nDist)
Conv("\x,30\Name\x,100\Unterschrift\x,170\Weitere Z.",oPrinter)
oPdf:NewLine(2)
Conv(t("Erstz‰hler")+"\x,30\____________________________\x,100\______________________________\x,170\___",oPrinter)
oPdf:NewLine(3)
Conv(t("Zweitz‰hler")+"\x,30\____________________________\x,100\______________________________\x,170\___",oPrinter)
oPdf:NewLine(3)
Conv(t("Drittz‰hler")+"\x,30\____________________________\x,100\______________________________",oPrinter)

//If(oPrinter:Type=="PDF",MBaseRun(Trim(Tr_Getini(1))+Chr(92)+"run"+Chr(92)+"barcode",{oPrinter,"C128",AllTrim(&(aPar[1])),aPar[2]}),"")
CopyPrint()
EndJob()
