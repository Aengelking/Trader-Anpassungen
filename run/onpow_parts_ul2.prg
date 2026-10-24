PROC RUN_Onpow_Parts_UL
   
LOCAL aData,aTabsOnpow,aTabsEng,aOrder
LOCAL aTabs,cTab
LOCAL aList,aListOld,aPart,nX,aP,cPart
LOCAL aCSV := {{"Supplier Model","ML Model"}}

   aData := {;
         /*++++ GQ22 and co. indicators ++++*/;
         {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CI",;
         "ONPOW"=>{;
            {"22","25","28","30","40"},;
            {""},;
            {"D","E"},;
            {" f/b any letter f/b "},;
            {"6V","12V","24V"},;
            {"S","A"},;
            {""};
         },;
         "ENG" => {;
            {"35/","40/","45/","50/","55/"},;
            {"P/"},;
            {"D/","R/"},;
            {" f/b any two letters or numbers f/b "},;
            {"06/","12/","24/"},;
            {"V2/","AS/"},;
            {"28"};
         },;   
         "ORDER" => {1,3,4,5,6,2,7};
      },;
      {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CI",;
         "ONPOW"=>{;
            {"22P","25P","28P","30P","40P"},;
            {"F"},;
            {"D","E"},;
            {" f/b any letter f/b "},;
            {"6V","12V","24V"},;
            {"S","A"},;
            {""};
         },;
         "ENG" => {;
            {"36/","41/","46/","51/","56/"},;
            {"F/"},;
            {"D/","R/"},;
            {" f/b any two letters or numbers f/b "},;
            {"06/","12/","24/"},;
            {"V2/","AS/"},;
            {"28"};            
         },;   
         "ORDER" => {1,3,4,5,6,2,7};
      },; 
      /*+++++ GQ 16 indicators ++++++*/;
      {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CI",;
         "ONPOW"=>{;
            {"16"},;
            {"B","F","H"},;
            {"D","E"},;
            {"J"},;
            {" f/b any letter f/b "},;
            {"","6V","12V","24V"},;
            {"N","S","A"};
         },;
         "ENG" => {;
            {"10/"},;
            {"D/","P/","R/"},;
            {"D/","R/"},;
            {"20"},;
            {" f/b any two letters or numbers f/b "},;
            {"00/","06/","12/","24/"},;
            {"BN/","V2/","AS/"};
         },;
         "ORDER" => {1,3,4,7,5,6,2};
      },;
      {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CI",;
         "ONPOW"=>{;
            {"16P"},;
            {"F","H"},;
            {"D","E"},;
            {"J"},;
            {" f/b any letter f/b "},;
            {"","6V","12V","24V"},;
            {"N","S","A"};
         },;
         "ENG" => {;
            {"11/"},;
            {"F/","R/"},;
            {"D/","R/"},;
            {"20"},;
            {" f/b any two letters or numbers f/b "},;
            {"00/","06/","12/","24/"},;
            {"BN/","V2/","AS/"};
         },;
         "ORDER" => {1,3,4,7,5,6,2};
      },;
      /*+++++ GQ22 and co. ++++++*/;
      {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CMI",;
         "ONPOW"=>{;
            {"22","22PF","25","25PF","28","28PF","30","30PF","40","40PF"},;
            {"11","22"},;
            {"Z",""},;
            {"D","E"},;
            {" f/b any letter f/b "},;
            {"","6V","12V","24V"},;
            {"S","A"},;
            {""},;
            {""};
         },;
         "ENG" => {;
            {"35/","36/","40/","41/","45/","46/","50/","51/","55/","56/"},;
            {"S/","D/"},;
            {"L/","M/"},;
            {"D/","R/"},;
            {" f/b any two letters or numbers f/b "},;
            {"00/","06/","12/","24/"},;
            {"V2/","AS/"},;
            {"28"},;
            {"F/"};
         },;   
         "ORDER" => {1,8,7,4,5,6,2,9,3};
      },;
      {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CM",;
         "ONPOW"=>{;
            {"22","22PF","25","25PF","28","28PF","30","30PF","40","40PF"},;
            {"11","22"},;
            {"Z",""},;
            {"S","A"},;
            {""},;
            {""};
         },;
         "ENG" => {;
            {"35/","36/","40/","41/","45/","46/","50/","51/","55/","56/"},;
            {"S/","D/"},;
            {"L/","M/"},;
            {"V2/","AS/"},;
            {"28"},;
            {"F/"};
         },;   
         "ORDER" => {1,5,4,2,6,3};
      },;
      /*+++++ GQ 16 ++++++*/;
      {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CMI",;
         "ONPOW"=>{;
            {"16"},;
            {"B","F","H"},;
            {"10"},;
            {"D","E"},;
            {"J"},;
            {" f/b any letter f/b "},;
            {"","6V","12V","24V"},;
            {"N","S","A"},;
            {""};
         },;
         "ENG" => {;
            {"10/"},;
            {"D/","F/","R/"},;
            {"S/"},;
            {"D/","R/"},;
            {"20"},;
            {" f/b any two letters or numbers f/b "},;
            {"00/","06/","12/","24/"},;
            {"BN/","V2/","AS/"},;
            {"M/"};
         },;
         "ORDER" => {1,3,8,4,9,5,6,2,7};
      },;
      /*++++ GQ16P ++++*/;
      {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CMI",;
         "ONPOW"=>{;
            {"16P"},;
            {"F","H"},;
            {"10"},;
            {"D","E"},;
            {"J"},;
            {" f/b any letter f/b "},;
            {"","6V","12V","24V"},;
            {"N","S","A"},;
            {""};
         },;
         "ENG" => {;
            {"11/"},;
            {"F/","R/"},;
            {"S/"},;
            {"D/","R/"},;
            {"20"},;
            {" f/b any two letters or numbers f/b "},;
            {"00/","06/","12/","24/"},;
            {"BN/","V2/","AS/"},;
            {"M/"};
         },;
         "ORDER" => {1,3,8,4,9,5,6,2,7};
      },;
      {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CM",;
         "ONPOW"=>{;
            {"16"},;
            {"B","F","H"},;
            {"10"},;
            {""},;
            {"","J"},;
            {"N","S","A"};
         },;
         "ENG" => {;
            {"10/"},;
            {"D/","F/","R/"},;
            {"S/"},;
            {"M/"},;
            {"ST","20"},;
            {"BN/","V2/","AS/"};
         },;
         "ORDER" => {1,3,5,4,6,2};
      },;
      {;
         "ONPOW_BASE"=>"GQ",;
         "BASE"=>"CM",;
         "ONPOW"=>{;
            {"16P"},;
            {"F","H"},;
            {"10"},;
            {""},;
            {"","J"},;
            {"N","S","A"};
         },;
         "ENG" => {;
            {"11/"},;
            {"F/","R/"},;            
            {"S/"},;
            {"M/"},;
            {"ST","20"},;
            {"BN/","V2/","AS/"};
         },;
         "ORDER" => {1,3,5,4,6,2};
      };      
      /*++++ LAS1-A ++++
         only key switches are covered which we do not have
      */;           
   }

   FOR nX := 1 TO Len(aData)
      aTabsOnpow := aData[nX,"ONPOW"]
      aTabsEng   := aData[nX,"ENG"]
      aOrder     := aData[nX,"ORDER"]

      aList := {{"",Array(Len(aTabsOnpow))}}

      FOR EACH aTabs IN aTabsOnpow 
         aListOld := aList
         aList := {}
         FOR EACH cTab IN aTabs
            FOR EACH aPart IN aListOld
               aP := AClone(aPart[2])
               aP[aOrder[aTabs:__eNumIndex()]] := aTabsEng[aTabs:__eNumIndex()][cTab:__eNumIndex()]
               Aadd(aList,{aPart[1]+cTab,aP})
               //? Atail(aList)[1]
               //? ValToPrg(Atail(aList)[2])
            NEXT
            IF Upper(Chr(Inkey())) == "P"
               IF SInkey(0) == 27
                  RETURN
               ENDIF
            ENDIF
         NEXT
      NEXT   

      FOR EACH aPart IN aList
         cPart := aData[nX,"BASE"]
         AEval(aPart[2],{|x| cPart += x })
         ? aData[nX,"ONPOW_BASE"]+aPart[1],"=>",cPart
         Aadd(aCSV,{aData[nX,"ONPOW_BASE"]+aPart[1],cPart})
      NEXT
      ? "Total: ",Len(aList)
   NEXT
   SaveAsCSV(Path("export\onpw_ul.csv"),aCSV)
   SInkey(0)
