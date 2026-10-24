/*
   this produces a CSV file for all parts with UL -> Used to list our parts with UL
*/
PROCEDURE RUN_Onpow_Parts_UL
   LOCAL aBases := {"CMI","CM","CI"}
   LOCAL nX,cBase,oOptBase
   LOCAL aParts,aOldParts
   LOCAL aList := {}
   LOCAL cPart

   nX := 1
   
   cBase := aBases[nX]
   oOptBase := OptionBase():New()
   oOptBase:Load( cBase )

   aParts := {cBase}
   
   CLS
   ? "Producing list"
   lFirst := .T.
   oOptBase:oTables:Each({|oTable|   
      ? oTable:Funktion   
      IF lFirst
         aParts[1] += "35/"         
         lFirst := .F.
      ELSE
         aOldParts := aParts
         aParts := {}
         IF Upper(Trim(oTable:Funktion)) == "LED-FARBE"
            FOR EACH cPart IN aOldParts
               Aadd(aParts,cPart+"RD/")
            NEXT
         ELSE
            oTable:oKeys:Each({ |oKey|            
               FOR EACH cPart IN aOldParts   
                  Aadd(aParts,cPart+oKey:TabKey)
               NEXT
               RETURN NIL
            })
         ENDIF
      ENDIF
      ?? Len(aParts)
      IF Inkey() == 27
         RETURN .F.
      ENDIF
      RETURN NIL
   })

   IF LastKey() == 27
      RETURN
   ENDIF

   CLS
   cPart := NIL
   FOR EACH cPart IN aParts
      cOnpow := StrTran(StrTran(StrTran(OnpowPartno(cPart,Len(cBase)),"/FP"),"-",""),"/")
      IF HB_RegexMatch("GQ(2[2,5,8]|30|40)(PF)?(11|22)Z?(D|E)?[A-Z]?(6V|12V|24V|110V|250V)?[SA]",cOnpow)
         Aadd(aList,{cPart,cOnpow})
         ? cPart,cOnpow
      ENDIF
      nKey := Inkey() 
      IF nKey == 27
         EXIT
      ELSEIF Upper(Chr(nKey)) == "P"
         Sinkey(0)
      ENDIF
   NEXT
   ? "Total: ",Len(aParts)
   ? "Parts: ",Len(aList)
   Sinkey(0)


   #include 'onpow_part_no.prg'