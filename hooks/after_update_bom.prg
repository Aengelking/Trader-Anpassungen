#define CRLF Chr(13)+Chr(10)
PROC HOOK_AFTER_UPDATE_BOM(oBom,lIndexIncreased,oRec)
   LOCAL cText,hFields,hField
   IF /*lIndexIncreased .AND.*/ oBom:oArtikel:QS .AND. oBom:oArtikel:Manufactur != 6
      hFields := oRec:FieldsUpdatedLastSave()
      IF ! HHasKEy(hFields,"POS") .OR. hFields["POS"]["BEFORE"] != 0
         cText := "Position: "+LTrim(Str(oRec:Pos,3))+CRLF
         cText += "Felder: "+CRLF
         FOR EACH hField IN hFields
            cText += "  "+hField:__enumKey()+": "+ValToPrg(hField["BEFORE"])+" => "+ValToPrg(hField["AFTER"])+CRLF
         NEXT

         SendMail({{"amos.engelking@engelking.de","Amos"}},"StÅckliste geÑndert "+Trim(oBom:oArtikel:Matchcode),cText)
      ENDIF
   ENDIF
RETURN