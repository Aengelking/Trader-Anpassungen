NetUse("Auftrag","ab")
NetUse("engauf","auf")

auf->(dbGoTop())
DO WHILE ! auf->(EOF())
   IF ! ab->(dbSeek( Str(auf->AbNr,6) ))
      ab->(Add_Rec(0))
   ELSE
      ab->(Rec_Lock(0))
   ENDIF
   ab->AbNr := auf->Abnr
   ab->Kundma := auf->Kundma
   ab->Money  := auf->Money

   ab->Ablade := auf->Ablade
   ab->ReliefAdr := auf->ReLiefAdr
   ab->DelAd     := auf->DelAd
   ab->Person    := auf->Person
   ab->Buyer     := auf->Buyer
   ab->Besda     := auf->Besda
   ab->(dbUnLock())

   auf->(dbSkip())
ENDDO
