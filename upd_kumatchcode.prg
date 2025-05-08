PROC UPD_MATCHCODE
   LOCAL aMatch := {},nX,cNewMatch

   CLS
   
   NetUse("engkund","ku")
   
   ku->(dbSetFilter({|| AT("”",ku->Kunde)!=0.OR.AT("",ku->KUNDE)!=0.OR.AT("„",ku->KUNDE)!=0 },'AT("”",Kunde)!=0.OR.AT("",KUNDE)!=0.OR.AT("„",KUNDE)!=0'))
   ku->(dbGoTop())
   DO WHILE ! ku->(EOF())
      Aadd(aMatch,{ku->Kunde,ku->Group})
      ku->(dbSkip())
   ENDDO

   FOR nX := 1 TO Len(aMatch)
      ?  aMatch[nX,1]
      cNewMatch := Pad(StrTran(StrTran(StrTran(aMatch[nX,1],"”","OE"),"„","AE"),"","UE"),8)

      IF ku->(dbSeek(cNewMatch+aMatch[nX,2]))
         ?? " bereits vorhanden:",cNewMatch
      ELSE
         //ChangeMatchcode
         ku->(dbSeek(aMatch[nX,1]+aMatch[nX,2]))
         Change_MatchCode( aMatch[nX,1], cNewMatch, aMatch[nX,2],.F. )         
         ? "ge„ndert in",cNewMatch
         /*IF Sinkey(0) == 27
            EXIT
         ENDIF*/
      ENDIF
   NEXT
   Sinkey(0)
RETURN
