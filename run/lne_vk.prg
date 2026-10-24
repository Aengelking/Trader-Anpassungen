//Gibt Preis fr Proforma Rechnung bei Musterlieferungen zurck

FUNCTION RUN_LNE_VK(oPrinter)   
   LOCAL aEnv:=SaveEnv()
   LOCAL oArt :=Artikel():New()
   LOCAL cCur := "EUR"

   IF lne->RefTyp == "BE"  //Rcksendung Lieferant
      NetUse("engbes","bes")
      bes->(dbSeek( Str(lne->RefBeleg,6)+Str(lne->RefPos,3) ))
      oPrinter:posinfo["val"]:=(bes->EkPr/bes->Pe) //Currate(bes->Money,"E")
      IF ! HHAsKey(oPrinter:posinfo,"curcode") 
         cCur := Currate(bes->Money,"X")
         oPrinter:posinfo["curcode"] := bes->Money
      ELSEIF oPrinter:posinfo["curcode"] != bes->Money
         oPrinter:posinfo["val"] *= Currate(bes->Money,"E") / Currate(oPrinter:posinfo["curcode"],"E")
      ENDIF
   ELSE
      oArt:Load(lne->Artikelnr)
      oPrinter:posinfo["val"]:=oArt:GetAvgBuyPrice(Date())*IF(ku->Group=="K",1.5,1)
      IF oPrinter:posinfo["val"] == 0
         oPrinter:posinfo["val"] := oArt:Letzte_Ek/oArt:PE*IF(ku->Group=="K",1.5,1)
      ENDIF
      IF oPrinter:posinfo["val"] == 0
         oPrinter:posinfo["val"] := 0.1
      ENDIF
      oPrinter:posinfo["curcode"] := "E"
   ENDIF

   oPrinter:posInfo["postot"]:= (lne->menge+lne->Fremd-GetEntFremdLagerQty(lne->Nummer,lne->Pos))*oPrinter:posinfo["val"]   
   oPrinter:posInfo["total"]+=oPrinter:posInfo["postot"]   

   oPrinter:posinfo["cur"] := cCur
    

   RestEnv(aEnv,.F.)

RETURN Str(oPrinter:posinfo["val"],6,2)+" "+cCur