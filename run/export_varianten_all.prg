PROC RUN_EXPORT_VARIANTEN
   LOCAL oBase
   LOCAL cBase := Pad("CMI",24)
   //LOCAL nLen
   //LOCAL aData := {{"Matchcode"}}
   LOCAL cTab1 := "15/"
   LOCAL nTab,nX
   LOCAL getlist := {}
   LOCAL aParts := {},aParentParts
   LOCAL hInclude,lInclude
   LOCAL hInc

   Head("Export alle m”glichen Variantenoptionen")

   @ 01,00 SAY "Variantenbasis" GET cBase
   //READ
   
   hInclude := {;   
      2=>{ "AS/"=>{ 1=>{"15/"} },"BN/"=>{1=>{"15/"}},"V2/"=>{1=>{"15/"}} },;   
      3=>{ "F/"=>{1=>{"15/"}},"R/"=>{1=>{"15/"}} },;
      4=>{ "D/"=>{1=>{"15/"}},"R/"=>{1=>{"15/"}}, "P/"=>{ 1=>{"15/"},3=>{"F/"} }, "S/"=>{ 1=>{"15/"},3=>{"F/"} } },;
      5=>{ "GN/"=>{1=>{"15/"}},"RD/"=>{1=>{"15/"}},"YL/"=>{1=>{"15/"}},"BL/"=>{1=>{"15/"}},"WH/"=>{1=>{"15/"}},"GR/"=>{1=>{"15/"}},"BR/"=>{1=>{"15/"}},"GB/"=>{1=>{"15/"}},"BW/"=>{1=>{"15/"}},"GO/"=>{1=>{"15/"}},"GW/"=>{1=>{"15/"}},"RY/"=>{1=>{"15/"}},"WR/"=>{1=>{"15/"}} },;
      6=>{ "00/" =>{1=>{"15/"}},"06/" =>{1=>{"15/"}},"12/" =>{1=>{"15/"}},"24/" =>{1=>{"15/"}} },;
      7=>{ "M/" =>{1=>{"15/"}}, "L/" =>{1=>{"15/"}} },;
      8=>{ "S/" =>{1=>{"15/"}}, "D/" =>{1=>{"15/"}} },;
      9=>{ "18"=>{1=>{"15/"}} };
   }
   
   oBase := OptionBase():New()
   oBase:Load( cBase )
   //nLen := Len(Trim(cBase))
   nTab := 0

   Aadd(aParts,{Trim(cBase),cTab1})

   oBase:oTables:Each({|oTable|
      LOCAL oKey
      nTab++
      ? oTable:Funktion
      IF nTab == 1         
         oKey := oTable:oKeys:GetRecord(cTab1)                           
      ELSE
         aParentParts := AClone(aParts)
         aParts := {}
   
         oTable:oKeys:Each({|oKey|            
            FOR nX := 1 TO Len(aParentParts)
               lInclude := .T.
               IF HHasKey(hInclude,nTab) //if there are no inclusions for this tab or this tabkey is not in the names inclusiosn it is inclued by default
                  IF ! HHasKey(hInclude[nTab],oKey:TabKey) //this Key has not been included into anything, might need to change this if we transfer from a hash to the DB
                     LOOP
                  ENDIF
                  FOR EACH hInc IN hInclude[nTab,oKey:TabKey]
                     IF hInc:__eNumKey() != 1
                        ? aParentParts[nX,hInc:__eNumKey()+1]
                     ENDIF
                     IF ! aParentParts[nX,hInc:__eNumKey()+1] $ hInc //not included, go to next part                           
                        lInclude := .F.
                        ?? "exclude"
                        EXIT
                     ENDIF
                  NEXT      
                  IF ! lInclude
                     LOOP
                  ENDIF               
               ENDIF                  
               Aadd(aParts,AClone(aParentParts[nX]))
               Aadd(ATail(aParts),Trim(oKey:TabKey))
            NEXT
            
            RETURN NIL
         })
      ENDIF
      /*IF oKey != NIL
         nLen += oTable:Length
         IF ! Empty(oKey:Descript)
            nP := AScan(aData[1],Trim(oTable:Funktion("DE")))
            IF nP == 0
               Aadd(aData[1],Trim(oTable:Funktion("DE")))
               Aadd(Atail(aData),NIL)
               nP := Len(aData[1])
            ENDIF
            ATail(aData)[nP] := oKey:descript("DE")                  
         ENDIF
      ENDIF*/
      RETURN NIL
   })
   IF Tr_MsgBox("Display parts?",,{"Yes","No"}) == 1
      FOR nX := 1 TO Len(aParts)
         ? ""
         FOR nTab := 1 TO Len(aParts[nX])
            ?? aParts[nX,nTab]
         NEXT
      NEXT
   ENDIF
   ? "No. of parts:",Len(aParts)

   

   SaveAsCSVInterFace(aParts)
   SiNkey(0)