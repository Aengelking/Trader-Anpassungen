LOCAL cNumber

NetUse("phonebook","pbk")
NetUse("engkund","ku")
NetUse("contacts","conts")

CLS

pbk->(dbSetOrder(2))
ku->(dbSetOrder(8))
ku->(dbGoTop())

/*DO WHILE ! ku->(EOF())
   @ 00,00 SAY ku->Nummer
   IF ! pbk->(dbSeek( Str(ku->Nummer,6)+Str(0,4) ))
      pbk->(Add_Rec(0))
      pbk->Address := ku->Nummer
   ELSE
      pbk->(Rec_Lock(0))
   ENDIF
   pbk->Number := NormalizeTelNo(ku->Telefon)
   pbk->(dbUnLock())
   ku->(dbSkip())
ENDDO*/

conts->(dbGoTop())
DO WHILE ! conts->(EOF())   
   ku->(dbSeek(Str(conts->Address,6)))
   @ 00,00 SAY ku->Nummer
   @ 01,00 SAY conts->Number   
   IF ! pbk->(dbSeek( Str(conts->Address,6)+Str(conts->Number,4) ))
      pbk->(Add_Rec(0))
      pbk->Address := conts->Address
      pbk->Contact := conts->Number
   ELSE
      pbk->(Rec_Lock(0))
   ENDIF
   cNumber := ""
	If At("-",conts->Telephone) == 1
		cNumber := SubStr(ku->Telefon,0,RAt("-",ku->Telefon)-1)+conts->Telephone
	Elseif ! Empty(conts->Telephone)
		cNumber := conts->Telephone
	EndiF

   pbk->Number := NormalizeTelNo(cNumber)
   pbk->(dbUnLock())
   conts->(dbSkip())
ENDDO