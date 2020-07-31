FUNCTION HOOK_BEFORE_SHIP_RECHNUNG(oRechnung,lShip)
   LOCAL oExtra
   LOCAL nCurWeek
   LOCAL lAllDue

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
                  Tr_MsgBox({"Bei diesem Kunden darf nur zum best„tigten Termin geliefert werden.","Daher kann diese nicht freigeben werden."})
                  RETURN .F.
               ENDIF
            ENDIF
            RETURN .T.
         })
         IF ! lAllDue
            RETURN .F.            
         ENDIF
      ENDIF
   ENDIF

RETURN .T.