netUse("folgeart","fol")
NetUse("artikel","art")

art->(dbSetOrder( 2 ))

//delete all record which refer to a non existent product
/*DO WHILE ! fol->(EOF())
   IF ! art->(dbSeek( Str(fol->Artikelnr,6) ))
      fol->(Rec_Lock())
      fol->(dbDelete())
      fol->(dbUnLock())
      ? fol->Artikelnr
   ENDIF
   fol->(dbSkip())
ENDDO*/

DO WHILE ! fol->(EOF())
   IF art->(dbSeek( Str(fol->Artikelnr,6) )) .AND. art->Lagerart
/*      fol->(Rec_Lock())
      fol->(dbDelete())
      fol->(dbUnLock())*/
      art->(dbSeek( Str(fol->Folgeart,6) ))
      IF At("MUTTER",art->Matchcode) == 0 .AND. At("DI.",art->Matchcode) == 0
         ? art->Matchcode,""
         art->(dbSeek( Str(fol->Artikelnr,6) ))
         ?? fol->Artikelnr,art->Matchcode
      ENDIF
   ENDIF
   fol->(dbSkip())
ENDDO


SInkey(0)