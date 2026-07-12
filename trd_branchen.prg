#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
;
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)

#include 'inkey.ch'

PROC TRD_BRANCHEN
   LOCAL oBrowse

   MEMVAR c_five
   SetColor(c_five)

   @ 10,10 CLEAR TO MaxRow()-1,180
   @ 10,10 TO MaxRow()-1,180
   @ 11,100 TO  MaxRow()-2,100
   
   NetUse("engkund","ku")
   NetUse("kuinfo","kuinfo")  

   ku->(dbSetOrder( 7 ))
   ku->(dbSeek( br->Branch ))

   oBrowse := ku->(TBrowseTr():New(11,11,MaxRow()-2,99))
   oBrowse:lBox := .F.
   oBrowse:OneColumn := .T.

   oBrowse:NewColumn("Matchcode", {||  ku->Kunde } )
   oBrowse:NewColumn("Name", {||  Trim(Trim(ku->Name1)+" "+ku->Name2) } )

   oBrowse:WhileBlock := {|| ku->Branch == br->Branch }

   oBrowse:AddKey(27,{|| .F. })
   oBrowse:AddKey(K_CTRL_ENTER,{|| EditBRanche() })
   oBrowse:AddKey(K_ENTER,{|| AIUpdate() })

   oBrowse:bAnyFun :={|| 
         LOCAL nX
         @ 11,101 CLEAR TO MaxRow()-2,179
         IF kuinfo->(dbSeek( Str(ku->Nummer) ) )
            FOR nX := 1 TO MlCount(kuinfo->Info,78)
               @ 11+nX-1,101 SAY MemoLine(kuinfo->Info,78,nX)
               IF 11+nX == MaxRow()-2
                  EXIT
               ENDIF
            NEXT
         ENDIF
      RETURN .T.
    }

   oBrowse:EventLoop()

STATIC FUNCTION EditBranche()
   LOCAL getlist := {}
   MEMVAR c_four
   LOCAL aEnv := SaveEnv()
   LOCAL hBranchen
   LOCAL cBranch := ku->Branch
   LOCAL nNextRec
   LOCAL nRec := ku->(Recno())

   IF ku->(EOF())
      RETURN .T.
   ENDIF

   ku->(dbSkip())
   IF ku->Branch == cBranch
      nNextRec := ku->(Recno())
   ELSE
      ku->(dbGoto(nRec))
      ku->(dbSkip(-1))
      nNextRec := ku->(Recno())
   ENDIF
   ku->(dbGoto(nRec))


   hBranchen := GetBranchen("DE")

   SetColor(c_four)

   @ 10,10 CLEAR TO 20,101
   @ 10,10 TO 20,101
   @ 10,11 SAY "[ Branche „ndern ]"
   @ 11,11 SAY "Branche" 
   @ 11,20,20,100 GET cBranch LISTBOX hBranchen ASSOCIATIVE
   READ

   IF LastKey() == 27 .OR. cBranch == ku->Branch
      RestEnv(aEnv)
      RETURN .T.
   ENDIF
   ku->(Rec_Lock())
   ku->Branch := cBranch
   ku->(dbUnLock())

   RestEnv(aEnv)
   ku->(dbGoto(nNextRec))
RETURN .T.

STATIC FUNCTION AIUpdate()
   LOCAL aEnv := SaveEnv()
   LOCAL nRec := ku->(Recno()),nNextRec

   //check if we are at the end of the file
   IF ku->(EOF()) .OR. ku->Branch != br->Branch
      RETURN .T.
   ENDIF

   //find the next record, before we update the current one
   ku->(dbSkip())
   IF ku->Branch == br->Branch
      nNextRec := ku->(Recno())
   ELSE
      ku->(dbGoto(nRec))
      ku->(dbSkip(-1))
      nNextRec := ku->(Recno())
   ENDIF
   ku->(dbGoto(nRec))

   //get the branch name and description from the AI
   IF Tr_MsgBox("Branche automatisch aktualisieren?",,{"Ja","Nein"}) == 1
      CLS
      IF UpdateBrancheWithAI()
         ? Replicate(Chr(196),100)
         ? "Neue Branche: ",ku->Branch,br->Name
         ? "Beschreibung:"
         ? kuinfo->Info
         oExtra := ku->(ExtraData():New(ku->Nummer))
         ? "Website: ",oExtra:Website
      ELSE
         ? Replicate(Chr(196),100)
         ? "Aktualisierung fehlgeschlagen"
      ENDIF
      Sinkey(0)
   ENDIF

   //clean up
   RestEnv(aEnv)
   IF ku->Branch != br->Branch
      ku->(dbGoto(nNextRec))
   ENDIF
RETURN .T.

#include 'x:\run\update_branch_ai.prg'
   
   