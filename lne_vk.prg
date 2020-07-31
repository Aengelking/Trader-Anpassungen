//Gibt Preis fr Proforma Rechnung bei Musterlieferungen zurck

FUNCTION RUN_LNE_VK(oPrinter)   
   LOCAL aEnv:=SaveEnv()
   LOCAL oArt :=Artikel():New()

   IF lne->RefTyp == "BE"  //Rcksendung Lieferant
      NetUse("engbes","bes")
      bes->(dbSeek( Str(lne->RefBeleg,6)+Str(lne->RefPos,3) ))
      oPrinter:posinfo["val"]:=(bes->EkPr/bes->Pe)/Currate(bes->Money,"E")
   ELSE
      oArt:Load(lne->Artikelnr)
      oPrinter:posinfo["val"]:=oArt:GetAvgBuyPrice(Date())*IF(ku->Group=="K",1.5,1)
   ENDIF

   RestEnv(aEnv,.F.)

RETURN Str(oPrinter:posinfo["val"],6,2)+" EUR"