LOCAL aLief := {"WALDOM","TECHNO","BULGIN","ITWMETAL","EDAC"}

NetUse("engbes","bes")

bes->(dbSetOrder( 6 ))

FOR nX := 1 TO Len(aLief)
   IF bes->(dbSeek( Pad(aLief[nX],8)+Str(-1,6) ))
      SendMail({{"daniel.becker@engelking.de","Daniel"}},"Warteliste "+aLief[nX],"Es befinden sich noch Positionen auf der Warteliste von "+ aLief[nX],,.F.)
   ENDIF
NEXT