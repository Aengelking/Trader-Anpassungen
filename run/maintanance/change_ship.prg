/**
  * Ändert die Standard Versandart bei Adressen von UPS auf Beliebige 
  *
  **/
  
NetUse("engkund","ku")

ku->(dbSetOrder( 2 ))
ku->(dbSeek("K"))

DO WHILE ku->Group == "K"
   IF ku->Versandart == 2
      ? ku->Kunde
      ku->(Rec_Lock())
      ku->Versandart := 1
      ku->(dbUnLock())
   ENDIF
   ku->(dbSkip())
ENDDO
