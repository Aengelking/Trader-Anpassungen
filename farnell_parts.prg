PROC FarnellParts
   LOCAL aParts := {{"PART","URL"}}
NetUse("comprice2","cmp2")
NetUse("artlief","ali")

DO WHILE ! cmp2->(Eof())
   IF cmp2->Lieferant == 4825 .AND. cmp2->Datum >= StoD("20240101")
      IF ali->(dbSeek( "FARNELL "+Str(cmp2->Artikelnr,6) )) .AND. ! Empty(ali->Artlief)
         ? ali->Artlief 
         Aadd(aParts,{Trim(ali->Matchcode),"https://de.farnell.com/x/x/x/dp/"+Trim(ali->Artlief)})
      ENDIF
   ENDIF
   cmp2->(dbSkip())
ENDDO
Sinkey(0)
SaveToOO_Interface(aParts,,"xlsx",.T.)

//#include 'X:\run\savetooo.prg'