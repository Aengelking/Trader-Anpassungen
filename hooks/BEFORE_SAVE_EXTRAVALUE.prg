Function BEFORE_SAVE_EXTRAVALUE(cName,oExtra)
   LOCAL aText,hReq
   IF oExtra:cDBID == "ART"            
      IF Trim(cName) == "COC" .AND. oExtra:CoC .AND. ! oExtra:Get("COC",,.T.) .AND. art->Bestand != 0         
         aText := {"CoC kann nicht gesetzt werden"}
         IF art->Bestand != 0
            Aadd(aText,"Artikel hat Bestand")
         ENDIF
         hReq := GetProductRequirementAndIncoming(art->Artikelnr)
         IF hReq["income"] != 0
            Aadd(aText,"Artikel bereits bestellt")
         ENDIF
         IF Len(aText) > 1
            Tr_MsgBox(aText)
            RETURN .F.
         ENDIF
      ENDIF
   ENDIF
