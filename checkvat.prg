PROCEDURE RUN_CheckVat
   LOCAL cFilter,oAddress,oVatAddress,nResult
   LOCAL cData
   LOCAL aList := {}
//? CheckVatId("GB537464035")
//? CheckVatId("FR46318654553")
NetUse("engkund","ku")

cFilter := "group != 'L' .AND. taxcode==3 .AND. !Empty(vatnr) .AND. Left(vatnr,2) != 'DE' .AND. turnover+turnoverol != 0"
ku->(dbSetFilter({|| ku->(&(cFilter)) },cFilter))
ku->(dbGoTop())

//ku->(dbSeek( "BAIERTEC"))
Aadd(aList,{"Kunde","USt-Id","Fehlercode","Fehlermeldung"})
CLS
DO WHILE ! ku->(EOF())
   //? ku->Kunde
   oAddress := Adresse():New()
   oAddress:Load(ku->Nummer)
   
   //IF Left(oAddress:VatNr,2) != "DE"
      IF Val(oAddress:Group) >= 1 .AND. Val(oAddress:Group) <= 9 //Lieferadresse
         oVatAddress := Adresse():New()
         oVatAddress:LoadMatchcode(oAddress:Kunde,"K")
      ELSE
         oVatAddress := oAddress
      ENDIF
      //AltD()
      nResult := CheckVatID(oAddress:Vatnr,Trim(oVatAddress:cName),Trim(oVatAddress:Town),@cData)  //Trim(oVatAddress:Town)
      //nResult := CheckVatID(oAddress:Vatnr,Trim(oVatAddress:cName),Trim(oVatAddress:Town),@cData)
      IF nResult != 0 .AND. nResult != 205 //Fehler aber nicht Abfrage nicht m”glich               
         Aadd(aList,{oAddress:Kunde,oAddress:Vatnr,nResult,HB_AnsiToOem(getVATIDErrorName(nResult))})
         ? oAddress:Kunde,oAddress:Group,Str(nResult,3)+" "+HB_AnsiToOem(getVATIDErrorName(nResult))
         //? cData
      ELSE
         //?? " OK"
      ENDIF
   //ENDIF
   ku->(dbSkip())
ENDDO

SaveAsCSVInterface(aList)

Sinkey(0)