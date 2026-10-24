
#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

PROC RUN_IMPORT_SUPPLIER_PARTS
   LOCAL cLief := Space(8)
   LOCAL getlist := {}
   LOCAL oImport 
   LOCAL aData
   
   Head("Lieferantenartikelnummern importieren")

   NetUse("engkund","ku")
   NetUse("artlief","ali")
   NetUse("artikel","art")

   @ 01,00 SAY "Lieferant" GET cLief PICTURE "@!" VALID Findad( cLief, "L", 01, 40 )
   READ

   IF LastKey() == 27
      RETURN
   ENDIF
   
   oImport := CSVImport():New()
   oImport:aFieldNames := {"Matchcode","Bestellnummer"}

   IF oImport:Interface()
      aData := oImport:GetDataAsHash()


      ali->(dbSetOrder( 1 ))

      AEval(aData,{|hRow|
         IF ! Empty(hRow["Matchcode"])
            IF art->(dbSeek( hRow["Matchcode"] )) .AND. Trim(art->Matchcode) == Trim(hRow["Matchcode"])
               ?? "",art->Matchcode,art->Artikelnr
               IF ali->(dbSeek( cLief+Str(art->Artikelnr,6) ))
                  ?? " update",hRow["Bestellnummer"]
                  ali->(Rec_Lock())
               ELSE
                  ali->(Add_Rec())
                  ali->Artikelnr := art->Artikelnr
                  ali->Matchcode := art->Matchcode
                  ali->Kunde     := cLief
                  ?? " added"
               ENDIF
               ali->ArtLief := hRow["Bestellnummer"]
               ali->(dbUnLock())
            ELSE
               ?? "",hRow["Matchcode"]," PART NOT FOUND"
            ENDIF
         ENDIF
      
         RETURN .T.
      })

      ? "DONE"
      SInkey(0)
   ENDIF