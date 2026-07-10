FUNC HOOK_APPROVE_RMA(oRMA)

LOCAL nTotAvg := 0,nAvg
LOCAL cText := ""
LOCAL lToOld := .F.,cPosText

oRMA:oPositions:Each({|oPos|
   IF ! oPos:Approved      
      nAvg := oPos:oRechPos:oArtikel:GetAvgBuyPrice(Date())*oPos:Menge
      cPosText := Str(oPos:Pos,3)+" "+Trim(oPos:Matchcode)+" "+LTrim(TransForm(oPos:Menge,oPos:oRechPos:oArtikel:cPicture))+" "+oPos:oRechPos:oArtikel:Me
      cText += cPosText+" Wert: "+LTrim(Str(nAvg,12,2)+";")
      nTotAvg += nAvg      
      
      IF oPos:oRechPos:RechDat < Date()-365
         lToOld := .T.
         
         cText += cPosText+"(RE"+LTrim(Str(oPos:oRechPos:Rechnr))+") „lter als ein Jahr;"
      ENDIF
   ENDIF
})

IF Trim(oRMA:Grund) == "ADR"
   RETURN {"",{Tr_Getini(28)}}
ENDIF

IF Trim(oRMA:Grund) == "DEF" .AND. nTotAvg < 200
   RETURN {"",{Tr_Getini(28)}}
ENDIF

cText += "Gesamtwert: "+LTrim(Str(nTotAvg,12,2))

//RETURN {"",{Tr_Getini(28)}}
RETURN  {cText,{9}}