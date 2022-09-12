   #define CRLF Chr(10)+Chr(13)

   PROC RUN_AUF_SET_DELDATE()
   LOCAL cFilter 
   LOCAL hUser := {=>},aOrders,nX
   LOCAL nLastAB,cText,oUser

   NetUse("artikel","art")
   NetUse("engauf","auf")
   auf->(dbSetOrder( 14 ))
   art->(dbSetOrder( 2 ))
      
   cFilter := 'Right(Str(dterm,4),2) $ {"97","98"} .AND. ! Trim(Matchcode) $ {"PORTO","FREIGHT"} .AND. bestat != 3'
   auf->(dbSetFilter({|| auf->(&(cFilter))},cFilter))
   auf->(dbGoTop())

   CLS

   DO WHILE ! auf->(EOF())
      ? auf->Abnr
      
      IF ! HHasKey(hUser,auf->Buyer)
         hUser[auf->Buyer] := {}
      ENDIF
      Aadd(hUser[auf->Buyer],{auf->Abnr,auf->Itmnr,_FindMoveWeek()})

      auf->(dbSkip())
   ENDDO

   CLS

   auf->(dbSetOrder( 1 ))

   

   FOR EACH aOrders IN hUser
      ? aOrders:__eNumKey()
      oUser := User():New()
      oUser:Load((aOrders:__eNumKey))
      nLastAB := 0
      cText := "Hallo "+SubStr(oUser:Name,1,AT(" ",oUser:Name)-1)+","+CRLF+CRLF+"folgende Auftr„ge stehen noch auf 'Termin folgt' oder 'Unbekannt':<pre>"   
      cText += "AB-Nr. Pos "+Pad("Artikel",25)+PadL("Menge",12)+" "+Space(4)+" "+"m”glicher Termin"+CRLF
      FOR nX := 1 TO Len(aOrders)
         auf->(dbSeek( Str(aOrders[nX,1],6)+Str(aOrders[nX,2]) ))

         IF nLastAB != auf->Abnr
            cText += Str(auf->Abnr,6) //+" vom: "+DtoC(auf->Besda)+". "+IF(Empty(auf->LastPrint),"Bisher keine AB verschickt","AB gedruckt am: "+DtoC(auf->LastPrint))+CRLF            
         ELSE
            cText += Space(6)
         ENDIF
         art->(dbSeek( Str(auf->Artikelnr,6) ))
         cText += " "+Str(auf->Itmnr)+" "+auf->Matchcode+PadL(Transform(auf->VkQty,Me(art->Me)),12)+" "+art->Me+" "+IF(!Empty(aOrders[nX,3]),NiceWeek(aOrders[nX,3]),"-")+CRLF
         nLastAB := auf->Abnr
      NEXT
      
      SendMail({{oUser:Email,oUser:Name}/*,{"amos.engelking@engelking.de","Amos","CC"}*/},"Auftr„ge mit 'Termin folgt'/'Unbekannt'",cText) //,,,,.T.)
   NEXT

   ? "Done"
   //Sinkey(0)



STATIC Function _FindMoveWeek(nMaxWeeks)
Local nWeek,lMove,nMoveWeek
   Default(@nMaxWeeks,52)      
   nWeek := 1
   lMove := .F.
   Do While nWeek <= nMaxWeeks
      nMoveWeek := AddWeeks(CWeek(Date()),nWeek)
      If GetKWStock(auf->Artikelnr,nMoveWeek,,.T.) >= auf->VkQty-auf->GelQty
         lMove := .T.
         EXIT
      Endif
      nWeek++
   Enddo
   If ! lMove
      Return ""
   Endif
Return nMoveWeek