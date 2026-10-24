
LOCAL hProducts  := {=>}
MEMVAR c_one_list
 nManu      := 1

NETUSE( "englsre", "re" , .F., 5 )
NetUse( "artikel", "art", .F., 0 )
//NetUse( "engkund", "ku" , .F., 0 )
NetUse( "manufact","man", .F., 0 )
NetUse("parts","part",.F.,0)

aManu := GetManufacturerArray()

nYear := Year(Date())-1

HEAD("Umsatz mit Produkten eines Herstellers in den letzten 12 Monaten")

@ 02,02 SAY "Hersteller"
@ 02,12,20,40 GET nManu LISTBOX aManu[2] //COLOR c_one_list
@ 21,02 SAY "Jahr"
@ 21,12 GET nYear PICTURE "9999" VALID nYear >= 2000 .AND. nYear <= Year(Date())
READ

IF LastKey() == 27
    RETURN
ENDIF

@ 21,02 SAY "Ausgangsrechnungen "

nMonths := 3

nCur := 1
dStartDate := StoD(Str(nYear,4)+"0101")
//dStartDate := SToD(Str(Year(dStartDate),4)+StrZero(Month(dStartDate),2)+"01")

nLastPos := NIL

//ku->(dbSetOrder( 8 )) //str(nummer)
re->(dbSetOrder(9))

Select("re")
SEt FILTER TO re->Reposnr != 0 .AND. re->AoQty != 0 //use filter with LETO

//re->(dbSeek( Str(1,3) )) //reposnr == 1
re->(dbSeek( DToS(dStartDate),.T. ))

DO while ! re->(eof()) .AND. Year(re->rechdat) == nYear // >= dStartDate//re->reposnr != 0 //.AND. nCur <= 500
    IF re->reposnr != 0 .AND. re->AoQty != 0
        nCur ++
        @ 21,21 SAY Str(nCur,12)

        art->(dbSetOrder(1))
        art->(dbSeek( re->Matchcode ))



        bAddProd := {|nQty,nWeight|
            IF art->manufactur == aManu[1,nManu]
              IF ! HHasKey(hProducts,art->Matchcode)
                	hProducts[art->Matchcode] := {0,0,{=>}}
              ENDIF

              stat_val := re->poswt * Currate(re->Money,"V") * nWeight    // NET VALUE

      		  hProducts[art->Matchcode][1] += stat_val
              hProducts[art->Matchcode][2] += nQty
              IF ! HHasKey(hProducts[art->Matchcode][3],re->Kunde)
                  hProducts[art->Matchcode][3][re->Kunde] := 0
              ENDIF
              hProducts[art->Matchcode][3][re->Kunde] += nQty
            ENDIF
        }



        IF art->Bezug >= 5  //Fertigungsartikel
            nArtnr := art->Artikelnr
            part->(dbSetOrder( 1 ))
            part->(dbSeek(STR(art->artikelnr,6)))
            aArt := {}
            nSumm := 0
            art->(dbSetOrder( 2 ))
            DO WHILE ! part->(EOF()) .AND. part->listart == nArtnr
                art->(dbSeek( Str(part->partart,6) ))
                IF part->Qty != 0
                    Aadd(aArt,{part->partart,(part->qty*re->AoQty*(100+part->addpercent)/100)+IF(re->AoQty<0,-1,1)*part->addqty,art->avpreis})
                    nSumm += art->avpreis*ABS(ATail(aArt)[2])
                ENDIF
                part->(dbSkip())
            ENDDO
            IF nLastPos != NIL
            SetPos(nLastPos,0)
            ENDIF
            nSumm := Max(nSumm,1)
            FOR nX := 1 TO Len(aArt)
                art->(dbSeek( Str(aArt[nX][1],6) ))
                IF nArtNr == 7097
                    ? re->rechnr,art->Matchcode,aArt[nX][3]*ABS(aArt[nX][2])/nSumm
                ENDIF
                Eval(bAddProd,aArt[nX][2],aArt[nX][3]*ABS(aArt[nX][2])/nSumm)
            NEXT
            nLastPos := Row()
        ELSE

            Eval(bAddProd,re->AoQty,1)
        ENDIF


    ENDIF
    re->(dbSkip( 1 ))
ENDDO
          ? "Bel. Taste"
          Inkey(0)
//Indirekten Umsätze (Fertigungsaufträge)

re->(dbClearFilter())

cFile := Trim(Tr_Getini(1))+"\export\products_"+Trim(aManu[2,nManu])+"_"+Str(nYear,4)+".csv"

SET PRINTER TO (cFile)
SET CONSOLE OFF
SET PRINTER ON

nX := 1
?? "Matchcode;Value;Quantity;Kunden"
aProd := NIL
nCust := NIL
FOR EACH aProd IN hProducts
    ? aProd:__eNumKey(),";",_CSVNtoS(aProd[1]),";",_CSVNtoS(aProd[2]),";"
    FOR EACH nCust IN aProd[3]
        ?? nCust:__eNumKey()+" ("+LTrim(Str(nCust,12,0))+") "
    NEXT
NEXT

SET PRINTER TO
SET PRINTER OFF
SET CONSOLE ON

Wapi_ShellExecute(,"open",cFile)

Static Function _CSVNtoS(nNum)

RETURN StrTran(Ltrim(Str(nNum,12,2)),".",",")
