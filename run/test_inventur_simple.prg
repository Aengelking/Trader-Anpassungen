PROC RUN_TEST_INVENTUR_SIMPLE 

   NetUse("count","cnt")
   NetUse("lagerort","lago")
   NetUse("lager","lag")

   lag->(dbSetOrder(2))
   lago->(dbSetOrder(2))

   SimpleCount(1653,.F.)
RETURN

   FUNCTION SimpleCount(nNr,lNew)
      LOCAL nRec := lago->(Recno())
      LOCAL hList := {=>}

      lago->(dbSeek(Str(nNr,6)))
      DO WHILE lago->Invnr == nNr .AND. ! lago->(EOF())
         IF ! lago->Lagerort $ hList
            hList[lago->Lagerort] := {}
         ENDIF
         //collect the items to be counted
         lag->(dbSeek( lago->Lagerort ))
         DO WHILE lag->Lagerort == lago->Lagerort .AND. ! lag->(EOF())
            IF ! lag->Artikelnr $ hList[lago->Lagerort]
               IF  lag->Taken 
                  Aadd(hList[lago->Lagerort],lag->Artikelnr)
                  IF cnt->(dbSeek( Str(nNr,6)+lago->Lagerort+Str(lag->Artikelnr,6) ))
                     IF lNew //if we are creating a new list we delete any records created through this loop
                        ? "l”schen",lag->Artikelnr,cnt->Menge1
                        cnt->(Rec_Lock(0))
                        //cnt->(dbDelete())
                        cnt->(dbUnLock())
                     ELSE  //we are not building a new list, in this case this part must have been counted already
                        HB_ADel(hList[lago->Lagerort],Len(hList[lago->Lagerort]),.T.)
                     ENDIF
                  ENDIF
               ELSEIF ! lag->Taken
                  ? lag->Artikelnr,lag->Lagermenge
                  IF lNew //if this is the first run of the, then we add the counting to the DB as if it has been counted
                     /*IF ! cnt->(dbSeek( Str(nNr,6)+lago->Lagerort+Str(lag->Artikelnr,6) ))
                        cnt->(Add_Rec(0))
                        cnt->InvNr := nNr
                        cnt->Lagerort := lago->Lagerort
                        cnt->Artikelnr := art->Artikelnr
                        cnt->Person1 := Tr_getini(28)
                        cnt->Menge1 := lag->Lagermenge
                        cnt->(dbUnLock())
                     ELSE
                        cnt->(Rec_Lock())
                        cnt->Menge1 += lag->LagerMenge
                        cnt->(dbUnLock())
                     ENDIF
                     */
                  ENDIF
               ENDIF
            ENDIF
            lag->(dbSkip())
         ENDDO
         lago->(dbSkip())
      ENDDO
      ? ValToPRg(hList)
      SInkey(0)

      lago->(dbGoto(nRec))
   RETURN hList
