FUNCTION HOOK_BEFORE_SHIP_RECHNUNG(oRechnung,lShip)
   LOCAL oExtra
   LOCAL nCurWeek
   LOCAL lAllDue
   LOCAL lAllWeight,cText

   IF lShip      
      oRechnung:oKunde:gotoRec()
      oExtra := ku->(ExtraData():New(oRechnung:oKunde:Nummer))
      
      IF oExtra:NoWish               
         //as we cannot prevent an invoice beeing created we check afterwards if all positions are not being shipped any earlier than confirmed
         //if they are, we will not allow the invoice to be "freigegeben"
         nCurWeek := Cweek(Date())
         
         oRechnung:Positions:Each({ |oPos|
            LOCAL lDue
            lAllDue := .T.            
            IF oPos:AoQty > 0               
               auf->(dbSetOrder( 1 ))
               auf->(dbSeek( Str(oPos:AbNr,6)+Str(oPos:RePosnr,3)))
            
               IF oRechnung:oKunde:Justintime 
                  //Alert("Liefertag: "+DtoC(GetJITLiefertag(auf->BDatum,ku->JIT_LZ)))
                  lDue := GetJITLiefertag(auf->BDatum,oRechnung:oKunde:JIT_LZ) <= Date()
               ELSE
                  lDue := auf->dterm <= nCurWeek
               ENDIF               
               IF ! lDue
                  lAllDue := .F.
                  IF GetConfigValue("BATCHMODE")                     
                     SendMail(GetConfigEmail("SO-READY"),"Rechnung konnte nicht verschickt werden "+LTrim(Str(oRechnung:Rechnr)),"Bei diesem Kunden darf nur zum best„tigten Termin geliefert werden."+Chr(10)+Chr(13)+"Daher kann diese nicht freigeben werden.")
                  ELSE
                     Tr_MsgBox({"Bei diesem Kunden darf nur zum best„tigten Termin geliefert werden.","Daher kann diese nicht freigeben werden."})
                  ENDIF
                  RETURN .F. //break out of loop
               ENDIF
            ENDIF
            RETURN .T.
         })
         IF ! lAllDue
            RETURN .F.            
         ENDIF
      ENDIF
      IF oExtra:PrintWeigh
         lAllWeight := .T.
         cText := "Bei den folgenden Artikeln fehlt das Stckgewicht:"
         oRechnung:Positions:Each({ |oPos|
            IF oPos:oArtikel:Gewicht == 0
               lAllWeight := .F.
               cText += Chr(10)+Chr(13)+oPos:oArtikel:Matchcode
            ENDIF
            RETURN .T.
         })
         IF ! lAllWeight
            SendMail(GetConfigEmail("SO-READY"),"Rechnung konnte nicht verschickt werden "+LTrim(Str(oRechnung:Rechnr)),cText)
         ENDIF
      ENDIF
   ENDIF

RETURN .T.