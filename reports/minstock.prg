#translate M(<x>) => '"'+Transform(<x>,Me(art->Me))+'"'
LOCAL aProducts  := {}
MEMVAR c_one_list
 nManu      := 1

//NETUSE( "englsre", "re" , .F., 5 )
NetUse( "artikel", "art", .F., 0 )
//NetUse( "engkund", "ku" , .F., 0 )
NetUse( "manufact","man", .F., 0 )
//NetUse("parts","part",.F.,0)

aManu := GetManufacturerArray()


HEAD(t("Mindestbestände für einen Hersteller exportieren"))

@ 02,02 SAY "Hersteller"
@ 02,12,20,40 GET nManu LISTBOX aManu[2] //COLOR c_one_list
READ

IF LastKey() == 27
    RETURN
ENDIF

art->(dbGoTop())
DO WHILE ! art->(EOF())
   @ 21,21 SAY art->Matchcode

   IF art->manufactur == aManu[1,nManu] .AND. art->Mindest != 0
        Aadd(aProducts,art->matchcode)
   ENDIF
   art->(dbSkip( 1 ))
ENDDO

/*
        art->Mindest
        hReqInc["avgrequirement"]
        hReqInc["forecast"]
        hReqInc["cust_count"]
        hReqInc["order_count"]
        hReqInc["maxorder"]
*/

SET PRINTER TO (Trim(Tr_Getini(1))+"\export\minstock_"+Trim(aManu[2,nManu])+".csv")
//SET CONSOLE OFF
SET PRINTER ON

nX := 1
?? "Matchcode,Mindestbestand,Dursch.Bedarf,Vorhersage,Anzahl Kunden,Anzahl Positionen,Größte Position"
cMatch := NIL
art->(dbSetOrder( 1 ))
FOR EACH cMatch IN aProducts
    art->(dbSeek( cMatch ))
    hReqInc := GetProductRequirementAndIncoming(art->Artikelnr)
    ? '"'+Trim(art->Matchcode)+'"',",",M(art->Mindest),",",M(hReqInc["avgrequirement"]),",",M(hReqInc["forecast"]),",",_CSVNtoS(hReqInc["cust_count"]),",",_CSVNtoS(hReqInc["order_count"]),",",M(hReqInc["maxorder"])
NEXT

SET PRINTER TO
SET PRINTER OFF
SET CONSOLE ON

Static Function _CSVNtoS(nNum)

RETURN '"'+StrTran(Ltrim(Str(nNum,12,0)),".",",")+'"'
