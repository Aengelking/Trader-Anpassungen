LOCAL nCount :=0
LOCAL nOntime := 0
LOCAL nMaybe := 0
LOCAL cFile
LOCAL dStart := StoD(Str(Year(Date())-1,4)+"0101")
LOCAL dEnd   := StoD(Str(Year(Date())-1,4)+"1231")
LOCAL cKunde := Space(8)

Head("Termintreue berechnen")

NetUse("engkund","ku")
NetUse("engauf","auf")
NetUse("englsre","re")

@ 01,00 SAY "Kunde" GET cKunde PICTURE "@!" VALID Findad( cKunde, "K", 01, 40 )
@ 02,00 SAY "Ab   " GET dStart
@ 03,00 SAY "Bis  " GET dEnd
READ

IF LastKey() == 27
   RETURN
ENDIF

ku->(dbSeek( cKunde+"K" ))
re->(dbSetOrder(10))

auf->(dbSetOrder( 9 )) //kundma+dtos(besda)
auf->(dbSeek( cKunde, .T. )) //+DToS(dStart) ,.T. ))

cFile := Trim(Tr_Getini(1))+"\export\ontimedelivery\"+Trim(cKunde)+".csv"
nH  := FCreate(cFile)
IF Ferror() != 0
   Alert("File create error: "+LTrim(Str(Ferror())))
   RETURN
ENDIF

SetPos(06,00)
FWrite(nH,"AB-Nr.;Pos;Artikel;Versand;Geplant;Differenz;Wunschtermin;Differenz"+Chr(13)+Chr(10))
? Pad("AB-Nr.",6)+" Pos "+Pad("Artikel",25)+" "+Pad("Versand",8)+" "+Pad("Geplant",8)+" "+Pad("Differenz",3)+" "+Pad("Wunschversand",8)+" "+Pad("Differenz",3)

DO WHILE ! auf->(EOF()) .AND. auf->Kundma == cKunde .AND. auf->Besda <= dEnd
   dPlan := CalWD(auf->DTerm)
   dWish := GetJITLiefertag(auf->WDatum,Hook("get_shiptime",{ku->Nummer}))
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
         ? Str(auf->AbNr)+" "+Str(auf->Itmnr,3)+" "+auf->Matchcode+" "+DToC(dShip)+" "+DToC(dPlan)+" "+Str(dShip-dPlan,3)+" "+DToC(dWish)+" "+Str(dShip-dWish,3)

         IF dShip <= dPlan
            nonTime++
         ENDIF
         nCount++
      ENDIF
   ENDIF
   auf->(dbSkip())
ENDDO

FClose(nH)
IF nCount > 0
   ? Str(nOnTime/nCount*100,6,2)+"%"+" on time"
ENDIF
Wapi_ShellExecute(,"open",cFile)
SInkey(0,128)



