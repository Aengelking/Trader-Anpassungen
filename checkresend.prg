
//#define TEST_RUN

PROCEDURE HRBMAIN

//SETTINGS

LOCAL nLast      := 15  //check last X days
LOCAL lError     := .F.
LOCAL cList := ""
LOCAL cErrorList := ""

//END OF SETTINGS

LOCAL nRec,nTotal,cText

#include "noworking.ch"

NetUse("post","post")
NetUse("englsre","re")
NetUse("engkund","ku")
NetUse("contacts","conts")

Head(t("Rechnungsversand"))


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

IF lError .OR. ! Empty(cList)
   IF lError
      cText := "Bei folgenden Rechnungen sind Fehler aufgetreten:"+Chr(13)+Chr(10)+cErrorList
   ELSE
      cText := ""
   ENDIF
   cText += "Folgende Rechnungen wurden versendet:"+Chr(13)+Chr(10)+cList
   //SendMail({{"GF","Geschäftsführung"},{"Buchhaltung","Buchhaltung"}},"Fehlender Rechnungsversand",cText,,,2)
   SendMail({{"GF","Geschäftsführung"}},"Rechnungsversand"+IF(lError," FEHLERHAFT",""),cText,,,2)
ENDIF

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