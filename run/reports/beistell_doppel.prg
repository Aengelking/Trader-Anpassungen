PROC RUN_REPORTS_BEISTELL
   LOCAL getlist := {}
   LOCAL cLief   := Space(8)
   LOCAL cFilter
   LOCAL hParts := {=>},nX,nY
   LOCAL aList := {},cFile

   Head("Artikel mit Mehrfachverwendung als Beistellmaterial")

   NetUse("artikel","art")
   NetUse("engkund","ku")
   NetUse("artlief","ali")
   NetUse("parts","part")

   @ 01,00 SAY "Lieferant" GET cLief PICTURE "@!" VALID FindAd(cLief,"L",01,40)
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   CLS

   cFilter := "bezug >= 5 .AND. ! obsolete"

   art->(dbSetFilter( {|| art->(&(cFilter))},cFilter ))
   art->(dbGoTop())

   DO WHILE ! art->(EOF())
      IF (ali->(dbSeek( cLief+Str(art->Artikelnr,6))) .OR. (part->(dbSeek( Str(art->Artikelnr,6)+Str(-1,4) )) .AND.  ali->(dbSeek( cLief+Str(part->Partart,6))))) .AND. ali->Priority <= 8  //if cLief is a supplier of this part
         ? art->Matchcode
         part->(dbSeek( Str(art->Artikelnr,6) ))
         DO WHILE part->ListArt == art->Artikelnr
            IF part->Pos > 0 .AND. part->Qty+part->AddQty > 0
               IF ! part->Partart $ hParts
                  hParts[part->Partart] := {}
               ENDIF
               IF ! art->Artikelnr $ hParts[part->Partart]
                  Aadd(hParts[part->Partart],art->Artikelnr)
               ENDIF   
            ENDIF
            part->(dbSkip())
         ENDDO
      ENDIF
      art->(dbSkip())
      IF Inkey() == 27
         EXIT
      ENDIF
   ENDDO

   art->(dbClearFilter())

   Aadd(aList,{"Artikel","Verwendet in"})

   art->(dbSetOrder( 2 ))
   FOR nX := 1 TO Len(hParts)
      IF Len(HGetValueAt(hParts,nX)) > 1
         art->(dbSeek( Str(HGetKeyAt(hParts,nX),6) ))
         ? HGetKeyAt(hParts,nX),art->Matchcode,Len(HGetValueAt(hParts,nX))
         Aadd(aList,{art->Matchcode})
         FOR nY := 1 TO Len(HGetValueAt(hParts,nX))
            art->(dbSeek( Str(HGetValueAt(hParts,nX)[nY],6) ))
            Aadd(ATail(aList),art->Matchcode)
         NEXT
      ENDIF
   NEXT   
   
   SaveToOO(,{"Artikel"=>aList},,"xlsx",.T.)
   //SaveToOO_Interface({"Artikel"=>aList},,"xlsx",.T.)

RETURN

#include 'x:\run\savetooo.prg'