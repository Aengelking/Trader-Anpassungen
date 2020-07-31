LOCAL nCount :=0
LOCAL nOntime := 0
LOCAL nMaybe := 0
LOCAL cFile := Trim(Tr_Getini(1))+"\export\fp_late.csv"
LOCAL dStart := Date()-365
LOCAL dEnd   := Date()

Head("Just-in-Time Prüfung FP")

@ 01,00 SAY "Ab " GET dStart
@ 02,00 SAY "Bis" GET dEnd
READ

IF LastKey() == 27
   RETURN
ENDIF

NetUse("engauf","auf")
auf->(dbSetOrder( 9 )) //kundma+dtos(besda)

netUse("engkund","ku")
ku->(dbSeek( Pad("FP",8)+"K" ))

NetUse("englsre","re",.F.,0)
re->(dbSetOrder(10))


auf->(dbSeek( Pad("FP",8) )) //+DToS(dStart) ,.T. ))
CLS

nH  := FCreate(cFile)
IF Ferror() != 0
   Alert("File create error: "+LTrim(Str(Ferror())))
   RETURN
ENDIF

FWrite(nH,"AB-Nr.;Pos;Artikel;Versand;Geplant;Differenz;Wunschtermin;Differenz"+Chr(13)+Chr(10))

DO WHILE ! auf->(EOF()) .AND. Trim(auf->Kundma) == "FP" .AND. auf->Besda <= dEnd
   dPlan := GetJITLiefertag(auf->BDatum,ku->JIT_LZ) //if the customer data has been changed, this will cause some issues
   dWish := GetJITLiefertag(auf->WDatum,ku->JIT_LZ)
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
         FWrite(nH,Str(auf->AbNr)+";"+Str(auf->Itmnr)+";"+auf->Matchcode+";"+DToC(dShip)+";"+DToC(dPlan)+";"+Str(dShip-dPlan,3)+";"+DToC(dWish)+";"+Str(dShip-dWish,3)+Chr(13)+Chr(10))
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



