
PROC RUN_Bulgin_Prices
   LOCAL aReq
   LOCAL cLiefma := Pad("BULGIN",8)
   LOCAL dDate := StoD("20241102")
   LOCAL aList := {}
   NetUse("artikel","art")
   art->(dbSetFilter({|| art->Manufactur == 1 },"manufactur==1"))
   art->(dbGotOP())

   Aadd(aList,{"Artikel","Bedarf","EK alt","EK neu","EK alt gesamt","EK neu gesamt","Differenz"})

   DO WHILE ! art->(EOF()) .AND. Inkey() != 27      
      aReq := GetProductRequireMentAndIncoming(art->Artikelnr)
      IF aReq["avgrequirement"] > 0
         ? art->Matchcode,aReq["avgrequirement"]
         aOldPrice := GetBuyPrice( cLiefma, art->Artikelnr, -1, , , , Date() )
         aNewPrice := GetBuyPrice( cLiefma, art->Artikelnr, -1, , , , dDate )
         ?? " Old Price",aOldPrice["price"]/aOldPrice["unit"],"New Price",aNewPrice["price"]/aNewPrice["unit"]
         ?? " Old Price",aOldPrice["price"]/aOldPrice["unit"]*aReq["avgrequirement"],"New Price",aNewPrice["price"]/aNewPrice["unit"]*aReq["avgrequirement"]
         Aadd(aList,{art->Matchcode,aReq["avgrequirement"],aOldPrice["price"]/aOldPrice["unit"],aNewPrice["price"]/aNewPrice["unit"],"=C"+LTrim(Str(Len(aList)+1))+"*B"+LTrim(Str(Len(aList)+1)),"=D"+LTrim(Str(Len(aList)+1))+"*B"+LTrim(Str(Len(aList)+1)),"=F"+LTrim(Str(Len(aList)+1))+"-E"+LTrim(Str(Len(aList)+1))})
      ENDIF
      art->(dbSkip()) 
   ENDDO

   SaveToOO_Interface(aList,,"XLSX")
   Sinkey(0)