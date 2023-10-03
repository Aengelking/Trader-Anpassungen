LOCAL aLief := {} // {"WALDOM","TECHNO","BULGIN","ITW","EDAC"}

NetUse("engbes","bes")

bes->(dbSetOrder( 1 ))
bes->(dbSeek( Str(-1,6) ))
DO WHILE bes->Besnr == -1
   IF ! bes->Liefma $ aLief
      SendMail({{"daniel.becker@engelking.de","Daniel"}},"Warteliste "+trim(bes->Liefma),"Es befinden sich noch Positionen auf der Warteliste von "+ Trim(bes->Liefma),,.F.)
      Aadd(aLief,bes->Liefma)
   ENDIF
   bes->(dbSkip())
ENDDO
/*FOR nX := 1 TO Len(aLief)
   IF bes->(dbSeek( Pad(aLief[nX],8)+Str(-1,6) ))
      SendMail({{"daniel.becker@engelking.de","Daniel"}},"Warteliste "+aLief[nX],"Es befinden sich noch Positionen auf der Warteliste von "+ aLief[nX],,.F.)
   ENDIF
NEXT*/