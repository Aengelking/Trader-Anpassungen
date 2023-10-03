#include 'inkey.ch'

PROC RUN_REPORTS_FIND_PERSON
LOCAL getlist := {}
LOCAL cName := Space(50)
LOCAL oBrowse,bFilter,cGroups

IF ! SystemUser():CheckPermission("R","ADR")
   RETURN
ENDIF

DO WHILE .T.
   Head("Adresse zu Person finden")

   NetUse("contacts","conts",.F.,0)
   NetUse("engkund","ku",.F.,0)
   
   cGroups := ""
   IF SystemUser():HasPermission("R","ADR_CUSTOMER")
      cGroups += "K"   
   ENDIF
   IF SystemUser():HasPermission("R","ADR_SUPPLIER")
      cGroups += "L"   
   ENDIF
   IF SystemUser():HasPermission("R","ADR_OTHER")
      cGroups += "S"   
   ENDIF

   IF Len(cGroups) == 0
      Tr_MsgBox("Berrechtigung fehlt")
      RETURN
   ENDIF

   @ 01,00 SAY "Name enth„lt" GET cName
   READ

   If LastKey() == 27 
      Return
   Endif

  
   bFilter := {|| ku->(dbSeek(Str(conts->Address,6))), ku->group $ cGroups .AND. At(Trim(Upper(cName)),Upper(conts->Name)) != 0 .AND. conts->Active}

   ku->(dbSetOrder( 8 ))

   conts->(dbSetOrder( 3 ))  //lower(email)
   conts->(dbGoTop())
   ku->(dbSetORder(8))
   conts->(__dbLocate(bFilter)) //At(cName,Upper(conts->Name)) != 0
   
   IF conts->(EOF())
      Tr_MsgBox("Keine Person gefunden")
      LOOP
   ENDIF
   
  
   oBrowse := TBrowseTr():New(02,00,10,MaxCol())
   oBrowse:OneColumn := .T.
   oBrowse:NewColumn("Adresse",{|| Str(conts->Address,6) })
   oBrowse:NewColumn("Matchcode",{|| ku->(dbSeek(Str(conts->Address,6))), ku->Kunde })
   oBrowse:NewColumn("Gruppe",{|| ku->Group })
   oBrowse:NewColumn("Firma",{|| Pad(Trim(ku->Name1)+" "+ku->Name2,35) })
   oBrowse:NewColumn("Name",{|| conts->Name })
   oBrowse:NewColumn("Email",{|| conts->Email })
   //oBrowse:cFor := cFilter
   oBrowse:forBlock := bFilter
   oBrowse:AddKey(K_ESC,{|| .F. })
   oBrowse:AddKey(K_F9,{|| 
      LOCAL aEnv := SaveEnv()
      ku->(dbSeek(Str(conts->Address,6)))
      EnAddr()
      RestEnv(aEnv)
      RETURN .T.
   })
   oBrowse:bRestFun := {||
      LOCAL cEmail
      __KeyBoard(Chr(LastKey()))
      cEmail := GetBox(Space(35),"Email")
      IF LastKey() != K_ESC .AND. ! Empty(cEmail)
         conts->(dbSeek( cEmail, .T. ))
      ENDIF
      RETURN .T.
   }
   oBrowse:EventLoop()
ENDDO
/*SetPos(02,00)

Do While conts->(Found())

	? conts->Address
	ku->(dbSeek( Str(conts->Address,6) ))
	?? "",ku->Kunde,ku->Name1,Pad(conts->Name,30)
	dbSelectArea("conts")
	CONTINUE
Enddo

? "Suche beendet."
SInkey(0)*/
