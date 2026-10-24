PROC RUN_SHOPWARE_PRODUCTS  //download product ID's from the website (Supabase) - runs at night
   //  Frueher wurden die IDs ueber die Shopware-Such-API geholt. Jetzt liefert die
   //  neue Website (Supabase/PostgREST) die Produkte. Gelesen wird mit dem Anon-Key
   //  ueber rest/v1/cms_products (nur is_active=true ist fuer anon sichtbar).
   //
   //  Variante B: es werden nur "Blaetter" gespeichert - also Varianten UND
   //  Einzelartikel ohne Kinder. Serien/Parents (deren id bei anderen als
   //  parent_id vorkommt) werden uebersprungen. Das entspricht dem alten
   //  childCount==0/NIL-Filter.
   LOCAL oSW := Supabase():New("https://kooxwelqbqplbryoxbya.supabase.co/",, "WEBSITE-AN")
   LOCAL nLimit  := 1000   //page size (Supabase max-rows)
   LOCAL nOffset := 0
   LOCAL nDown   := 0
   LOCAL nFound  := 0
   LOCAL nWald   := 0
   LOCAL nStored := 0
   LOCAL cResp
   LOCAL aData
   LOCAL hRow
   LOCAL aAll     := {}      //alle geladenen aktiven Zeilen (gepuffert)
   LOCAL hParents := {=>}    //Set aller vorkommenden parent_id (normalisiert, ohne Bindestriche)
   LOCAL hSeenId  := {=>}    //Set aller aktiven BLATT-ids (fuer den "nicht mehr vorhanden"-Abgleich)
   LOCAL lDownloadOk := .F.
   LOCAL cId, cNum, nArtnr, lFound, nRec
   LOCAL aNotFound, cFile

   Head("Downloading product ID's from Website (Supabase)")

   NetUse("shopware","shop")
   NetUse("artikel","art")
   NetUse("waldom","wald")

   @ 01,00 SAY "Downloaded:"
   @ 02,00 SAY "Found:"
   @ 03,00 SAY "Waldom:"

   //  --- Pass 1: alle aktiven Produkte laden, parent-Set aufbauen, Zeilen puffern ---
   DO WHILE .T.
      cResp := oSW:Execute("rest/v1/cms_products","GET",{;
         "select"    => "id,product_number,parent_id,image_url",;
         "is_active" => "eq.true",;
         "order"     => "product_number",;
         "limit"     => LTrim(Str(nLimit)),;
         "offset"    => LTrim(Str(nOffset))},;
         {"Authorization: Bearer $APIKEY$"})

      aData := NIL
      HB_JsonDecode(cResp, @aData)

      IF ValType(aData) != "A"
         ?? "Fehler beim Abruf der Produktdaten (PostgREST)."
         ? cResp
         EXIT   //Abbruch OHNE Aufraeumen -> keine Massenloeschung bei API-Fehler
      ENDIF

      IF Len(aData) == 0
         lDownloadOk := .T.
         EXIT
      ENDIF

      FOR EACH hRow IN aData
         nDown++
         cId := StrTran(hRow["id"], "-", "")          //Website-uuid ohne Bindestriche -> passt in UUID C(32)
         AAdd(aAll, hRow)
         IF HHasKey(hRow, "parent_id") .AND. ! Empty(hRow["parent_id"])
            hParents[ StrTran(hRow["parent_id"], "-", "") ] := .T.
         ENDIF
      NEXT

      @ 01,13 SAY Str(nDown,10)

      IF Len(aData) < nLimit   //letzte (Teil-)Seite -> fertig
         lDownloadOk := .T.
         EXIT
      ENDIF
      nOffset += nLimit
   ENDDO

   IF ! lDownloadOk
      IF ! GetConfigValue("BATCHMODE")
         ? "Abgebrochen - Datenbank nicht veraendert."
         SInkey(0)
      ENDIF
      RETURN
   ENDIF

   //  Blatt-ids bestimmen (id NICHT im parent-Set) und Set fuer den Abgleich fuellen
   FOR EACH hRow IN aAll
      cId := StrTran(hRow["id"], "-", "")
      IF ! HHasKey(hParents, cId)
         hSeenId[cId] := .T.
      ENDIF
   NEXT

   //  --- Pass 2: nur Blaetter speichern ---
   art->(dbSetOrder( 1 ))   //1 = Matchcode
   FOR EACH hRow IN aAll
      cId  := StrTran(hRow["id"], "-", "")
      cNum := hRow["product_number"]

      IF HHasKey(hParents, cId)   //Serie/Parent -> ueberspringen (Variante B)
         LOOP
      ENDIF

      nArtnr := 0
      IF art->(dbSeek( Pad(cNum, 25) ))   //pad to 25 chars otherwise it can get assigned to the wrong product
         nArtnr := art->Artikelnr
         nFound++
      ENDIF

      //  Datensatz in der shopware-DBF finden bzw. anlegen (Logik wie bisher)
      IF nArtnr != 0
         shop->(dbSetOrder( 1 ))
         lFound := shop->(dbSeek( Str(nArtnr,6) ))
         IF lFound
            nRec := shop->(Recno())

            //check for duplicates and delete them
            shop->(dbSkip(1))
            DO WHILE ! shop->(Eof()) .AND. shop->Artikelnr == nArtnr
               shop->(Rec_Lock(0))
               shop->(dbDelete())
               shop->(dbSkip(1))
            ENDDO
            shop->(dbGoto(nRec))
         ENDIF
      ELSE
         shop->(dbSetOrder( 2 ))   //2 = UUID
         lFound := shop->(dbSeek( cId ))
      ENDIF

      nRec := shop->(Recno())
      shop->(dbSetOrder( 3 ))      //3 = Matchcode
      IF shop->(dbSeek( cNum ))    //search for the matchcode

         IF ! lFound               //If no record was found, we use this one
            nRec := shop->(Recno())
            lFound := .T.
            shop->(dbSkip())
         ENDIF

         //check for duplicates with the same matchcode and delete them, this can happen if the product is recreated
         DO WHILE ! shop->(Eof()) .AND. Trim(shop->Matchcode) == cNum
            IF shop->(Recno()) != nRec   //only delete if the record number is different
               ? "Duplicate found:", Pad(cNum,25), shop->UUID, cId
               shop->(Rec_Lock(0))
               shop->(dbDelete())
               shop->(dbUnLock())
            ENDIF
            shop->(dbSkip(1))
         ENDDO
      ENDIF

      shop->(dbGoto(nRec))

      IF lFound
         shop->(Rec_Lock(0))
      ELSE
         shop->(Add_Rec(0))
      ENDIF
      shop->UUID := cId
      IF nArtnr != shop->Artikelnr
         shop->Bestand := 0
      ENDIF
      shop->Artikelnr := nArtnr
      shop->Matchcode := cNum
      IF nArtnr == 0 .AND. wald->(dbSeek( cNum ))
         shop->Waldom := .T.
         nWald++
      ELSE
         shop->Waldom := .F.
      ENDIF
      shop->HasImage := HHasKey(hRow, "image_url") .AND. ! Empty(hRow["image_url"])
      shop->(dbUnLock())

      nStored++
      @ 02,13 SAY Str(nFound,10)
      @ 03,13 SAY Str(nWald,10)
   NEXT

   //  --- Pass 3: lokale Saetze loeschen, deren UUID kein aktives Blatt mehr ist ---
   shop->(dbSetOrder( 2 ))
   shop->(dbGoTop())
   aNotFound := {{"UUID","Matchcode"}}
   DO WHILE ! shop->(EOF())
      IF ! HHasKey(hSeenId, Trim(shop->UUID))
         Aadd(aNotFound, {shop->UUID, shop->Matchcode})
         ? shop->UUID, shop->Matchcode, " not found anymore"
         shop->(Rec_Lock(0))
         shop->(dbDelete())
         shop->(dbUnLock())
      ENDIF
      shop->(dbSkip())
   ENDDO

   IF Len(aNotFound) > 1
      cFile := GetEnv("temp")+"\shopware_notfound_"+TtoS(DateTime())+".csv"
      SaveAsCSV(cFile, aNotFound, .T.)
      ? "List of not found products saved to "+cFile
      SendMessage("PRODUKTMANAGEMENT | Produkte nicht mehr auf der Website","Produkte nicht mehr auf der Website","Im Anhang eine Liste an Produkten die frueher vorhanden waren aber nicht mehr auf der Website sind.",{cFile})
   ENDIF

   IF ! GetConfigValue("BATCHMODE")
      ? "completed - gespeichert:", LTrim(Str(nStored))
      SInkey(0)
   ENDIF

   #include 'x:\run\shopware.prg'
   #include 'x:\run\supabase_api.prg'
