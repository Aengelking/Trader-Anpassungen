LOCAL nX,cPart
NetUse("artikel","art")
NetUse("artlief","ali")
ali->(dbSetOrder( 1 ))

CLS

FOR EACH cPart IN {"CM","CI"}
   art->(dbSeek( cPart,.T. ))
   
   DO WHILE AT(cPart,art->Matchcode) == 1
      IF ali->(dbSeek(Pad("ONPOW",8)+Str(art->Artikelnr,6)))
   
         cOnpow := OnpowPartno()
   
         IF ! Empty(cOnPow) .AND. Trim(ali->Artlief) != cOnpow
            nChoice := Tr_MsgBox({"Artikel: "+art->Matchcode,"Aktuell: "+ali->Artlief,"Neu:     "+cOnpow},,{"ignorieren","ersetzen","abbrechen"})
            IF nChoice == 2
               ali->(Rec_Lock())
               ali->Artlief := cOnPow
               ali->(dbUnLock())
            ELSEIF nChoice == 3
               RETURN
            ENDIF
         ENDIF
      ENDIF
      art->(dbSkip())
   ENDDO
NEXT

#include 'onpow_part_no.prg'