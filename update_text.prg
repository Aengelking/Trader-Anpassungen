LOCAL nID
LOCAL aIDS := {"OP"=>0,"OPT"=>0}

NetUse("text","txt")
netUSe("opttab","opt")
NetUSe("option","op")
NetUse("ID","ID")

DO WHILE ! txt->(Eof())
   cAlias := SubStr(txt->Field_Ref,0,At("_",txt->Field_Ref)-1)
   txt->(Rec_Lock())
   txt->ID := txt->Recno
   txt->(dbUnLock())
   txt->(dbSkip())
ENDDO

FOR EACH cAlias IN {"OP","OPT"}
   (cAlias)->(dbGoTop())
   DO WHILE ! (cAlias)->(EOF())
      (cAlias)->(Rec_Lock())
      (cAlias)->ID := (cAlias)->(Recno())
      (cAlias)->(dbUnLock())
      aIDS[cAlias] := Max(aIDS[cAlias],(cAlias)->(Recno()))
      (cAlias)->(dbSkip())
   ENDDO
NEXT

FOR EACH nID IN aIDS
   IF id->(dbSeek(nID:__enumKey()))
      id->(Rec_Lock())
   ELSE
      id->(Add_Rec())
      id->Alias := nID:__enumKey()
   ENDIF
   id->ID := nID
NEXT

