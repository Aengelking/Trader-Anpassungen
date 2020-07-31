FUNCTION OnpowPartno(cMatch,nLength)

LOCAL aParts,nRef,cPart
LOCAL hTablesRef,cBase
LOCAL hReferences := {=>}
LOCAL oOptBase,cArt,cRef

IF ValType(cMatch) != "C" .OR. nLength == 0
   IF art->Length == 0 .OR. art->Length == Len(Trim(art->matchcode))
      RETURN ""
   ENDIF
   nLength := art->Length
   cMatch := art->Matchcode
ENDIF

cBase := Left(cMatch,nLength)

oOptBase := OptionBase():New()
oOptBase:Load( cBase )

hReferences["SERIES"] := {"10/"=>"GQ16","11/"=>"GQ16P","20/"=>"GQ19","21/"=>"GQ19P","22/"=>"GQ19S","23/"=>"GQ19SP","25/"=>"LAS1GQ","26/"=>"LAS1GQP",;
                            "30/"=>"LAS1-AGQ","31/"=>"LAS1-AGQP","35/"=>"GQ22","36/"=>"GQ22P","37/"=>"GQ22F","38/"=>"GQ22PF","40/"=>"GQ25","41/"=>"GQ25P","45/"=>"GQ28","46/"=>"GQ28P","50/"=>"GQ30","51/"=>"GQ30P"}
IF cBase == "CI"
   hReferences["SERIES"]   := HB_HCopy({"02/"=>"GQ6","03/"=>"GQ6","04/"=>"GQ8","05/"=>"GQ8","06/"=>"GQ10","07/"=>"GQ10","08/"=>"GQ12","09/"=>"GQ14","12/"=>"GQ12","13/"=>"GQ14"},hReferences["SERIES"])
ELSE
   hReferences["SERIES"]   := HB_HCopy({"08/"=>"GQ12-A","15/"=>"LAS2GQ","16/"=>"LAS2GQP"},hReferences["SERIES"])
ENDIF
hReferences["MATERIAL"] := {"AS/"=>"/A","AB/"=>"/BU","AG/"=>"/GN","AN/"=>"/NT","AR/"=>"/RD","BN/"=>"/N","V2/"=>"/S","MB/"=>"/A","BG/"=>"/G","GA/"=>"/GA"} //,"AN/"=>"/NT","AR/"=>"/RD","AG/"=>"/GN"
IF cBase == "CI"
   hReferences["BUTTON"]   := {"D/"=>"G-","F/"=>"T-","P/"=>"F-","R/"=>"H-"}
ELSE
   hReferences["BUTTON"]   := {"F/"=>"F-","R/"=>"H-","D/"=>"B-"}
ENDIF
hReferences["LEDTYPE"]  := {"D/"=>"D","P/"=>"DT","R/"=>"E","S/"=>"ET","F/"=>"D"}
hReferences["LEDCOLOR"] := {"01/"=>"/31GR","02/"=>"/31GB","03/"=>"/31BR","10/"=>"/42RGB","11/"=>"/41RGB","12/"=>"/42WBG","13/"=>"/41WBG","14/"=>"/42RGY","15/"=>"/41RGY","16/"=>"/42GRW","17/"=>"/41GRW",;
                            "BL/"=>"/B","BR/"=>"/2BR","GB/"=>"/2GB","GN/"=>"/G","GO/"=>"/2GO","GR/"=>"/2GR","RD/"=>"/R","WH/"=>"/W","WR/"=>"/2RW","YL/"=>"/Y","OR/"=>"/O","BW/"=>"/2BW","RY/"=>"/2RY","GO/"=>"/2GO"}
hReferences["LEDVOLT"]  := {"00/"=>"/0V","06/"=>"/6V","12/"=>"/12V","24/"=>"/24V","30/"=>"/30V"}
hReferences["FUNCTION"] := {"M/"=>"","L/"=>"Z"}
hReferences["POLES"]    := {"D/"=>"22","S/"=>"11"}
hReferences["CONNTYPE"] := {=>}
IF cBase == "CI"
   hReferences["IP"] := {"25/"=>"/FP","26/"=>"/FP","35/"=>"/FP","36/"=>"/FP","40/"=>"/FP","41/"=>"/FP","45/"=>"/FP","46/"=>"/FP","50/"=>"/FP","51/"=>"/FP"}
ELSE
   hReferences["IP"] := {=>}
ENDIF
//hReferences["LEDSPECIAL"] := {"10/"=>"/C+","11/"=>"/C-","12/"=>"/C+","13/"=>"/C-","14/"=>"/C+","15/"=>"/C-","01/"=>"-3P","02/"=>"-3P","03/"=>"-3P","16/"=>"/C+","17/"=>"/C-"}

