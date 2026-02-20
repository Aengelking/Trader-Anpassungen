PROC SYNC_Supabase_Website()
   LOCAL oRest := RestApi():New()

   Head("Sync Supabase Website")

   oRest:cBaseUrl := "https://kooxwelqbqplbryoxbya.supabase.co/"
   oRest:cApiKeyName := "WEBSITE"

   _SyncOptionsToSupabase(oRest)
   SInkey(0)
RETURN

STATIC PROCEDURE _SyncOptionsToSupabase(oRest)
   LOCAL cUrl := "functions/v1/erp-options-sync"
   LOCAL cResponse
   LOCAL aHeader := {}
   LOCAL hData := _BuildOptionsJson()

   ? "Sende Options-Daten zu Supabase..."   

   AAdd(aHeader, "Authorization: Bearer $APIKEY$")   

   //gtSetClipboard(HB_JsonEncode(hData)) //debug: copy the json to clipboard

   cResponse := oRest:Execute(cUrl, "POST", hData, aHeader, .T.)

   IF ! Empty(cResponse)
      ? "OPTIONS erfolgreich synchronisiert"
      _PrintSyncResponse(cResponse)
   ELSE
      ? "Fehler: leere Antwort von Supabase"
   ENDIF

RETURN

STATIC FUNCTION _BuildOptionsJson()
   LOCAL aEnv := SaveEnv()
   LOCAL hResult := {=>}
   LOCAL aBases := {}, aTables := {}, aKeys := {}
   LOCAL oBase
   LOCAL hBase, hTable, hKey
   LOCAL oTable2

   @ 01,00 SAY "Lese Options-Daten aus ERP..."

   hResult["bases"]  := aBases
   hResult["tables"] := aTables
   hResult["keys"]   := aKeys

   NetUse("optbas", "opb")
   opb->(dbGoTop())

   DO WHILE ! opb->(EOF())
      IF ! Empty(Trim(opb->MODEL))
         hBase := {=>}
         hBase["model"]          := Trim(opb->MODEL)
         hBase["model_ref"]      := Trim(opb->MODEL1)
         hBase["matchcode"]      := Trim(opb->MATCHCODE)
         hBase["price_domestic"] := opb->PRICE
         hBase["price_export"]   := opb->PRICEX
         hBase["article_nr"]     := IF(opb->ARTIKELNR > 0, opb->ARTIKELNR, NIL)
         AAdd(aBases, hBase)

         oBase := OptionBase():New()
         IF oBase:Load(opb->MODEL)
            oBase:oTables:Each({|oTable|            
               IF oTable:ID != 0
                  @ 02,00 SAY "Verarbeite Tabelle: " + Trim(oTable:Funktion)
                  hTable := {=>}
                  hTable["model"]      := Trim(oTable:Model)
                  hTable["table_nr"]   := oTable:Table
                  hTable["key_length"] := oTable:Length
                  hTable["label"]      := hb_StrToUTF8(Trim(oTable:Funktion))
                  AAdd(aTables, hTable)



                  oTable:oKeys:Each({|oKey|     
                     IF oKey:ID != 0
                        hKey := {=>}
                        hKey["model"]         := Trim(oKey:oTable:Model)
                        hKey["table_nr"]      := oKey:oTable:Table
                        hKey["tab_key"]        := Trim(oKey:TabKey)
                        hKey["description"]    := hb_StrToUTF8(Trim(oKey:Descript))
                        hKey["matchcode"]      := Trim(oKey:MatchCode)
                        hKey["price_domestic"] := oKey:Price
                        hKey["price_export"]   := oKey:Pricex
                        hKey["code"]           := oKey:Code
                        hKey["article_nr"]     := IF(oKey:Artikelnr > 0, oKey:Artikelnr, NIL)
                        AAdd(aKeys, hKey)
                     ENDIF
                     RETURN NIL
                  })
               ENDIF
               RETURN NIL               
            })
         ENDIF
      ENDIF
      opb->(dbSkip())
   ENDDO

   USE
   RestEnv(aEnv)
RETURN hResult

STATIC PROCEDURE _PrintSyncResponse(cResponse)
   LOCAL hResp := NIL
   LOCAL hResults := NIL
   LOCAL nBases := 0
   LOCAL nTables := 0
   LOCAL nKeys := 0

   IF Empty(cResponse)
      RETURN
   ENDIF

   HB_JsonDecode(cResponse, @hResp)

   IF ValType(hResp) != "H"
      ? "Antwort (kein JSON): " + cResponse
      RETURN
   ENDIF

   IF HHasKey(hResp, "success") .AND. hResp["success"]
      IF HHasKey(hResp, "results") .AND. ValType(hResp["results"]) == "H"
         hResults := hResp["results"]

         IF HHasKey(hResults, "bases") .AND. ValType(hResults["bases"]) == "H" .AND. HHasKey(hResults["bases"], "upserted")
            nBases := hResults["bases"]["upserted"]
         ENDIF

         IF HHasKey(hResults, "tables") .AND. ValType(hResults["tables"]) == "H" .AND. HHasKey(hResults["tables"], "upserted")
            nTables := hResults["tables"]["upserted"]
         ENDIF

         IF HHasKey(hResults, "keys") .AND. ValType(hResults["keys"]) == "H" .AND. HHasKey(hResults["keys"], "upserted")
            nKeys := hResults["keys"]["upserted"]
         ENDIF
      ENDIF

      ? "Upserted bases : " + LTrim(Str(nBases))
      ? "Upserted tables: " + LTrim(Str(nTables))
      ? "Upserted keys  : " + LTrim(Str(nKeys))

      IF HHasKey(hResp, "synced_at")
         ? "Synced at: " + hb_ValToStr(hResp["synced_at"])
      ENDIF
   ELSE
      ? "Sync-Response meldet success = false"
      ? "Antwort: " + cResponse
   ENDIF
RETURN
