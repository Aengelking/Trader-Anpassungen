
PROC RUN_MT_RECHPROBLEM
   LOCAL aKunden := {}
   LOCAL cSkontoKu := ""
   LOCAL cOhneKu   := ""
   LOCAL cSkonto,lSkonto,hContact
   LOCAL cEmailOhne,cEmailSkonto,cFooter

   NetUse("englsre","re")
   re->(dbSetOrder(8))
   re->(dbSeek( Str(0,3)+Str(67766,6) ))
   NetUse("engkund","ku")
   ku->(dbSetOrder(1))
   NetUse("skontoa","ska")

   cEmailSkonto := __LoadFile("header")
   cEmailSkonto += "Sehr geehrte Damen und Herren,<br><br>wegen eines technischen Problems kam es in den vergangenen Wochen leider zu einer Verzîgerung beim Versand unserer Rechnungen. HierfÅr mîchten wir uns aufrichtig entschuldigen.<br><br>"
   cEmailOhne   := cEmailSkonto
   cEmailSkonto += "Gleichzeitig mîchten wir Ihnen versichern, dass Sie bei einer Begleichung Ihrer Rechnung innerhalb von 10 Tagen selbstverstÑndlich von einem Skontoabzug profitieren kînnen. Dabei orientieren wir uns am Versanddatum der Rechnung, nicht am Rechnungsdatum.<br><br>"
   
   cFooter := "Wir danken Ihnen fÅr Ihr VerstÑndnis und stehen fÅr etwaige Fragen gerne zur VerfÅgung.<br><br>"   
   cFooter += "Mit freundlichen GrÅ·en<br>"
   cFooter += "Ihr Engelking-Team"
   cFooter += __LoadFile("footer")

   cEmailOhne += cFooter
   cEmailSkonto += cFooter

DO WHILE re->Rechdat <= SToD("20231211") .AND. re->Reposnr == 0 .AND. ! re->(Eof()) .AND. Inkey() != 27
   IF ! re->Kunde $ aKunden
      ku->(dbSeek( re->Kunde+"K" ))   
      
      ska->(dbGoto( re->Skonto+1 ))
      cSkonto := Skont(,,ska->Ziel1,ska->Ziel2,ska->Ziel3,ska->Rate1,ska->Rate2,ska->Rate3,"D",.F.)

      ? re->Rechnr,ku->Kunde,ku->Re_Via,cSkonto
      IF ! "Vorkasse" $ cSkonto
         lSkonto := AT("%",cSkonto) != 0         
         IF ku->Re_Via == "EMAI"
            hContact := GetInvoiceContact()
            IF lSkonto
               cSkontoKu += hContact["email"]+";"
               
            ELSE
               cOhneKu += hContact["email"]+";"
            ENDIF
            IF Tr_MsgBox("Email an "+hContact["email"]+" senden?",,{"Ja","Nein"}) == 1
               SendMail({{hContact["email"],hContact["name"]}},"Wichtige Mitteilung zu verspÑteten Rechnungen",IF(lSkonto,cEmailSkonto,cEmailOhne),,,,.T.,"info@engelking.de")
            ENDIF
         ELSE
            //Tr_MsgBox("Brief "+IF(lSkonto,"mit Skonto ","")+"an "+Trim(re->Kunde)+" senden")
            MosText("inverr"+IF(!lSkonto,"2","")+".brf",,{"CHOOSEFILE"=>.F.,"CHANGEADDRESS"=>.F.})
         ENDIF
      ENDIF
      Aadd(aKunden,re->Kunde)
   ENDIF
   re->(dbSkip())
ENDDO

gtSetClipboard(cSkontoKu)
Tr_MsgBox("Adressen mit Skonto in die Zwischenablage kopiert")
gtSetClipboard(cOhneKu)
Tr_MsgBox("Adressen ohne Skonto in die Zwischenablage kopiert")


STATIC FUNCTION __LoadFile(cFileBase,lHtml)
   LOCAL cFile,cLine,nRet,nF
   LOCAL cText := ""
   cFile := Path("\config\email\")+cFileBase+".html" //+"_"+cLang   
   IF File(cFile)
      lHtml := .T.
      nF := FOpen(cFile,0)
      Do While .T.
         nRet := HB_FReadLine(nF,@cLine)
         cLine := HB_AnsiToOem(cLine)
         cText += If(!Empty(cText),Chr(13)+Chr(10),"")+cLine            
         If nRet != 0
            EXIT
         Endif
      Enddo
      FClose(nF)
   ENDIF
RETURN cText

