#include 'inkey.ch'

PROC RUN_REPORTS_FIND_PERSON
LOCAL getlist := {}
LOCAL cName := Space(50)
LOCAL cEmail := Space(255)
LOCAL cDomain := Space(255)
LOCAL oBrowse,bFilter,bWhile,cGroups

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

   @ 01,00 SAY "Name enth„lt" GET cName WHEN Empty(cEmail) .AND. Empty(cDomain)
   @ 02,00 SAY "Email       " GET cEmail WHEN Empty(cName) .AND. Empty(cDomain)
   @ 03,00 SAY "Domain      " GET cDomain WHEN Empty(cName) .AND. Empty(cEmail)
   READ

   If LastKey() == 27 
      Return
   Endif


   IF Empty(cName) .AND. Empty(cEmail) .AND. Empty(cDomain)
      Tr_MsgBox("Bitte Name oder Email angeben")
      LOOP
   ENDIF
  
   bFilter := {|| 
      ku->(dbSeek(Str(conts->Address,6)))
      IF ! ku->group $ cGroups
         RETURN .F.
      ENDIF
      IF ! Empty(cName) .AND. At(Trim(Upper(cName)),Upper(conts->Name)) == 0
         RETURN .F. 
      ENDIF
      RETURN conts->Active
   }

   ku->(dbSetOrder( 8 ))


   IF ! Empty(cDomain)
      conts->(dbSetOrder( 4 )) //domain
      bWhile := {|| Trim(cDomain) == Trim(SubStr(conts->Email,At("@",conts->Email)+1)) }
      IF ! conts->(dbSeek( cDomain ))
         Tr_MsgBox("Keine Person mit dieser Domain gefunden")
         LOOP
      ENDIF
      ku->(dbSeek(Str(conts->Address,6)))
   ELSEIF ! Empty(cEmail)
      conts->(dbSetOrder( 3 ))  //lower(email)
      bWhile := {||  Lower(Trim(cEmail)) == Trim(Lower(conts->Email)) }
      IF ! conts->(dbSeek( Lower(cEmail) ))
      //IF conts->(EOF()) .OR. Lower(Trim(conts->Email)) != Trim(Lower(cEmail))
         Tr_MsgBox("Keine Person mit dieser Email gefunden")
         LOOP
      ENDIF
      ku->(dbSeek(Str(conts->Address,6)))
   ELSE
      conts->(dbSetOrder( 3 )) 
      bWhile := {|| .T. }
      conts->(dbGoTop())
   ENDIF
   
   ku->(dbSetORder(8))
   TxtBox("Suche...")
   conts->(__dbLocate(bFilter,bWhile)) //At(cName,Upper(conts->Name)) != 0
   TxtClear()
   IF conts->(EOF())
      Tr_MsgBox("Keine Person gefunden")
      LOOP
   ENDIF

   oBrowse := conts->(TBrowseTr():New(04,00,MaxRow(),MaxCol()))
   oBrowse:OneColumn := .T.
   oBrowse:NewColumn("Adresse",{|| Str(conts->Address,6) })
   oBrowse:NewColumn("Matchcode",{|| ku->(dbSeek(Str(conts->Address,6))), ku->Kunde })
   oBrowse:NewColumn("Gruppe",{|| ku->Group })
   oBrowse:NewColumn("Firma",{|| Pad(Trim(ku->Name1)+" "+ku->Name2,35) })
   oBrowse:NewColumn("Name",{|| conts->Name })
   oBrowse:NewColumn("Email",{|| conts->Email })
   //oBrowse:cFor := cFilter
   oBrowse:forBlock := bFilter
   
   oBrowse:WhileBlock := bWhile
   
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
