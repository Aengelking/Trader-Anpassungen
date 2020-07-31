PARAMETERS oRMA

LOCAL nTotAvg := 0,nAvg
LOCAL cText := ""

oRMA:oPositions:Each({|oPos|
   IF ! oPos:Approved
      nAvg := oPos:oRechPos:oArtikel:GetAvgBuyPrice(Date())*oPos:Menge
      cText += Trim(oPos:Matchcode)+" "+LTrim(TransForm(oPos:Menge,oPos:oRechPos:oArtikel:cPicture))+" "+oPos:oRechPos:oArtikel:Me+" Wert: "+LTrim(Str(nAvg,12,2)+";")
      nTotAvg += nAvg
   ENDIF
})

IF Trim(oRMA:Grund) == "DEF" .AND. nTotAvg < 200
   RETURN {"",{Tr_Getini(28)}}
ENDIF

cText += "Gesamtwert: "+LTrim(Str(nTotAvg,12,2))

//RETURN {"",{Tr_Getini(28)}}
RETURN  {cText,{9}}