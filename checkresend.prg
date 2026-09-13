
//#define TEST_RUN

PROCEDURE HRBMAIN

//SETTINGS

LOCAL nLast      := 15  //check last X days
LOCAL lError     := .F.
LOCAL cList := ""
LOCAL cErrorList := ""

//END OF SETTINGS

LOCAL nRec,nTotal,cText
LOCAL aFina := {},nSub,nRe,hSub
LOCAL cTilta := "",cTiltaErr := ""

#include "noworking.ch"


NetUse("post","post")
NetUse("englsre","re")
NetUse("engkund","ku")
NetUse("contacts","conts")

Head(t("Rechnungsversand"))


/*  Factoring: gepackte Rechnungen im Status FINA erst bei Tilta einreichen -
 *  anlegen, Belege hochladen, Finanzierung beantragen. Das ersetzt den
 *  Handbetrieb aus RUN_FACTORING: Mail lesen, im Portal hochladen, freigeben.
 *
 *  Eine erfolgreich eingereichte Rechnung hat danach keinen Status FINA mehr
 *  und wird deshalb von der Versandschleife unten mitgenommen - derselbe Lauf
 *  reicht ein und verschickt. Was nicht durchgeht, behaelt FINA und geht damit
 *  nicht raus, genau wie bisher, wenn niemand freigegeben hat; diese Faelle
 *  kommen per Mail.
 *
 *  Bewusst ein eigener Durchgang VOR der Schleife: run\tilta_submit.prg
 *  arbeitet in denselben Arbeitsbereichen, das darf eine laufende Schleife
 *  nicht unter sich haben. Der Ausschnitt ist derselbe wie beim Versand
 *  (nLast Tage), damit alte Haenger nicht jede Nacht neu gemeldet werden - die
 *  stehen in RUN_CHECK_FACTORING.                                          */
NetUse("rechnung","reh")
reh->(dbSetOrder( 1 ))
re->(dbSetOrder( 9 ))
re->(dbSeek( DToS(Date()-nLast), .T. ))
DO WHILE ! re->(Eof()) .AND. re->RechDat <= Date()
   IF re->Reposnr == 0 .AND. re->Packed .AND. re->PosWt != 0
      nRe := re->Rechnr
      IF reh->(dbSeek( Str(nRe,6) )) .AND. reh->State == "FINA"
         Aadd(aFina,nRe)
      ENDIF
   ENDIF
   re->(dbSkip())
ENDDO

IF Len(aFina) > 0
   @ 11,10 SAY "Factoring bei Tilta anmelden"
   FOR nSub := 1 TO Len(aFina)
      @ 11,40 SAY aFina[nSub]
      hSub := NIL
      BEGIN SEQUENCE WITH {|e| Break(e)}
         hSub := MBaseRun(Path("run\tilta_submit.prg"),{aFina[nSub]})
      RECOVER
         hSub := NIL
      END SEQUENCE

      IF ValType(hSub) != "H" .OR. ! HHasKey(hSub,"ok")
         cTiltaErr += Str(aFina[nSub],6)+" Einreichen abgebrochen"+Chr(13)+Chr(10)
         cTilta    += Str(aFina[nSub],6)+" Einreichen abgebrochen"+Chr(13)+Chr(10)
      ELSE
         cTilta += Str(aFina[nSub],6)+" "+__TiltaLogLine(hSub)+Chr(13)+Chr(10)
         IF ! hSub["ok"]
            cTiltaErr += Str(aFina[nSub],6)+" "+__TiltaLogLine(hSub)+Chr(13)+Chr(10)
         ENDIF
      ENDIF
   NEXT
   @ 11,40 CLEAR TO 11,MaxCol()
   ? "Factoring eingereicht:",LTrim(Str(Len(aFina))),"Rechnungen geprueft"
ENDIF

@ 11,10 SAY t("Überprüfung und Versand")

