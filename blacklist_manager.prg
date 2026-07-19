//
// Blacklist maintenance screen (add / remove / list entries).
//
// Standalone runnable: hook it into the menu by procedure name, like the
// other RUN_* scripts. All blacklist logic lives in the shared blacklist.prg.
//

#include 'inkey.ch'

STATIC s_hBlackEmail
STATIC s_hBlackDomain

PROCEDURE RUN_Mailing_Blacklist
   LOCAL oBrowse

   Head("Mailing Blacklist")

   IF ! OpenBlacklist()
      Tr_MsgBox("Blacklist-Tabelle (mailblack) nicht gefunden")
      RETURN
   ENDIF

   @ 00,00 SAY "Mailing Blacklist   INS=Hinzufuegen  DEL=Loeschen  ESC=Zurueck"

   oBrowse := TABrowse():New(02,00,MaxRow()-1,MaxCol())
   __BlacklistLoadRows(oBrowse)

   oBrowse:NewColumn(" "+Pad("Gilt fuer",11)+" "+Pad("Typ",6)+" "+Pad("Eintrag",40)+" "+"Grund",{||
      LOCAL aRow := oBrowse:CurrentDataRow()
      IF aRow == NIL   // empty list: nothing to render on the current row
         RETURN ""
      ENDIF
      RETURN " "+Pad(BlacklistScopeText(aRow[5]),11)+" "+Pad(IF(aRow[2]=="D","Domain","Email"),6)+" "+Pad(aRow[1],40)+" "+Pad(aRow[3],18)
   })

   oBrowse:AddKey(K_ESC,{|| .F. })
   oBrowse:AddKey(K_INS,{||
      LOCAL nT, cV, cR, cS
      nT := Tr_MsgBox("Art des Eintrags",,{"Abbrechen","Email","Domain"})
      IF nT $ {2,3}
         cV := Trim(GetBox(Space(80),"Email bzw. Domain","@S80"))
         IF LastKey() != K_ESC .AND. ! Empty(cV)
            cR := Trim(GetBox(Space(60),"Grund (optional)","@S60"))
            IF LastKey() != K_ESC
               cS := AskBlacklistScope(cV)
               IF ! Empty(cS)
                  AddToBlacklist(cV,IF(nT==3,"D","E"),cR,cS)
                  __BlacklistLoadRows(oBrowse)
                  oBrowse:GoTop()
                  oBrowse:Refresh := .T.
                  oBrowse:RefreshAll()
               ENDIF
            ENDIF
         ENDIF
      ENDIF
      RETURN .T.
   })
   oBrowse:AddKey(K_DEL,{||
      LOCAL aRow := oBrowse:CurrentDataRow()
      IF aRow != NIL .AND. ! Empty(aRow[1]) .AND. ;
         Tr_MsgBox("Eintrag loeschen?",aRow[1],{"Nein","Ja"}) == 2
         DeleteFromBlacklist(aRow[1],aRow[2])
         __BlacklistLoadRows(oBrowse)
         oBrowse:GoTop()
         oBrowse:Refresh := .T.
         oBrowse:RefreshAll()
      ENDIF
      RETURN .T.
   })

   @ MaxRow(),00 SAY "INS=Hinzufuegen  DEL=Loeschen  ESC=Zurueck"

   IF Len(oBrowse:aData) == 0
      @ 04,03 SAY "(Blacklist ist leer - mit INS einen Eintrag hinzufuegen)"
   ENDIF

   // Always enter the loop so INS works even on an empty list
   oBrowse:EventLoop()

RETURN

STATIC FUNCTION __BlacklistLoadRows(oBrowse)
   oBrowse:aData := {}
   IF OpenBlacklist()
      mblack->(dbGoTop())
      DO WHILE ! mblack->(Eof())
         IF ! mblack->(Deleted())
            Aadd(oBrowse:aData,{Trim(mblack->Entry),Trim(mblack->Type),Trim(mblack->Reason),mblack->AddedAt,BlacklistRecScope()})
         ENDIF
         mblack->(dbSkip())
      ENDDO
   ENDIF
   s_hBlackEmail := NIL   // keep the lookup cache fresh
RETURN NIL


#include 'x:\run\blacklist.prg'
