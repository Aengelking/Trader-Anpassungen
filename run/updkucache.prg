LOCAL hTurnover

   NetUse("engkund","ku",.F.,0)
   ku->(dbGoTop())
   ku->(dbSetOrder(2))

   ku->(dbSeek("K",.T.)) //look for the first customer

   Do While ! ku->(EOF()) .AND. ku->GROUP == "K"

      @ MaxRow(),00 SAY ku->Kunde

      //both function fill the cache file
      GetCustomerTurnover(ku->Kunde)
      GetCustomerOpenEnquiries(ku->Kunde)
      
      ku->(dbSkip())
   ENDDO