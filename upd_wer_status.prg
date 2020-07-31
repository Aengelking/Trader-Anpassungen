NetUse("werkauf","wer")
NetUse("artikel","art")
art->(dbSetOrder( 2 ))
cFilter := 'Status < 4 .AND. Qty == 0' //nicht erledigte Rahmen-WA's

wer->(dbSetFilter({|| wer->(&(cFilter)) },cFilter))
wer->(dbGoTop())
DO WHILE ! wer->(Eof())
   ? wer->Aufno
   wer->(Rec_Lock())
   wer->Status := 4
   wer->(dbUnLock())
   wer->(dbSkip())
ENDDO
wer->(dbClearFilter())
SInkey(0)