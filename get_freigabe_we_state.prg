FUNC HOOK_Get_Freigabe_WE_State(cState,lFrei,lSonder,nMenge,dBis,nVerbraucht,nArtnr,nSupplier)
   LOCAL hRet
   LOCAL cNextLevel
//PARAMETERS cState,lFrei,lSonder,nMenge,dBis,nVerbraucht,nArtnr,nSupplier

LOCAL oArt := Artikel():New()
oArt:Load(nArtnr)

hRet := {"LWE"=>.F.,"LSPERRONLY"=>.F.,"LNOSPERRQTY"=>0}


   cNextLevel := cState
   If lFrei .OR. cState == ""      
   	cNextLevel := GetNextFreigabeLevel(nArtnr,nSupplier,cState)
   Endif

   cState := "DONE"

   //If (cState == "UNT"  .AND. lFrei) .OR. (art->Gruppe == "KONK" .AND. cState == "UNTK" .AND. lFrei) .OR. (cState == "MUS" .AND. ! lFrei) //Musterfreigabe
   If cNextLevel == "MUS" .OR. cNextLevel == "DONE" .OR. cState == ""
   	hRet:lWE         := .T.
   	hRet:lSperrOnly  := .T.
      HRet:nNoSperrQty := If(Left(art->Gruppe,2)=="KO",If(art->Gruppe == "KONK",1000,10),2000)      
   Elseif cState == "MUS"
   	hRet:lWE         := .T.
   	hRet:lSperrOnly  := .T.
   Elseif cState == "DONE"
   	If lSonder
   		hRet:lWE := dBis <= Date() .AND. nVerbraucht < nMenge
   		hRet:nMaxQty := nMenge-nVerbraucht
   	Else
   		hRet:lWE := .T.
   	Endif
   Endif


Return hRet
