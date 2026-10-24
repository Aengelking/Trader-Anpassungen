LOCAL cFile := Trim(Tr_Getini(1))+"\export\customer_per_manufacturer.csv"
LOCAL nYear,dStartDate,nCur,cKunde,stat_val
LOCAL hCustomers := {=>},hCustomer
LOCAL aMan := {},aEng := {},aDis := {}

NETUSE( "englsre", "re" , .F., 5 )
NetUse( "artikel", "art", .F., 0 )
NetUse( "engkund", "ku" , .F., 0 )
NetUse("contacts","conts",.F.,0)

Head("Umsatz Hersteller pro Kunde")

aManu := GetManufacturerArray()

SetColor(c_five)
@ 07,05 CLEAR TO 09,56
@ 07,05 TO 09,56
@ 08,06 SAY "Ausgangsrechnungen "

nCur := 1
//dStartDate := AddMonth(Date(),-12)
//dStartDate := SToD(Str(Year(dStartDate),4)+StrZero(Month(dStartDate),2)+"01")
dStartDate := SToD(Str(Year(Date())-1,4)+"0101")  //since 1.1. last year

art->(dbSetOrder(1))

re->(dbSetFilter({|| re->Reposnr != 0 .AND. re->AoQty != 0 .AND. re->poswt != 0},"reposnr != 0 .AND. poswt != 0 .AND. aoqty != 0"))
re->(dbSetOrder( 9 )) //Dtos(rechdat)+kunde
re->(dbSeek( DToS(dStartDate) ,.T. ))

DO while ! re->(eof()) .AND. re->RechDat < Date() //.AND. re->reposnr != 0 //.AND. nCur <= 500
   art->(dbSeek( re->Matchcode ))

   If art->Lagerart
      cKunde := re->Kunde

      IF ! HHasKey(hCustomers,cKunde)
         hCustomers[cKunde] := {"MAN"=>0,"ENG"=>0,"DIS"=>0}
      ENDIF
      nCur ++

      @ 08,26 SAY Str(nCur,12)+" "+DtoC(re->Rechdat)

      stat_val := re->poswt * Currate(re->Money,"V")     // NET VALUE

      IF art->Manufactur == 5 //Engelking China
         hCustomers[cKunde]["ENG"] += stat_val
      ELSEIF art->Manufactur == 6 //Engelking
         hCustomers[cKunde]["MAN"] += stat_val
      ELSE
         hCustomers[cKunde]["DIS"] += stat_val
      ENDIF
   ENDIF


   re->(dbSkip( 1 ))
ENDDO

conts->(dbSetOrder(2))

FOR EACH hCustomer IN hCustomers
   ku->(dbSeek( hCustomer:__eNumKey()+"K" ))
   IF hCustomer["MAN"]+hCustomer["ENG"]+hCustomer["DIS"] > 1000
      ? hCustomer:__eNumKey(),ku->Kunde,hCustomer["MAN"],hCustomer["ENG"],hCustomer["DIS"]
   
      conts->(dbSeek( Str(ku->Nummer,6) ))
   
      DO While ! conts->(Eof()) .AND. conts->Address == ku->Nummer
         IF conts->Active .AND. conts->Anrede != 0 .AND. ! Empty(conts->Email)
            IF ! (conts->Email $ aMan .OR. conts->Email $ aEng .OR. conts->Email $ aDis)
               IF hCustomer["MAN"] > hCustomer["ENG"] .AND. hCustomer["MAN"] > hCustomer["DIS"]
                  Aadd(aMan,conts->Email)
               ELSEIF hCustomer["ENG"] > hCustomer["MAN"] .AND. hCustomer["ENG"] > hCustomer["DIS"]
                  Aadd(aEng,conts->Email)
               ELSE
                  Aadd(aDis,conts->Email)
               ENDIF
            ENDIF
         ENDIF
         conts->(dbSkip())
      ENDDO
   
       IF hCustomer["MAN"] > hCustomer["ENG"] .AND. hCustomer["MAN"] > hCustomer["DIS"]
          ?? " manufactured"
       ELSEIF hCustomer["ENG"] > hCustomer["MAN"] .AND. hCustomer["ENG"] > hCustomer["DIS"]
          ?? " Engelking"
       ELSE
          ?? " Distribution"
      ENDIF
   ENDIF
NEXT
? "Manufactured",Len(aMan)
? "Engelking",Len(aEng)
? "Distribution",Len(aDis)
Sinkey(0)

__SaveAsCSV("X:\export\survey_man.csv",aMan)
__SaveAsCSV("X:\export\survey_eng.csv",aEng)
__SaveAsCSV("X:\export\survey_dis.csv",aDis)

STATIC FUNCTION __SaveAsCSV(cFile,aData)
   LOCAL nH := FCreate(cFile)
   LOCAL nCol,cCol,nRow
   IF nH == NIL .OR. FError() != 0
      RETURN .F.
   ENDIF
   FOR nRow := 1 TO LEN(aData)
      IF nRow > 1
         FWrite(nH,Chr(13)+Chr(10))
      ENDIF
      FWrite(nH,HB_OemToAnsi('"'+Trim(aData[nRow])+'"'))
   NEXT
   FClose(nH)
RETURN .T.