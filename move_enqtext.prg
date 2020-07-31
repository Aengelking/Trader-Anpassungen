LOCAL aTexts,nText,aAli,cAli

IF Tr_Getini(28) != 9
   RETURN
ENDIF

aTexts := {}

Head("ENQTEXT in ENGTEXT übertragen")

NetUse("enqtext","etx")
NetUse( "engtext2","tx" )
NetUse("angebot","ang")

ang->(dbGoTop())
DO WHILE ! ang->(EOf())
   IF ang->Text != 0 .AND. etx->(dbSeek( ang->Text )) .AND. ! tx->(dbSeek( ang->Text ))
      cText := ""
      DO WHILE etx->TextNr == ang->Text
         IF ! Empty(cText)
            cText += Chr(13)+Chr(10)
         ENDIF
         cText += etx->Text
         etx->(dbSkip())
      ENDDO
     tx->(Add_Rec(0))
     tx->TextNr := ang->Text
     tx->Text := cText
     tx->(dbUnLock())
   ENDIF
   ang->(dbSkip())
ENDDO


? "DONE"
Inkey(0,128)