LOCAL aLief := {} // {"WALDOM","TECHNO","BULGIN","ITW","EDAC"}
LOCAL oExtra

NetUse("engbes","bes")
NetUse("engkund","ku")

bes->(dbSetOrder( 1 ))
bes->(dbSeek( Str(-1,6) ))
DO WHILE bes->Besnr == -1
   IF ! bes->Liefma $ aLief
      ku->(dbSeek( bes->Liefma+"L" ))
      oExtra := ku->(ExtraData():New(ku->Nummer))
      IF oExtra:Wait_Day == Dow(Date())
//         SendMail({{"daniel.becker@engelking.de","Daniel"}},"Warteliste "+trim(bes->Liefma),"Es befinden sich noch Positionen auf der Warteliste von "+ Trim(bes->Liefma),,.F.)
         SendMessage("Einkauf | Warteliste",,"Warteliste "+trim(bes->Liefma),"Es befinden sich noch Positionen auf der Warteliste von "+ Trim(bes->Liefma))
      ENDIF
      Aadd(aLief,bes->Liefma)
   ENDIF
   bes->(dbSkip())
ENDDO
/*FOR nX := 1 TO Len(aLief)
   IF bes->(dbSeek( Pad(aLief[nX],8)+Str(-1,6) ))
      SendMail({{"daniel.becker@engelking.de","Daniel"}},"Warteliste "+aLief[nX],"Es befinden sich noch Positionen auf der Warteliste von "+ aLief[nX],,.F.)
   ENDIF
NEXT*/