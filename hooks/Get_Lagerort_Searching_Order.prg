FUNC Get_Lagerort_Searching_Order(aLoop,nAdressnr)
   LOCAL oExtra := art->(ExtraData():New(art->Artikelnr))

   IF oExtra:Expires //as if the part has "charge" activated the sort order of the database is accoringly so we have a chronoligcal order and take the stock in that order
      Aadd(aLoop,{{|| ! lago->Sperrlager .AND. lago->Address == nAdressnr },3,3})
      Aadd(aLoop,{{|| ! lago->Sperrlager .AND. lago->Address == 0 },3,3})
   ENDIF
   
RETURN aLoop