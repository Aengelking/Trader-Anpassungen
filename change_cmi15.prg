PROC RUN_ChangeCMI15
   LOCAL aArticles,nArtikelnr,oArt
   LOCAL cNewMatch
   NetUse("artikel","art")
   
   aArticles := CollectArticlesWithMatchcode({"CM15", "CM16", "CMI15", "CMI16"})
   
   CLS
   
   // Display or process the results
   
   FOR EACH nArtikelnr IN aArticles      
      art->(dbSetOrder( 2 ))
      art->(dbSeek( Str(nArtikelnr,6) ))
      oArt := Artikel():New()
      ? nArtikelnr,oArt:Matchcode
      IF oArt:Bestand == 0 .AND. ! oArt:HasOpenSalesOrder() .AND. ! oArt:HasOpenPurchaseOrder()
         ?? " no SO & PO"
         cNewMatch := StrTran(oArt:Matchcode,"/18","/28")
         IF cNewMatch == oArt:Matchcode
            ?? " no change"
         ELSE
            ?? " new matchcode: ",cNewMatch         
            IF oArt:ChangeMatchcode(cNewMatch)
               ?? " changed"            
            ELSE
               ?? " ERROR"
               Sinkey(0)
            ENDIF
         ENDIF
         
      ENDIF

   NEXT

   Sinkey(0)


FUNCTION CollectArticlesWithMatchcode(aPatterns)
   LOCAL aArticles := {}
   LOCAL cPattern
   
   // Open the article database
   NetUse("artikel", "art")
   
   // Loop through all articles
   art->(dbSetOrder( 1 ))
   art->(dbGoTop())
   FOR EACH cPattern IN aPatterns
      art->(dbSeek( cPattern , .T.))
      DO WHILE ! art->(Eof()) .AND. SUBSTR(art->Matchcode, 1, LEN(cPattern)) == cPattern
         
         AADD(aArticles,art->Artikelnr )
         
         
         art->(dbSkip())
      ENDDO
   NEXT
   
   
RETURN aArticles