PROC RUN_ListTakenOrte
   LOCAL nCount := 0
   CLS
   
   NetUse("artikel","art")
   NETUSE("LAGER","LAG")

   art->(dbSetOrder( 2 ))
   
   lag->(dbSetOrder(2))
   Select("lag")
   SET FILTER TO lag->Taken  .AND. Val(Left(Lag->Lagerort,3)) $ {0,1,2,3,45}

   lag->(dbGoTop())

   DO WHILE ! lag->(EOF())      
      //Left(lag->Lagerort,6) > "000/04" .AND. ! (lag->Lagerort >= "000/03A017" .AND. lag->Lagerort <= "000/03A076") .AND. ! (lag->Lagerort >= "000/04A017" .AND. lag->Lagerort <= "000/04A076") .AND. ! (lag->Lagerort >= "000/09A001" .AND. lag->Lagerort <= "000/09A099") 
      IF AllTrim(lag->Lagerort) != "/" .AND. ! Empty(lag->Lagerort) .AND.;         
         ! (lag->Lagerort >= "000/03A017" .AND. lag->Lagerort <= "000/03A076") .AND. ! (lag->Lagerort >= "000/04A017" .AND. lag->Lagerort <= "000/04A076") .AND. ! (lag->Lagerort >= "000/09A001" .AND. lag->Lagerort <= "000/09A099")    
         art->(dbSeek( Str(lag->Artikelnr,6) ))
         ? art->Matchcode,lag->Lagerort,lag->Lagermenge
         nCount++
      ENDIF
      lag->(dbSkip())
   ENDDO
   ? "Anzahl: ",nCount
   Sinkey(0)
RETURN