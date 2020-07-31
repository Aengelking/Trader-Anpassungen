/*PROC RUN_TEST_FACTORING
   oRechnung := Rechnung():New()
   oRechnung:Load(53266)
   NetUse("ups","ups")
   NetUse("paknum","pnum")
   RUN_FACTORING(oRechnung)*/

FUNCTION RUN_FACTORING(oRechnung)         
   LOCAL cShipNtf,oPdf
   LOCAL aFiles,aAttach

   cShipNtf := GetEnv("temp")+"\SN"+StrZero(oRechnung:Rechnr,6)+".pdf"
   oPdf := Pdf():New(cShipNtf)
   oPdf:NewPage("A4","P")
   oPdf:SetFont("Helvetica",,18)
   oPdf:AtSay("Versandbenachrichtung Lieferschein Nr. "+Str(oRechnung:Rechnr))
   oPdf:NewLine(2)
   oPdf:SetFont("Helvetica",,12)
   oPdf:AtSay("Tracking-Nr.")
   oPdf:AtSay("Gewicht",,50,"R")
   ups->(dbSetOrder( 3 ))
   IF ups->(dbSeek( Str(oRechnung:Rechnr,10) ))
      pnum->(dbSetOrder( 1 ))
      pnum->(dbSeek( ups->Nr ))
      DO WHILE pnum->Nr == ups->Nr
         oPdf:NewLine()
         oPdf:AtSAy(Trim(pnum->Nummer))
         oPdf:AtSAy(Str(pnum->Weight,5,2)+"kg",,50,"R")
         pnum->(dbSkip())
      ENDDO
   ENDIF
   oPdf:Close()
   aAttach := {cShipNtf}

   aFiles := GetArchiveFiles( {"LS"=>oRechnung:Rechnr} )
   IF Len(aFiles) > 0
      Aadd(aAttach,ATail(aFiles)[6])
   ENDIF

   Sendmail({{"amos.engelking@engelking.de","Amos"},{"sigrid.reichmann@engelking.de","Sigrid"}},"Bitte Factoring anmelden fÅr RE "+LTrim(Str(oRechnung:Rechnr)),"Lieferschein und Versandbenachrichtung im Anhang",aAttach)
   
   oRechnung:State := "FINA"
   oRechnung:Save() //Field("STATE")
RETURN .T.
