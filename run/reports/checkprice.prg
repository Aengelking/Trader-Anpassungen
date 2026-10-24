LOCAL oArtikel,aPrices
LOCAL nX,nPrice,cCompet
LOCAL nCount,nQty
LOCAL aCompet := {"RS","Farnell","Ettinger","Conrad","TME","Mouser","Reichelt","Schukat","Arrow",HB_AnsiToOem("BÜRKLIN")}
LOCAL aCompPrices,hPrices,aBrakes,cMeTr
LOCAL aRow,aData := {},nEX := Currate("P","E")
LOCAL cFile
LOCAL bFilter,cFilter
LOCAl nHandle

Head(t("Verkaufspreise Bulgin überprüfen"))

cFile := Trim(Tr_Getini(1))+"\export\bulgin_price_chart.csv"

DO WHILE LastKey() != 27 .AND. (nHandle := FOpen(cFile,1)) == -1 .AND. TR_MsgBox("Could not open file",,{"Retry","Cancel"}) != 2
ENDDO

NetUse("artikel","art")
NetUse("artlief","ali")
NetUse("me","me")

bFilter := {|| art->manufactur == 1 .AND. ! art->Obsolete .AND. art->Table == 44}
cFilter := "manufactur == 1 .AND. ! Obsolete .AND. Table == 44"

art->(dbSetFilter(bFilter,cFilter))  //bulgin, nich abgekündigt, geprüfter Preis
//art->(dbGoTop())
art->(dbSeek("A",.T.)) //start with parts starting with a letter

nCount := 0

aRow := {"Artikel","Buy Low","Buy High"}
AEval(aCompet,{|cCompet| Aadd(aRow,cCompet),Aadd(aRow,"Qty") })
Aadd(aData,aRow)

DO WHILE ! art->(EOF()) // .AND. nCount < 10
   ? art->matchcode

   oArtikel := Artikel():New(.F.)
   oArtikel:Load(art->Artikelnr)
   aCompPrices := GetCompPrices(aCompet)
   hPrices := aCompPrices[2]
   aBrakes := aCompPrices[1]

   IF Len(hPrices) > 0
      aRow := {Trim(art->Matchcode)}

      FOR EACH nQty IN {999999,-1}
         aBuy := GetBuyPrice(Pad("BULGIN",8),art->Artikelnr,nQty,,,,Date())
         IF aBuy["price"] != 0
            Aadd(aRow,Round((aBuy["price"]/aBuy["unit"])*nEx,2))
         ELSE
            Aadd(aRow,"")
         ENDIF
      NEXT

//      aPrices := oArtikel:GetSellPrices(Date()) //this would update the competition database, so we will not do this!
//      Aadd(aRow,IF(Len(aPrices)>=1,Atail(aPrices)[2]/art->VkPE,0))
//      Aadd(aRow,IF(Len(aPrices)>=1,aPrices[1,2]/art->VkPE,0))

      cMeTr := me->(Me(art->me))

      FOR EACH cCompet IN aCompet
         IF HHasKey(hPrices,cCompet) .AND. Len(hPrices[cCompet]) >= 1
            Aadd(aRow,Round( HGetValueAt(hPrices[cCompet],Len(hPrices[cCompet])),2) )
            Aadd(aRow,Round( HGetKeyAt(hPrices[cCompet],Len(hPrices[cCompet])),2) )

//            Aadd(aRow,Round( HGetValueAt(hPrices[cCompet],1),2) )
//            Aadd(aRow,Round( HGetKeyAt(hPrices[cCompet],1),2) )
         ELSE
            Aadd(aRow,"")
            Aadd(aRow,"")
         ENDIF
      NEXT
      Aadd(aData,aRow)
   ENDIF
   art->(dbSetFilter(bFilter,cFilter))
   art->(dbSkip())
   nCount++
ENDDO

FClose(nHandle)

SaveAsCSV(cFile,aData)
WAPI_ShellExecute(,"open",cFile)


STATIC Function GetCompPrices(aCompet)
   LOCAL aBrakes,nY,nP,nMaxLen,nX,hPrices,hPriceList

   MEMVAR c_five

   aBrakes := {}
   hPriceList := {=>}

   FOR nX := 1 TO Len(aCompet)
      ali->(dbSeek(Pad(Upper(aCompet[nX]),8)+Str(art->Artikelnr,6)))
      IF aCompet[nX] $ "TME Schukat" .OR. (ali->(Found()) .AND. ! Empty(ali->artlief))
         ?? "",aCompet[nX]
         hPrices := GetPricesCompet(aCompet[nX]) //MBaseRun(Trim(Tr_Getini(1))+"\run\prices\"+HB_OemToAnsi(aCompet[nX]),{art->Artikelnr,ali->Artlief,art->Matchcode})
         IF ValType(hPrices) != "H" .OR. Len(hPrices) == 0
            hPrices := {=>}
         ELSE
            FOR nY := 1 TO Len(hPrices)
               IF AScan(aBrakes,HGetKeyAt(hPrices,nY)) == 0
                  Aadd(aBrakes,HGetKeyAt(hPrices,nY))
               ENDIF
            NEXT
            hPriceList[aCompet[nX]] := hPrices
         ENDIF
      ENDIF
   NEXT
   ASort(aBrakes)

RETURN {aBrakes,hPriceList}

#include 'x:\run\prices\getprices.prg'