
#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

PROC RUN_IMPORT_SUPPLIER_PARTS
   LOCAL cKunde := Space(8)
   LOCAL getlist := {}
   LOCAL oImport 
   LOCAL aData
   
   Head("Kundenartikelnummern importieren")

   NetUse("engkund","ku")
   NetUse("artkund","aku")
   NetUse("artikel","art")

   @ 01,00 SAY "Kunde" GET cKunde PICTURE "@!" VALID Findad( cKunde, "K", 01, 40 )
   READ

   IF LastKey() == 27
      RETURN
   ENDIF
   
   oImport := CSVImport():New()
   oImport:aFieldNames := {"Matchcode","Bestellnummer"}

   IF oImport:Interface()
      aData := oImport:GetDataAsHash()


      aku->(dbSetOrder( 1 ))

      AEval(aData,{|hRow|
         IF ! Empty(hRow["Matchcode"])
            IF art->(dbSeek( hRow["Matchcode"] )) .AND. Trim(art->Matchcode) == Trim(hRow["Matchcode"])
               ? art->Matchcode,art->Artikelnr
               IF aku->(dbSeek( cKunde+Str(art->Artikelnr,6) ))
                  ?? " update",hRow["Bestellnummer"]
                  aku->(Rec_Lock())
               ELSE
                  aku->(Add_Rec())
                  aku->Artikelnr := art->Artikelnr
                  aku->Matchcode := art->Matchcode
                  aku->Kunde     := cKunde
                  ?? " added"
               ENDIF
               aku->ArtLief := hRow["Bestellnummer"]
               aku->(dbUnLock())
            ELSE
               ? hRow["Matchcode"]," PART NOT FOUND"
            ENDIF
         ENDIF
      
         RETURN .T.
      })

      ? "DONE"
      SInkey(0)
   ENDIF