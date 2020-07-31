LOCAL aList := {}
LOCAL cFile
NetUse("artikel","art")
art->(dbSetOrder( 2 ))
art->(dbGoTop())

CLS

Aadd(aList,{"Matchcode","Menge"})
DO WHILE ! art->(EOF())
//   IF art->Manufactur == 1 //bulgin
      hReqInc := GetProductRequirementAndIncoming(art->artikelnr)
      IF hReqInc["requirement"] != 0
//      nOver := art->Bestand+hReqInc["income"]-hReqInc["requirement"]
      nOver := GetKWStock(art->artikelnr,2052)
      IF nOver < 0
         ? art->Matchcode,nOver
         Aadd(aList,{art->Matchcode,nOver})
      ENDIF
      ENDIF
//   ENDIF
   art->(dbSkip())
ENDDO
cFile := Path("export\art_no_deckung.csv")
SaveAsCSV(cFile,aList)
WAPI_ShellExecute(NIL, "Open", cFile, "", "", 1)
? "done"
Inkey(0,128)