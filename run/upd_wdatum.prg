LOCAL nKey := 0,lFound := .T.
NetUse("engauf","auf")
NetUse("engkund","ku")

auf->(dbSetOrder( 14 ))


DO WHILE nKey != 27 .AND. lFound
   auf->(dbGoTop())
   CLS
   SetPos(0,0)
   DO WHILE auf->BeStat < 3 .AND. ! auf->(EOF())
      IF auf->VkQty > auf->GelQty .AND. Right(Str(auf->Dterm,4),2) != "99"
         dFriday := CalWd(auf->Wterm)+4
         IF auf->Wdatum < dFriday-4 .OR. auf->Wdatum > dFriday
            ku->(dbSeek( auf->Kundma+"K" ))
            IF ! ku->JustInTime
               IF auf->WTerm <= 1602  //wterm in the past we can update these automatically to the friday.
                  auf->(Rec_Lock())
                  auf->WDatum := dFriday
                  auf->(dbUnLock())
               ELSE
                  ? auf->Abnr,auf->Itmnr,StrZero(auf->WTerm,4),CalWD(auf->Wterm),auf->Wdatum
               ENDIF
               IF Row() == MaxRow() //reached end of screen
                  EXIT
               ENDIF
            ENDIF
         ENDIF
      ENDIF
      auf->(dbSkip())
   ENDDO

   nKey := SInkey(5,128)
ENDDO