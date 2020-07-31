NetUse("engbes","bes")
bes->(dbSetOrder( 1 ))
bes->(dbSeek( Str(-1,6) ))
CLS
DO WHILE bes->Besnr == -1
   ? bes->Liefma,bes->Matchcode,bes->BeQty,bes->Buyer
   bes->(dbSkip())
ENDDO
Sinkey(0)