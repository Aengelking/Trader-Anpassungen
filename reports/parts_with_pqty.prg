PROC RUN_REPORTS_PART_WITH_PQTY   
   LOCAL aList
   LOCAL cSupplier := Space(8)
   LOCAL getlist := {}
   LOCAL bAdd,cWork

   Head("Artikel eines Lieferanten mit VPE's")

   NetUse("artikel","art")
   NetUse("artlief","ali")
   NetUse("engkund","ku")
   NetUse("parts","part")

   @ 01,00 SAY "Lieferant" GET cSupplier VALID FindAd(cSupplier,"L",02,00) PICTURE "@!"
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   art->(dbSetOrder( 2 ))
   part->(dbSetOrder( 2 ))

   aList := {{"Part no.","Your part no.","Work order part","packaging quantity"}}

   bAdd := {|cWork| 
      IF art->VPE != 0
         @ 10,00 SAY art->Matchcode+" "+ali->Artlief+" "+Transform(art->Vpe,Me(art->Me))
         IF AScan(aList,{|x| x[1] == Trim(art->Matchcode) }) == 0
            Aadd(aList,{Trim(art->Matchcode),Trim(ali->Artlief),cWork,LTrim(Transform(art->Vpe,Me(art->Me)))})
         ENDIF
      ENDIF
      RETURN .T.
   }

   ali->(dbSeek( cSupplier ))
   DO WHILE ali->Kunde == cSupplier .AND. ! ali->(EOF())
      art->(dbSeek( Str(ali->Artikelnr,6) )) 
      IF Trim(art->Type) == "LOHN" //by these we need to look at the main part
         ? "LOHN",art->Matchcode
         cWork := art->Matchcode         
         part->(dbSeek( Str(ali->Artikelnr), .T. ))
         DO WHILE part->PartArt == ali->Artikelnr .AND. ! part->(EOF())
            art->(dbSeek( Str(part->Listart,6) ))
            ? art->Matchcode
            Eval(bAdd,cWork)
            part->(dbSkip())
         ENDDO
      ELSE
         Eval(bAdd,"")         
      ENDIF
      ali->(dbSkip())
   ENDDO

   SaveAsCSVInterface(aList)
   //? Len(aList)
   //Sinkey(0)

RETURN

