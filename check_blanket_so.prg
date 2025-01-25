#define CRLF Chr(13)+Chr(10)

PROCEDURE Check_Blanket_So()
   LOCAL nWeeksBefore := GetValue("SALES_FRAME_WARN",4,"Warnung - Wochen for Rahmenablauf")
   LOCAL cKey
   LOCAL hAB := {=>},oUser
        
   NetUse("artikel","art")
   NetUse("engkund","ku")
   NetUSe("engauf","auf")   
   NetUse("notes","nts")
   
   SET RELATION TO auf->kundma+"K" INTO "ku"

   auf->(dbSetOrder( 14 ))
   auf->(dbSetFilter({|| auf->VkQty-auf->GelQty > 0 .AND. Val(Right(Str(auf->dterm,4),2)) == 99 .AND. auf->Wterm < AddWeeks(Cweek(),nWeeksBefore) .AND. wterm >= CWeek(Date())   },; 
                        "VkQty-GelQty > 0 .AND. Val(Right(Str(dterm,4),2)) == 99 .AND. wterm < "+Str(AddWeeks(CWeek(Date()),nWeeksBefore),4)+" .AND. wterm > "+CalWeek(Date()) ))      
   auf->(dbGoTop())

   DO WHILE auf->Bestat < 3 .AND. ! auf->(EOF())
      art->(dbSeek(auf->Matchcode))
      cKey := auf->Kundma+Str(auf->Buyer,2)
      IF ! HHasKey(hAb,cKey)
         hAB[cKey] := {"TEXT"=>"","KUNDE"=>auf->Kundma,"USER"=>auf->Buyer,"NOTES"=>"","AB"=>{}}
      ENDIF      
      IF ! Empty(hAB[cKey]["TEXT"])
         hAB[cKey]["TEXT"] += Chr(13)+Chr(10)
      ENDIF
      hAB[cKey]["TEXT"] += Str(auf->Abnr,6)+" "+Str(auf->Itmnr,3)+" "+Dtoc(auf->Besda)+" "+auf->Matchcode+" "+PadL(Transform(auf->ContrQty,Me(art->Me)),12)+" "+PadL(Transform(auf->VkQty-auf->GelQty,Me(art->Me)),12)+" "+art->Me+" "+NiceWeek(CWeek(auf->WDatum))+" "+NiceWeek(auf->Wterm)
      IF ! auf->Abnr $ hAB[cKey]["AB"]
         Aadd(hAB[cKey]["AB"],auf->Abnr)
         hAB[cKey]["NOTES"] += StrTran(GetNotesForAb(auf->Abnr),"<h3>Notizen</h3>","<h3>Notizen AB "+LTrim(Str(auf->Abnr))+"</h3>")
      ENDIF

      auf->(dbSkip())
            
   ENDDO
   
   auf->(dbClearFilter())
   auf->(dbClearRelation())

   auf->(dbSetOrder( 1 ))
   
   FOR EACH cKey IN HGetKeys(hAB)
      
      hAB[cKey]["TEXT"] := Pad("AB",6)+" "+Pad("Pos",3)+" "+Pad("Datum",8)+" "+Pad("Artikel",25)+" "+PadL("Menge",12)+" "+PadL("Offen",12)+" "+Space(4)+" "+Pad("Geplant",8)+" "+Pad("Ende",8)+Chr(13)+Chr(10)+hAB[cKey]["TEXT"]+Chr(13)+Chr(10)+hAB[cKey]["NOTES"]
      oUser := User():New()
      oUser:Load(hAB[cKey]["USER"])
      //
      SendMail({{oUser:Email,oUser:Name}},"Rahmen von "+Trim(hAb[cKey]["KUNDE"])+" "+IF(Len(hAB[cKEy]["AB"])>1,"laufen","l„uft")+" bald ab",hAB[cKey]["TEXT"])
   NEXT

RETURN 