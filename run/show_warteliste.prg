
NetUse("engbes","bes")
bes->(dbSetOrder( 1 ))
bes->(dbSeek( Str(-1,6) ))
CLS
? pad("Lief.",8),Pad("Artikel",25),Pad("Menge",12),"Besteller"
DO WHILE bes->Besnr == -1
   ? bes->Liefma,bes->Matchcode,bes->BeQty,bes->Buyer
   bes->(dbSkip())
ENDDO
Sinkey(0)