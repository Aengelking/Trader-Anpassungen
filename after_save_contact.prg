PARAMETERS lNew

//Alert("Contact has been edited "+IF(lNew,"NEW",""))

NetUse("phonebook","pbk")
pbk->(dbSetOrder(2))

cNumber := ""
If At("-",conts->Telephone) == 1
   cNumber := SubStr(ku->Telefon,0,RAt("-",ku->Telefon)-1)+conts->Telephone
Elseif ! Empty(conts->Telephone)
   cNumber := conts->Telephone
EndiF
IF ! pbk->(dbSeek( Str(conts->Address,6)+Str(conts->Number,4) ))   
   pbk->(Add_Rec(0))
   pbk->Address := conts->Address
   pbk->Contact := conts->Number
ELSE
   pbk->(Rec_Lock(0))
ENDIF
pbk->Number := NormalizeTelNo(cNumber)
pbk->(dbUnLock())
