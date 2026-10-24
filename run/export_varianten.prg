PROC RUN_EXPORT_VARIANTEN
   LOCAL oBase
   LOCAL cBase
   LOCAL nLen
   LOCAL aData := {{"Matchcode"}}
   LOCAL nP
   LOCAL cFilter := "variant='V' .AND. ! obsolete"

   Head("Export Artikel mit Variantenoptionen")

   NetUse("artikel","art")
   art->(dbSetFilter({|| art->(&(cFilter)) },cFilter))
   art->(dbGoTop())

   DO WHILE ! art->(EOF()) .AND. Inkey() != 27
      @ 01,00 SAY art->Matchcode+" "+art->variant
      Aadd(aData,Array(Len(aData[1])))
      Atail(aData)[1] := art->Matchcode
      cBase := Substr( art->Matchcode,1,art->length )            
      oBase := OptionBase():New()
      oBase:Load( cBase )
      nLen := art->Length+1
      
      oBase:oTables:Each({|oTable|
         LOCAL oKey
         oKey := oTable:oKeys:GetRecord(SubStr( art->Matchcode,nLen,oTable:Length ))                  
         IF oKey != NIL
            nLen += oTable:Length
            IF ! Empty(oKey:Descript)
               nP := AScan(aData[1],Trim(oTable:Funktion("DE")))
               IF nP == 0
                  Aadd(aData[1],Trim(oTable:Funktion("DE")))
                  Aadd(Atail(aData),NIL)
                  nP := Len(aData[1])
               ENDIF
               ATail(aData)[nP] := oKey:descript("DE")                  
            ENDIF
         ENDIF
         RETURN NIL
      })
      art->(dbSetFilter({|| art->(&(cFilter)) },cFilter))
      art->(dbSkip())
   ENDDO
   SaveAsCSVInterFace(aData)