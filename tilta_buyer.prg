/*****************************************************************************
 *  tilta_buyer.prg  -  RUN_TILTA_BUYER
 *
 *  Kunde bei Tilta einrichten: Buyer, Ansprechpartner, Kreditfazilitaet.
 *  Die Arbeit macht run\tilta_setup.prg - hier steht nur die Oberflaeche, damit
 *  Hook und Menuepunkt dieselbe Logik benutzen.
 *
 *  Normalerweise passiert das automatisch, sobald ein Kunde auf Factoring
 *  gestellt wird (Hook after_save_address). Dieser Menuepunkt ist fuer den Fall,
 *  dass jemand es von Hand anstossen oder den Stand nachsehen will.
 *****************************************************************************/

PROCEDURE Run_Tilta_Buyer()

LOCAL cKunde := Space(8)
LOCAL getList := {}
LOCAL oExtra
LOCAL hRes
LOCAL aMsg := {}
LOCAL nX

   NetUse("engkund","ku",.F.,0)

   Head("Kunde bei Tilta einrichten")

   /*  Kunde waehlen  */
   DO WHILE .T.
      @ 01,00 SAY "Kunde" GET cKunde PICTURE "@!"
      READ
      IF LastKey() == 27
         RETURN
      ENDIF
      @ 01,14 CLEAR TO 01,MaxCol()
      ku->(dbSetOrder( 1 ))
      IF ! ku->(dbSeek( Pad(cKunde,8)+"K" ))
         @ 01,14 SAY "NICHT GEFUNDEN"
      ELSE
         @ 01,14 SAY Trim(ku->Name1)+" "+Trim(ku->Name2)
         EXIT
      ENDIF
   ENDDO

   oExtra := ku->(ExtraData():New(ku->Nummer))
   IF ! oExtra:Factoring
      IF Tr_MsgBox({"Dieser Kunde ist im Trader nicht auf Factoring gestellt.", ;
                    "Trotzdem bei Tilta einrichten?"},,{"Nein","Ja"}) != 2
         RETURN
      ENDIF
   ENDIF

   IF Tr_MsgBox({Trim(ku->Name1)+" "+Trim(ku->Name2), ;
                 Trim(ku->PLZ)+" "+Trim(ku->Town)+", "+Trim(ku->CountryIso), ;
                 "als Buyer "+LTrim(Str(ku->Nummer))+" bei Tilta einrichten?", ;
                 "Vorhandenes wird nicht geaendert."},,{"Nein","Ja"}) != 2
      RETURN
   ENDIF

   hRes := MBaseRun(Path("run\tilta_setup.prg"),{ku->Nummer})

   IF ValType(hRes) != "H" .OR. ! HHasKey(hRes,"log")
      Tr_MsgBox("Das Setup hat kein Ergebnis geliefert.","FEHLER")
      RETURN
   ENDIF

   FOR nX := 1 TO Len(hRes["log"])
      Aadd(aMsg,hRes["log"][nX])
   NEXT
   Tr_MsgBox(aMsg,IF(hRes["ok"],"OK","NICHT VOLLSTAENDIG"))

RETURN
