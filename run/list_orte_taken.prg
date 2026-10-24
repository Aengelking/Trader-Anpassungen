PROC RUN_ListTakenOrte
   LOCAL nCount := 0
   LOCA oP
   CLS
   
   NetUse("artikel","art")
   NETUSE("LAGER","LAG")

   art->(dbSetOrder( 2 ))
   
   lag->(dbSetOrder(2))
   Select("lag")
   SET FILTER TO lag->Taken  .AND. Val(Left(Lag->Lagerort,3)) $ {0,1,2,3,45}

   lag->(dbGoTop())

   StartPrint(,,"PDF")
   oP := getCurrentPrinterObject()
   oP:Data:NewPage()

   oP:Data:SetFont("Fixed")
   oP:Data:AtSay(Pad("Artikel",25)+" "+Pad("Art.nr",6)+" "+Pad("Lagerort",10)+" "+Pad("Menge",12))

   DO WHILE ! lag->(EOF())      
      //Left(lag->Lagerort,6) > "000/04" .AND. ! (lag->Lagerort >= "000/03A017" .AND. lag->Lagerort <= "000/03A076") .AND. ! (lag->Lagerort >= "000/04A017" .AND. lag->Lagerort <= "000/04A076") .AND. ! (lag->Lagerort >= "000/09A001" .AND. lag->Lagerort <= "000/09A099") 
      IF AllTrim(lag->Lagerort) != "/" .AND. ! Empty(lag->Lagerort) .AND.;         
         ! (lag->Lagerort >= "000/03A017" .AND. lag->Lagerort <= "000/03A076") .AND. ! (lag->Lagerort >= "000/04A017" .AND. lag->Lagerort <= "000/04A076") .AND.;
         ! (lag->Lagerort >= "000/09A001" .AND. lag->Lagerort <= "000/09A099")    
         
         art->(dbSeek( Str(lag->Artikelnr,6) ))
         //? art->Matchcode,lag->Lagerort,lag->Lagermenge
         oP:Data:NewLine()
         oP:Data:AtSay(art->Matchcode+" "+Str(art->Artikelnr,6)+" "+lag->Lagerort+" "+Transform(lag->Lagermenge,Me(art->Me)))
         nCount++
      ENDIF
      lag->(dbSkip())
   ENDDO
   //? "Anzahl: ",nCount
   
   CopyPrint()

   //Sinkey(0)
RETURN