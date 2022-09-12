PROC RUN_CHECK_ISO
   LOCAL aSupplier
   LOCAL nLief,oExtra
   LOCAL nWarnDays := 30
   LOCAL aTo := {{"amos.engelking@engelking.de","Amos"},{"daniel.becker@engelking.de","Daniel"}}
   //LOCAL aTo := {{"amos.engelking@engelking.de","Amos"}}
   LOCAL hDocuments := {;
      "QISO9001"=>{"EXPIRE"=>.T.,"MIN_DATE"=>StoD(""),"NAME"=>"ISO Zertifikat","LEVEL_MISSING"=>8,"LEVEL_INVALID"=>0},;
      "QREACH"=>{"EXPIRE"=>.F.,"MIN_DATE"=>StoD("20220610"),"NAME"=>"REACH Best„tigung","LEVEL_MISSING"=>9,"LEVEL_INVALID"=>9},;
      "QROHS"=>{"EXPIRE"=>.F.,"MIN_DATE"=>StoD("20190101"),"NAME"=>"RoHS Best„tigung","LEVEL_MISSING"=>9,"LEVEL_INVALID"=>9},;
      "QTSCA"=>{"EXPIRE"=>.F.,"MIN_DATE"=>StoD("20190101"),"NAME"=>"TSCA Best„tigung","LEVEL_MISSING"=>9,"LEVEL_INVALID"=>9};
   }
   LOCAL hDoc,cField
   LOCAL cTable := ""
   LOCAL hDocs := {=>},cDocs
   CLS

   NetUse("engkund","ku")

   ku->(dbSetOrder( 8 ))

   FOR EACH hDoc IN hDocuments
      cField := hDoc:__enumkey()

      aSupplier := GetIdsWithExtraField("KU",cField)

      FOR EACH nLief IN aSupplier
         ku->(dbSeek( Str(nLief) ))
         IF ! HHasKey(hDocs,nLief)
            hDocs[nLief] := ""
         ENDIF
         IF ku->Group != "L"
            ? nLief,"Not a supplier"
         ELSE
            oExtra := ku->(ExtraData():New(nLief))
            IF Val(oExtra:Level) >= hDoc["LEVEL_INVALID"]
               ? nLief,oExtra:Get(cField)
               IF hDoc["EXPIRE"] .AND. oExtra:Get(cField)+nWarnDays <= Date()               
                  IF ! Empty(hDocs[nLief])
                     hDocs[nLief] += "<br />"
                  ENDIF
                  hDocs[nLief] += hDoc["NAME"]+" "+IF(oExtra:Get(cField)<Date(),"ist","l„uft")+" am "+DtoC(oExtra:Get(cField))+" ab"+IF(oExtra:Get(cField)<Date(),"gelaufen","")
                  //SendMail(aTo,Trim(ku->Kunde)+" "+hDoc["NAME"]+" "+IF(oExtra:Get(cField)<Date(),"abgelaufen","l„uft ab"),hDoc["NAME"]+" "+IF(oExtra:Get(cField)<Date(),"ist","l„uft")+" am "+DtoC(oExtra:Get(cField))+" ab"+IF(oExtra:Get(cField)<Date(),"gelaufen",""))
               ELSEIF ! Empty(hDoc["MIN_DATE"]) .AND. oExtra:Get(cField) < hDoc["MIN_DATE"]
                  IF ! Empty(hDocs[nLief])
                     hDocs[nLief] += "<br />"
                  ENDIF
                  hDocs[nLief] += hDoc["NAME"]+" ist seit dem "+DtoC(hDoc["MIN_DATE"])+" veraltet"
                  //SendMail(aTo,Trim(ku->Kunde)+" "+hDoc["NAME"]+" veraltet",hDoc["NAME"]+" ist seit dem "+DtoC(hDoc["MIN_DATE"])+" veraltet")   
               ENDIF
            ENDIF
         ENDIF
      NEXT

      //Check if all suppliers with a certain level have this document      
      aSupplier := GetIdsWithExtraField("KU","LEVEL")

      FOR EACH nLief IN aSupplier
         ku->(dbSeek( Str(nLief) ))
         IF ku->Group != "L"
            ? nLief,"Not a supplier"
         ELSE
            oExtra := ku->(ExtraData():New(nLief))
            ? ku->Kunde,oExtra:Level,oExtra:Get(cField)
            IF Val(oExtra:Level) >= hDoc["LEVEL_MISSING"] .AND. Empty(oExtra:Get(cField))
               IF ! Empty(hDocs[nLief])
                  hDocs[nLief] += "<br />"
               ENDIF
               hDocs[nLief] += hDoc["NAME"]+" fehlt"
               //SendMail(aTo,Trim(ku->Kunde)+" "+hDoc["NAME"]+" fehlt")
            ENDIF
         ENDIF
      NEXT
   NEXT
   IF Len(hDocs) > 0
      FOR EACH cDocs IN hDocs
         IF ! Empty(cDocs)
            ku->(dbSeek( Str(cDocs:__enumKey()) ))   
            cTable += "<tr><td>"+Trim(ku->Kunde)+"</td><td>"+cDocs+"</td></tr>"
         ENDIF
      NEXT
      SendMail(aTo,"Fehlende/Abgelaufene Dokumente","<table border='1'>"+cTable+"</table>")
   ENDIF
   ? "complete"
   //Sinkey(0)
   