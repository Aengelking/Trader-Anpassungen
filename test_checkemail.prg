FUNCTION CheckEmail(cEmail)
   LOCAL lFound := .F.
   NetUse("engkund","ku")
   NetUse("contacts","conts")

   conts->(dbSetOrder( 3 )) //lower(email)
   ku->(dbSetOrder( 8 ))   
   conts->(dbSetRelation("ku",{|| Str(conts->Address,6) },"Str(address,6)"))      
   conts->(dbSeek(Trim(Lower(cEmail))))   
   DO WHILE ! lFound .AND. Trim(Lower(cEmail)) == Trim(Lower(conts->Email))      
      IF ku->Group == "K" .AND. conts->Active .AND. conts->Anrede != 0
         lFound := .T.
         EXIT
      ENDIF
      conts->(dbSkip())
   ENDDO   
   conts->(dbClearRelation())
   IF lFound
      Alert("Email "+cEmail+" found in contacts as "+Trim(conts->Name)+" Address: "+ku->Kunde+" "+ku->Group)
   ELSE
      Alert("Email "+cEmail+" not found in contacts")
   ENDIF
RETURN lFound