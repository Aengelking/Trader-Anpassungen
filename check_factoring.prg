
PROC RUN_CHECK_FACTORING
   LOCAL oExtra
   LOCAL aRenr := {},nNr
   LOCAL aIds
   LOCAL oRech,nX
   LOCAL aList
   LOCAL cFile := PatH("export\factoring_"+TtoS(DateTime())+".ods")

   Head("Freigabe Factoringrechnungen prfen")

   NetUse("rechnung","reh")
   SET FILTER TO reh->State == "FINA" //.AND. reh->Rechdat >= StoD("20200501") .AND. reh->Rechdat <= Date()-3 .AND. ! reh->Bezahlt

   reh->(dbGoTop())
   @ 01,00 SAY "Daten werden eingelesen..."
   DO WHILE ! reh->(EOF())
      //oExtra := reh->(ExtraData():New(reh->Rechnr))
      //? reh->Kunde,reh->Rechnr,reh->Rechdat,Pad(oExtra:Factorer,12),oExtra:FactorAprD,IF(reh->Bezahlt,"bezahlt","")
      Aadd(aReNr,reh->Rechnr)
      reh->(dbSkip())
   ENDDO

   
   aIds := GetIdsWithExtraField("REH","FACTORER")
   FOR EACH nNr IN aIds
      IF ! nNr $ aReNr
         Aadd(aReNr,nNr)
      ENDIF
   NEXT
   ASort(aRenr)

   //SetColor("N/W*")
   
   //CLS
   //SetPos(0,0)
   //? Pad("Rechnung",6),Pad("Kunde",8),Pad("R.Datum",8),Pad("Factorer",12),Pad("Annahme",8)
   aList := {{"Rechnung","Kunde","R.Datum","Factorer","Annahme"}}
   nX := 1
   FOR EACH nNr IN aReNr
      oRech := Rechnung():New()
      oRech:Load(nNr)
      IF oRech:RechDat >= StoD("20200101") .AND. oRech:Brutto > 0
         oExtra := reh->(ExtraData():New(nNr))
         IF Mod(nX,2) == 0
            SetColor("N/W*")
         ELSE
            SetColor("W+/N*") 
         ENDIF
         //? Str(nNr,6),oRech:Kunde,oRech:Rechdat,Pad(oExtra:Factorer,12),oExtra:FactorAprD,IF(oRech:Bezahlt,"bezahlt",Space(7))
         Aadd(aList,{nNr,oRech:Kunde,oRech:Rechdat,oExtra:Factorer,oExtra:FactorAprD,IF(oRech:Bezahlt,"bezahlt","")})
         nX++
      ENDIF
   NEXT

   //SaveAsCSVInterface(aList)
   SaveToOO(cFile,aList)
   Wapi_ShellExecute(,"open",cFile)


   //Sinkey(0)
   #include 'x:\run\savetooo.prg'