
PROC RUN_UPD_SHIPTIME
   LOCAL cLiefma := Space(8)
LOCAL nShipTime := 0,nOldShiptime := 1
LOCAL getList := {}

NetUse("engbes","bes")
NetUse("engkund","ku")

Head("Laufzeiten in Bestellungen aktualisieren")
@ 01,00 SAY "Lieferant    " GET cLiefma PICTURE "@!" VALID ku->(CHECK(cLiefma+"L","ku->Name1",01,23,1))
@ 02,00 SAY "Alte Laufzeit" GET nOldShiptime PICTURE "999"
@ 03,00 SAY "Neue Laufzeit" GET nShipTime PICTURE "999"
READ

IF LastKey() == 27
   RETURN
ENDIF

bes->(dbSetOrder( 2 ))
bes->(dbSeek( cLiefma+Str(0,3), .T. ))

DO WHILE bes->Liefma == cLiefma .AND. bes->BeStat < 3 .AND. ! bes->(EOF())

   IF bes->ShipTime == nOldShiptime
      bes->(Rec_Lock())
      bes->Shiptime := nShiptime
      bes->(dbUnLock())
   ENDIF

   bes->(dbSkip())
ENDDO