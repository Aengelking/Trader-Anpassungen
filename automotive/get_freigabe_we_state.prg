FUNC HOOK_Get_Freigabe_WE_State(cState,lFrei,lSonder,nMenge,dBis,nVerbraucht,nArtnr,nSupplier)
   LOCAL hRet
   LOCAL cNextLevel

   LOCAL oArt := Artikel():New()
   oArt:Load(nArtnr)

   hRet := {"LWE"=>.F.,"LSPERRONLY"=>.F.,"LNOSPERRQTY"=>0}

   /*cNextLevel := cState
   If lFrei .OR. cState == ""      
   	cNextLevel := GetNextFreigabeLevel(nArtnr,nSupplier,cState)
   Endif*/

   cState := "DONE"

   //If (cState == "UNT"  .AND. lFrei) .OR. (art->Gruppe == "KANK" .AND. cState == "UNTK" .AND. lFrei) .OR. (cState == "MUS" .AND. ! lFrei) //Musterfreigabe
   If cState == "PRUE"
   	hRet:lWE         := .T.
   	hRet:lSperrOnly  := .T.
      hRet:nNoSperrQty := 15
   Elseif cState == "DONE"
   	hRet:lWE := .T.   	
   Endif


Return hRet