re->(dbSetOrder( 9 )) //dtos(rechdat)+kunde
re->(dbSeek( DTos(Date()-nLast), .T. ))
? Date()-nLast,re->Rechnr,re->Rechdat
DO WHILE ! re->(Eof()) .AND. re->RechDat <= Date() //-1
   IF re->Reposnr == 0 .AND. re->Packed .AND. re->PosWt != 0  .AND. ! re->State == "FINA" //FINA = Factoring beantragen
      @ 11,22 SAY re->Rechnr
      IF ! post->(dbSeek( "RE"+Str(re->Rechnr,6) ))
         nRec := re->(Recno())

         nTotal := GetRechnungSumme()
         IF re->PosWt != nTotal //we have had problems with the totals on invoices, so I have added a check here 24.01.18
            lError := .T.
            cErrorList += Str(re->Rechnr,6)+" "+DToC(re->Rechdat)+" Summe falsch, Ist: "+Ltrim(Str(re->PosWt))+" Soll: "+LTrim(Str(nTotal))+Chr(13)+Chr(10)
         ELSE
         //GotoRechAddress()

            re->(dbGoTo(nRec))
            GotoRechAddress()
   
            TxtBox("Rechnung versenden")
            #ifndef TEST_RUN
            IF ku->Re_Via == "EMAI"
               //send email
               post->(Add_Rec(0))
               post->Typ := "RE"
               post->Via := "EMAI"
               post->Nummer := re->Rechnr
               post->DateTime := TtoS(DateTime()) //DToS(Date())+SubStr(Time(),1,2)+SubStr(Time(),4,2)+SubStr(Time(),8,2)+"0000"
               post->(dbUnLock())
               SetPrinterMethodType(3) //email
            ELSE
               SetPrinterMethodType(4) //letter
            ENDIF

            //IF ku->Re_Via == "EMAI" //temp only send emails

   			engrepr("",0,re->Rechnr,.F.,ku->Re,0)  //original
            SetPrinterMethodType(0)
      		TxtClear()
         
   
            //ENDIF

      		IF post->(dbSeek( "RE"+Str(re->Rechnr,6) )) //sent successfully
               cList += Str(re->Rechnr,6)+" "+DToC(re->Rechdat)+Chr(13)+Chr(10)
               //print copy
               SetPrinterMethodType(1)
         		TxtBox("Rechnungs Kopie")
         		engrepr("",0,re->Rechnr,.F.,0,1)
         		SetPrinterMethodType(0)
         		TxtClear()
         	ELSE
         	  cList += Str(re->Rechnr,6)+" "+DToC(re->Rechdat)+" FEHLGESCHLAGEN"+Chr(13)+Chr(10)
         	ENDIF
      		#endif
            re->(dbSetOrder( 9 ))
            re->(dbGoTo(nRec))



         ENDIF
      ENDIF
   ENDIF
   re->(dbSkip())

ENDDO

@ 11,22 SAY "abgeschlossen"

//#ifdef TEST_RUN
//   Inkey(0,128)
//#endif

IF ! Empty(cTiltaErr)
   SendMail({{"amos.engelking@engelking.de","Amos"}, ;
             {"sigrid.reichmann@engelking.de","Sigrid"}}, ;
            "Factoring: Rechnungen nicht eingereicht", ;
            "Diese Rechnungen konnten nicht bei Tilta eingereicht werden und sind"+Chr(13)+Chr(10)+ ;
            "deshalb auch nicht versendet worden:"+Chr(13)+Chr(10)+Chr(13)+Chr(10)+ ;
            cTiltaErr+Chr(13)+Chr(10)+ ;
            "Gesamtprotokoll des Laufs:"+Chr(13)+Chr(10)+cTilta)
ENDIF

IF lError .OR. ! Empty(cList)
   IF lError
      cText := "Bei folgenden Rechnungen sind Fehler aufgetreten:"+Chr(13)+Chr(10)+cErrorList
   ELSE
      cText := ""
   ENDIF
   cText += "Folgende Rechnungen wurden versendet:"+Chr(13)+Chr(10)+cList
   //SendMail({{"GF","Geschäftsführung"},{"Buchhaltung","Buchhaltung"}},"Fehlender Rechnungsversand",cText,,,2)
   IF lError
      SendMail({{"GF","Geschäftsführung"}},"Rechnungsversand"+IF(lError," FEHLERHAFT",""),cText,,,2)
   ENDIF
ENDIF

/*  Protokoll von run\tilta_submit.prg einzeilig machen: die letzte Zeile sagt,
 *  woran es lag, die vorherigen sagen, wie weit es kam.                    */
STATIC FUNCTION __TiltaLogLine(hSub)
   LOCAL cOut := "", nX
   IF ValType(hSub) != "H" .OR. ! HHasKey(hSub,"log")
      RETURN "keine Rueckmeldung"
   ENDIF
   FOR nX := 1 TO Len(hSub["log"])
      cOut += IF(Empty(cOut),""," / ")+hSub["log"][nX]
   NEXT
RETURN IF(Empty(cOut),"keine Rueckmeldung",cOut)

STATIC FUNCTION GetRechnungSumme()
   Local aEnv := SaveEnv()
   LOCAL nRechnr := re->Rechnr
   LOCAL nTotal := 0
   LOCAL nMwstRate := 0
   LOCAL nMwst

   re->(dbSetOrder( 12 ))
   re->(dbSeek( Str(nRechnr,6)+Str(0,3) ))
   //nTotal := re->OfQty //Porto
   IF re->reart <  2 //netto, dann muss die MwSt Rate gesetzt werden, ansonsten bleibt diese bei 0
      taxit( re->taxcode,@nMwStRate,re->rechdat,.F. )
   ENDIF
   re->(dbSkip( 1 ))
   DO WHILE ! re->(EOF()) .AND. re->RECHNR == nRechnr
      If re->reposnr != 0
         nTotal += ROUND( (re->aoqty*re->preis/re->pe)*(1-re->rabatt/100),2)+re->Zuschlag
      Endif
      re->(dbSkip())
   ENDDO

   re->(dbSeek( Str(nRechnr,6)+Str(0,3) ))
   nTotal *= (1+re->Rabatt/100)
   nTotal += re->OfQty
   
   nMwSt := Int( nTotal*nMwStRate+If(nTotal>=0,0.5,-0.5) )/100.00
   nTotal := nTotal+nMwSt

   RestEnv(aEnv)
RETURN Round(nTotal,2)