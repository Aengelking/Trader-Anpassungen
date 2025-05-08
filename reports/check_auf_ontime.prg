PROC RUN_REPORT_CHECK_AUF_ONTIME
   LOCAL nCount :=0
   LOCAL nOntime := 0
   LOCAL nMaybe := 0
   LOCAL cFile 
   LOCAL dStart := StoD(Str(Year(Date())-1,4)+"0101")
   LOCAL dEnd   := StoD(Str(Year(Date())-1,4)+"1231")
   LOCAL cKunde := Space(8)
   LOCAL getlist := {}
   LOCAL dPlan,dWish,nH
   LOCAL nShipTime,dShip

   Head("Analyse Termintreue")

   NetUse("engkund","ku")

   @ 01,00 SAY "Kunde" GET cKunde PICTURE "@!" VALID ku->(FindAd(cKunde,"K",01,15))
   @ 02,00 SAY "Ab   " GET dStart
   @ 03,00 SAY "Bis  " GET dEnd
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   NetUse("engauf","auf")
   NetUse("englsre","re")

   auf->(dbSetOrder( 9 )) //kundma+dtos(besda)
   re->(dbSetOrder(10))

   ku->(dbSeek( cKunde+"K" ))
   auf->(dbSeek( cKunde )) //+DToS(dStart) ,.T. ))
   CLS

   cFile := Path("export\")+"analyse_termintreue_"+Trim(cKunde)+".csv"

   nH  := FCreate(cFile)
   IF Ferror() != 0
      Alert("File create error: "+LTrim(Str(Ferror())))
      RETURN
   ENDIF

   FWrite(nH,HB_OemToAnsi("AB-Nr.;Pos;Artikel;Best„tigt;Versand;Geplant;Differenz;Wunschtermin;Differenz")+Chr(13)+Chr(10))

DO WHILE ! auf->(EOF()) .AND. auf->Kundma == cKunde .AND. auf->Besda <= dEnd
   IF ku->JustInTime
      dPlan := GetJITLiefertag(auf->BDatum,ku->JIT_LZ) //if the customer data has been changed, this will cause some issues
      dWish := GetJITLiefertag(auf->WDatum,ku->JIT_LZ)
   ELSE
      nShipTime := Hook("get_shiptime",{ku->Nummer,.F.},1)
      dPlan := CalWD(auf->Dterm)+4-nShipTime  //latest leaving on Friday of that week
      dWish := GetJITLiefertag(auf->WDatum,nShipTime)
   ENDIF
   dShip := Stod("")
   IF dPlan >= dStart .AND. dPlan <= dEnd
      re->(dbSeek( Str(auf->Abnr,6)+Str(auf->itmnr,3) ))
      Do While re->abnr == auf->abnr .AND. re->reposnr == auf->itmnr
         IF re->aoqty > 0
            dShip := Max(re->rechdat,dShip)
         ENDIF
      	re->(dbSkip())
      Enddo
      IF ! Empty(dShip)
         FWrite(nH,Str(auf->AbNr)+";"+Str(auf->Itmnr)+";"+Trim(auf->Matchcode)+";"+DToC(IF(ku->JustInTime,auf->BDatum,CalWD(auf->Dterm)+4))+";"+DToC(dShip)+";"+DToC(dPlan)+";"+Str(dShip-dPlan,3)+";"+DToC(dWish)+";"+Str(dShip-dWish,3)+Chr(13)+Chr(10))
         IF dShip > dPlan
   //         FWrite(nH,Str(auf->AbNr)+";"+Str(auf->Itmnr)+";"+auf->Matchcode+";"+DToC(dShip)+";"+DToC(dPlan)+";"+Str(dShip-dPlan,3)+Chr(13)+Chr(10))
            IF dShip <= dPlan+2
               nMaybe++
            ENDIF
         ELSE
            nonTime++
         ENDIF
         nCount++
      ENDIF
   ENDIF
   auf->(dbSkip())
ENDDO

FClose(nH)

? Str(nOnTime/nCount*100,6,2)+"%"+" on time"
? Str((nOnTime+nMaybe)/nCount*100,6,2)+"%"+" maybe on time (max. 2 days late)"
Wapi_ShellExecute(,"open",cFile)
SInkey(0,128)