IF cBase == "CMI"
   hTablesRef := {"SERIES"=>1,"BUTTON"=>3,"POLES"=>8,"FUNCTION"=>7,"LEDTYPE"=>4,"CONNTYPE"=>9,"LEDCOLOR"=>5,"LEDVOLT"=>6,"MATERIAL"=>2,"IP"=>7} //,"LEDSPECIAL"=>5}
ELSEIF cBase == "CM"
   hTablesRef := {"SERIES"=>1,"BUTTON"=>3,"POLES"=>5,"FUNCTION"=>4,"CONNTYPE"=>6,"MATERIAL"=>2,"IP"=>4}
ELSE
   hTablesRef := {"SERIES"=>1,"BUTTON"=>3,"LEDTYPE"=>4,"CONNTYPE"=>7,"LEDCOLOR"=>5,"LEDVOLT"=>6,"MATERIAL"=>2,"IP"=>1} //,"LEDSPECIAL"=>5}
ENDIF

cArt := SubStr(cMatch,nLength+1)

aParts := {}
oOptBase:oTables:Each({|oTable|
   Aadd(aParts,Left(cArt,oTable:Length))
   cArt := SubStr(cArt,oTable:Length+1)
   RETURN NIL
})

IF aParts[1] $ {"90/","05/"}  //cannot create part no for these series
   RETURN ""
ENDIF

IF aParts[1] $ {"35/","36/","40/","41/","45/","46/","50/","51/","55/","56/"}
   hReferences["CONNTYPE"] := {"ST"=>"-L"}            
   FOR EACH nRef IN hTablesRef
      IF cBase == "CMI"
         hTablesRef := {"SERIES"=>1,"CONNTYPE"=>9,"BUTTON"=>3,"POLES"=>8,"FUNCTION"=>7,"LEDTYPE"=>4,"LEDCOLOR"=>5,"LEDVOLT"=>6,"MATERIAL"=>2,"IP"=>7} //,"LEDSPECIAL"=>5}
      ELSEIF cBase == "CM"
         hTablesRef := {"SERIES"=>1,"CONNTYPE"=>6,"BUTTON"=>3,"POLES"=>5,"FUNCTION"=>4,"MATERIAL"=>2,"IP"=>4}
      ENDIF
   NEXT
ENDIF

cPart := ""
FOR EACH nRef IN hTablesRef
   //? nRef:__enumKey()
   IF HHasKey(hReferences[nRef:__enumKey()],aParts[nRef])
      cRef := hReferences[nRef:__enumKey()][aParts[nRef]]
      cPart += cRef
      IF nRef:__enumKey() == "SERIES"
         //Series dependant setting
         IF cRef+"|" $ "GQ12-A|GQ16|GQ16P|GQ19|GQ19P|GQ19S|GQ19SP|GQ22F|"
            hReferences["CONNTYPE"] := {"20"=>"/J","28"=>"/J"}
            IF cBase == "CMI" .AND. cRef $ {"GQ16"}
               hReferences["CONNTYPE"]["ST"] := "/L"
            ENDIF
            IF aParts[IF(cBase == "CMI",7,4)] == "N/"  //special case, when normaly open then singlepole code changes
               hReferences["POLES"]    := {"S/"=>"01"}
            ELSE
               hReferences["POLES"]    := {"S/"=>"10"}
            ENDIF
         ELSEIF cRef $ {"LAS1GQ","LAS1GQP"}
            hReferences["CONNTYPE"] := {"ST"=>"/L"}
         ENDIF
         IF cRef+"|" $ "LAS1GQ|LAS1-AGQ|GQ22|GQ25|GQ28|GQ30|GQ22F|"
            hReferences["BUTTON"]["F/"] := "-"
            hReferences["BUTTON"]["P/"] := "-"
         ENDIF
         IF cBase != "CI"
            IF cRef+"|" $ "LAS1GQ|LAS1GQP|GQ22|GQ22P|GQ25|GQ25P|GQ28|GQ28P|GQ30|GQ30P|"
               hReferences["IP"] := {"M/"=>"/FP"}
            ELSEIF cRef+"|" $ "LAS2GQ|LAS2GQP|"
               hReferences["IP"] := {"M/"=>"/FP","L/"=>"/FP"}
            ENDIF
         ENDIF
      ELSEIF nRef:__enumKey() == "LEDTYPE" .AND. cRef+"|" $ "DT|ET|" .AND. hReferences["SERIES"][aParts[hTablesRef["SERIES"]]] != "LAS2GQ"
         hReferences["IP"] := {=>}
      ENDIF
   ENDIF
NEXT
RETURN cPart
