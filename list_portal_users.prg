#include 'inkey.ch'
//#include 'trader.ch'

/*
   FUNCTION: RUN_ListPortalUsers

   DESCRIPTION:
   Browse and manage portal users with interactive TBrowseTr interface.
   Features: wide columns, inline display, search by typing, optional filtering via F11

   PARAMETERS:
   None

   RETURNS:
   None
*/
PROC RUN_ListPortalUsers
   LOCAL oBrowse, oFilter
   LOCAL cSearch := ""
   LOCAL cCol
   MEMVAR c_six

   NetUse("portalusr", "pusr", .F., 0)
   NetUse("engkund", "ku", .F., 0)
   NetUse("contacts", "conts", .F., 0)

   pusr->(dbSetOrder(1)) // Email order
   ku->(dbSetOrder(8))   // Address number order
   conts->(dbSetOrder(3)) // Email order

   // Initialize filter
   IF oFilter == NIL
      oFilter := InteractiveFilter():New(00, 02, 05)
      oFilter:AddValue("Email", 'email', Space(50), "@S20")
      oFilter:AddValue("Active", 'active', .F.)
      oFilter:AddValue("Email Confirmed", 'emailconf', .F.)
      oFilter:AddValue("Has API Key", 'haskey', .F.)
   ENDIF

   

   // Create browse object - full screen
   oBrowse := pusr->(TBrowseTr():New(00, 00, MaxRow(), MaxCol()))
   oBrowse:ColorSpec := c_six
   oBrowse:Title := "[ PORTAL USERS ]"
   oBrowse:OneColumn := .T.
   
   pusr->(dbGoTop())

   // Exclude internal domains by default
   oBrowse:ForBlock := {|| !("engelking.de" $ Lower(pusr->Email) .OR. "engelking.eu" $ Lower(pusr->Email)) }
   oBrowse:cFor := "!('engelking.de' $ Lower(Email) .OR. 'engelking.eu' $ Lower(Email))"

   

   // ESC to exit
   oBrowse:AddKey(K_ESC, {|| .F. })

   // SPACE to show details inline
   oBrowse:AddKey(K_SPACE, {|| _ShowPortalUserDetails(), .T. }, "Show Details")

   oBrowse:AddKey(K_ENTER, {|| _EditPortalUserDetails(), .T. }, "Konto zuordnen")

   oBrowse:AddKey(K_DEL, {|| _DeletePortalUser(), .T. }, "L”schen")

   // F11 for filter
   oBrowse:AddKey(K_F11, {||
      LOCAL cClauseCol := SetColor(c_five)
      oFilter:Dialog()
      oBrowse:SetFilter(oFilter)
      SetColor(cClauseCol)
      RETURN .T.
   }, "Filter")

   // F10 for CSV export
   oBrowse:AddKey(K_F10, {||
      LOCAL hFields := {=>}
      hFields["Email"] := {|| pusr->Email }
      hFields["Active"] := {|| IF(pusr->Active, "Yes", "No") }
      hFields["Email Confirmed"] := {|| IF(pusr->EmailConf, "Yes", "No") }
      hFields["Customer Name"] := {|| _GetCustomerName() }
      hFields["Supplier Name"] := {|| _GetSupplierName() }
      hFields["Has API Key"] := {|| IF(!Empty(pusr->KeyToken), "Yes", "No") }
      hFields["Has Session Token"] := {|| IF(!Empty(pusr->Token), "Yes", "No") }
      hFields["Last Login"] := {|| IF(Empty(pusr->Timestamp), "Never", DToC(SToD(Left(pusr->Timestamp, 8)))) }
      
      oBrowse:SaveAsCSV(hFields)
      RETURN .T.
   }, "Export to CSV")

   // Define columns - WIDE layout
   oBrowse:NewColumn("Email", {|| 
      RETURN PadR(pusr->Email, 35)
   }, , 1, "@", Space(35), {|x| Lower(x) })

   oBrowse:NewColumn("Kunde", {||
      LOCAL cName := _GetCustomerName()
      RETURN PadR(cName, 25)
   })

   oBrowse:NewColumn("Lieferant", {||
      LOCAL cName := _GetSupplierName()
      RETURN PadR(cName, 25)
   })

   oBrowse:NewColumn("Aktiv", {||
      RETURN Pad(IF(pusr->Active, "Y", "N"), 5)
   })

   oBrowse:NewColumn("Best„tigt", {||
      RETURN Pad(IF(pusr->EmailConf, "Y", "N"), 10)
   })

   oBrowse:NewColumn("API Key", {||
      RETURN Pad(IF(!Empty(pusr->KeyToken), "Y", "N"), 10)
   })

   oBrowse:NewColumn("Login", {||
      LOCAL cLastLogin := IF(Empty(pusr->Timestamp), "Nie", DToC(SToD(Left(pusr->Timestamp, 8))))
      RETURN PadR(cLastLogin, 10)
   })

   oBrowse:NewColumn("", {||      
      IF ! Empty(pusr->JWT_JTI) .AND. StoT(pusr->JWT_EXP) >= Date()
         RETURN Pad("angemeldet",10)
      ENDIF
      RETURN Pad("", 10)
      //RETURN pusr->JWT_EXP 
   })

   // Search by typing functionality - bRestFun
   oBrowse:bRestFun := {||
      LOCAL nKey := LastKey()
      LOCAL cChar := hb_keyChar(nKey)

      // Only capture printable characters
      IF cChar != "" .AND. nKey >= 32 .AND. nKey <= 126
         cSearch += Upper(cChar)
         
         // Search in email field
         pusr->(dbSetOrder(1))
         IF pusr->(dbSeek(cSearch))
            oBrowse:GoTop()
         ELSE
            // Try partial match
            pusr->(dbGoTop())
            DO WHILE !pusr->(EOF())
               IF Upper(Left(pusr->Email, Len(cSearch))) == cSearch
                  EXIT
               ENDIF
               pusr->(dbSkip())
            ENDDO
         ENDIF

      ELSEIF nKey == K_BS .AND. Len(cSearch) > 0
         // Backspace to remove last character
         cSearch := Left(cSearch, Len(cSearch) - 1)
         
         IF Len(cSearch) > 0
            pusr->(dbSetOrder(1))
            IF pusr->(dbSeek(cSearch))
               oBrowse:GoTop()
            ENDIF
         ELSE
            pusr->(dbGoTop())
         ENDIF

      ELSEIF nKey == K_SPACE
         // Space clears search
         cSearch := ""
         pusr->(dbGoTop())
      ENDIF

      RETURN .T.
   }

   // Status bar with instructions
   @ MaxRow(), 0 SAY "Type=Search BS=Clear Space=Reset Del=Delete F11=Filter F10=Export ENTER=Details ESC=Exit"

   oBrowse:goTop()
   oBrowse:EventLoop()

RETURN

/*
   Helper function: Get customer company name from Address
*/
STATIC FUNCTION _GetCustomerName()
   LOCAL cName := ""

   IF pusr->Address != 0
      IF ku->(dbSeek(Str(pusr->Address, 6)))
         cName := AllTrim(ku->Name1)
         IF !Empty(ku->Name2)
            cName += " " + AllTrim(ku->Name2)
         ENDIF
      ENDIF
   ENDIF

RETURN cName

/*
   Helper function: Get supplier company name from Supplier field
*/
STATIC FUNCTION _GetSupplierName()
   LOCAL cName := ""

   IF pusr->Supplier != 0
      IF ku->(dbSeek(Str(pusr->Supplier, 6)))
         cName := AllTrim(ku->Name1)
         IF !Empty(ku->Name2)
            cName += " " + AllTrim(ku->Name2)
         ENDIF
      ENDIF
   ENDIF

RETURN cName

/*
   Helper function: Show detailed user information inline
*/
STATIC FUNCTION _ShowPortalUserDetails()
   LOCAL nRow := 2
   LOCAL cCol
   LOCAL aEnv := SaveEnv()
   MEMVAR c_five

   IF pusr->(EOF())
      RETURN .T.
   ENDIF

   SetColor(c_five)
   @ 1, 0 CLEAR TO 11, MaxCol()
   @ 1, 0 TO 11, MaxCol()

   @ nRow, 2 SAY "Email:" + PadR(pusr->Email, 50)
   nRow++
   @ nRow, 2 SAY "UUID:" + PadR(pusr->UUID, 50)
   nRow++
   @ nRow, 2 SAY "Active:" + PadR(IF(pusr->Active, "Yes", "No"), 10)
   nRow++
   @ nRow, 2 SAY "Email Confirmed:" + PadR(IF(pusr->EmailConf, "Yes", "No"), 10)
   nRow++
   @ nRow, 2 SAY "Address (Customer):" + PadR(Str(pusr->Address, 6), 10)
   nRow++
   @ nRow, 2 SAY "Supplier:" + PadR(Str(pusr->Supplier, 6), 10)
   nRow++
   @ nRow, 2 SAY "Has API Key:" + PadR(IF(!Empty(pusr->KeyToken), "Yes", "No"), 10)
   nRow++
   @ nRow, 2 SAY "Has Session Token:" + PadR(IF(!Empty(pusr->Token), "Yes", "No"), 10)
   nRow++
   @ nRow, 2 SAY "Last Login:" + PadR(IF(Empty(pusr->Timestamp), "Never", pusr->Timestamp), 20)

   Inkey(0, 128)

   RestEnv(aEnv,.T.)

RETURN .T.

/*
   Helper function: Edit portal user details (e.g. assign to customer)   
*/
STATIC FUNCTION _EditPortalUserDetails()
   LOCAL hAddress := {=>}
   LOCAL cGroup   := "K"
   LOCAL nX,aChoice := {},aSelectable := {},nChoice
   LOCAL hPeople := {=>}
   LOCAL lSelectable := .F.
   LOCAL nRec := pusr->(RecNo())
   LOCAL lSuccess


   IF pusr->(EOF())
      RETURN .T.
   ENDIF

   

   IF pusr->Address != 0      
      IF ! pusr->Active
         IF Tr_MsgBox("Zugang aktivieren?",,{"Nein","Ja"}) == 2
            pusr->(Rec_Lock(0))
            pusr->Active := .T.
            pusr->(dbUnlock())         
            __SendActivationEmail()
         ENDIF
         RETURN .T.
      ENDIF
      Tr_MsgBox("Dieser Benutzer ist bereits einem Kunden/Lieferanten zugeordnet. Eine erneute Zuordnung ist nicht m”glich.")
   ELSE      
      NetUse("engkund","ku")
      NetUse("contacts","conts")

      conts->(dbSetOrder( 3 )) //lower(email)
      ku->(dbSetOrder( 8 ))   
      conts->(dbSetRelation("ku",{|| Str(conts->Address,6) },"Str(address,6)"))      
      conts->(dbSeek(Trim(Lower(pusr->Email)))) //
      DO WHILE Trim(Lower(pusr->Email)) == Trim(Lower(conts->Email))      
         IF ku->Group == cGroup 

            IF ! HB_HHasKey(hAddress,conts->Address) 
               hAddress[conts->Address] := { "count"=> 1,"usedAsGeneral"=>.F.,"active"=>conts->Active }
            ELSE
               hAddress[conts->Address]["count"]++
               IF ! conts->Active
                  hAddress[conts->Address]["active"] := .F.
               ENDIF
            ENDIF
               
            IF conts->Anrede == 0  //it is a general contact, not linked to a specific person, we want to ignore this if there is a specific one for the same email
               hAddress[conts->Address]["usedAsGeneral"] := .T.                           
            ENDIF

         ENDIF
         conts->(dbSkip())
      ENDDO   

      IF Len(hAddress) == 0  //Keine Kontakte gefunden, dann erlauben wir die „nderung von bestehenden Benutzern ohne Zuordnung
         conts->(dbSetOrder( 4 )) //domain
         conts->(dbSeek(Trim(Lower(SubStr(pusr->Email, At("@", pusr->Email) + 1)))))
         DO WHILE Trim(Lower(SubStr(pusr->Email, At("@", pusr->Email) + 1))) == Trim(Lower(SubStr(conts->Email, At("@", conts->Email) + 1)))
            IF ku->Group == cGroup
               IF ! pusr->(dbSeek(Trim(Lower(conts->Email)))) //noch kein Portalbenutzer
                  IF ! HB_HHasKey(hPeople,Trim(Lower(conts->Email))) 
                     hPeople[Trim(Lower(conts->Email))] := { "count"=> 1,"usedAsGeneral"=>.F.,"address"=>conts->Address,"active"=>conts->Active }
                  ELSE
                     hPeople[Trim(Lower(conts->Email))]["count"]++
                     IF hPeople[Trim(Lower(conts->Email))]["address"] != conts->Address
                        hPeople[Trim(Lower(conts->Email))]["address"] := 0
                     ENDIF
                     IF ! conts->Active
                        hPeople[Trim(Lower(conts->Email))]["active"] := .F.
                     ENDIF
                  ENDIF
                  IF conts->Anrede == 0  //it is a general contact, not linked to a specific person, we want to ignore this if there is a specific one for the same email
                     hPeople[Trim(Lower(conts->Email))]["usedAsGeneral"] := .T.                           
                  ENDIF                  
               ENDIF
               pusr->(dbGoTo(nRec))
            ENDIF
            conts->(dbSkip())
         ENDDO
      ENDIF
      conts->(dbClearRelation())


      IF Len(hAddress) != 0
         IF Len(hAddress) == 1 
            IF HGetValueAt(hAddress,1)["count"] > 1
               Alert("Es gibt mehrere Kontakte mit der gleichen Email-Adresse. Bitte zuerst die Zuordnung der Kontakte kl„ren, bevor diesem Benutzer ein Kunde/Lieferant zugeordnet werden kann.")
               RETURN .T.            
            ELSEIF ! HGetValueAt(hAddress,1)["active"]
               Tr_MsgBox("Der Kontakt, der diesem Benutzer zugeordnet werden k”nnte, ist inaktiv. Bitte zuerst Kontakt aktivieren.")
               RETURN .T.               
            ELSEIF HGetValueAt(hAddress,1)["usedAsGeneral"]
               Tr_MsgBox("Der Kontakt, der diesem Benutzer zugeordnet werden k”nnte, ist ein allgemeiner Kontakt. Bitte zuerst eine konkrete Person anlegen und diesem Benutzer zuordnen.")
               RETURN .T.
            ENDIF
         ELSE         
            FOR nX := 1 TO Len(hAddress)
               ku->(dbSeek(Str(HGetKeyAt(hAddress,nX),6)))
               Aadd(aChoice, ku->Kunde)
               IF hAddress[HGetKeyAt(hAddress,nX)]["usedAsGeneral"] 
                  aChoice[Len(aChoice)] := ATail(aChoice)+" (als allgemeiner Kontakt verwendet)"
                  Aadd(aSelectable, .F.)         
               ELSEIF hAddress[HGetKeyAt(hAddress,nX)]["count"] != 1            
                  aChoice[Len(aChoice)] := ATail(aChoice)+" (verwendet von "+Str(hAddress[HGetKeyAt(hAddress,nX)]["count"],3)+" Kontakten)"
                  Aadd(aSelectable, .F.)
               ELSE
                  Aadd(aSelectable, .T.)
                  lSelectable := .T.
               ENDIF
            NEXT
            IF Len(aChoice) == 0 .OR. ! lSelectable
               Tr_MsgBox("Keine passenden Kunden/Lieferanten gefunden, die diesem Benutzer zugeordnet werden k”nnten.")
               RETURN .T.
            ENDIF
            @ 09,09 CLEAR TO 21,101
            @ 09,09 TO 21,101
            @ 09,10 SAY "[ Kunde ausw„hlen ]"
            nChoice := AChoice(10,10,20,100,aChoice,aSelectable) 
            IF nChoice == 0 .OR. LastKey() == 27
               RETURN .T.
            ENDIF
            pusr->(Rec_Lock())
            pusr->Address := HGetKeyAt(hAddress,nChoice)
            pusr->Active := .T.
            pusr->(dbUnLock())
            ku->(dbSeek(Str(pusr->Address,6)))
            lSuccess := __SendActivationEmail()
            Tr_MsgBox("Benutzer "+Trim(pusr->Email)+" wurde Kunde "+ku->Kunde+" zugeordnet"+IF(lSuccess, " und der Benutzer wurde ber die Aktivierung informiert.", ""))
         ENDIF
      ELSE
         FOR nX := 1 TO Len(hPeople)
            Aadd(aChoice, HGetKeyAt(hPeople,nX))
            IF hPeople[HGetKeyAt(hPeople,nX)]["usedAsGeneral"] 
               aChoice[Len(aChoice)] := ATail(aChoice)+" (als allgemeiner Kontakt verwendet)"
               Aadd(aSelectable, .F.)         
            ELSEIF hPeople[HGetKeyAt(hPeople,nX)]["count"] != 1            
               aChoice[Len(aChoice)] := ATail(aChoice)+" (verwendet von "+Str(hPeople[HGetKeyAt(hPeople,nX)]["count"],3)+" Kontakten)"
               Aadd(aSelectable, .F.)
            ELSE
               Aadd(aSelectable, .T.)
               lSelectable := .T.
            ENDIF
         NEXT
         IF Len(aChoice) == 0 .OR. ! lSelectable
            Tr_MsgBox("Keine passenden Personen gefunden, die diesem Benutzer zugeordnet werden k”nnten.")
            RETURN .T.
         ENDIF
         @ 09,09 CLEAR TO 21,101
         @ 09,09 TO 21,101
         @ 09,10 SAY "[ Email-Adresse die ersetzt wird ]"
         nChoice := AChoice(10,10,20,100,aChoice,aSelectable)
         IF nChoice == 0 .OR. LastKey() == 27
            RETURN .T.
         ENDIF
         pusr->(dbGoto(nRec))
         pusr->(Rec_Lock())
         pusr->Address := hPeople[HGetKeyAt(hPeople,nChoice)]["address"]
         pusr->Active := .T.
         pusr->(dbUnLock())
         conts->(dbSetOrder(3))
         conts->(dbSeek(Trim(Lower(HGetKeyAt(hPeople,nChoice)))))
         conts->(Rec_Lock(0))
         conts->Email := pusr->Email
         conts->(dbUnLock())
         lSuccess := __SendActivationEmail()
         Tr_MsgBox("Benutzer "+Trim(pusr->Email)+" wurde "+Trim(conts->Name)+" zugeordnet"+IF(lSuccess, " und der Benutzer wurde ber die Aktivierung informiert.", ""))
      ENDIF
   ENDIF
RETURN .T.

/*
   Helper function: Delete selected portal user
*/
STATIC FUNCTION _DeletePortalUser()
   LOCAL lDeleted := .F.

   IF pusr->(EOF())
      RETURN .T.
   ENDIF

   IF Tr_MsgBox("Portalbenutzer " + Trim(pusr->Email) + " wirklich l”schen?",, {"Nein", "Ja"}) != 2
      RETURN .T.
   ENDIF

   IF pusr->(Rec_Lock(0))
      pusr->(dbDelete())
      pusr->(dbUnlock())
      lDeleted := .T.
   ENDIF

   IF lDeleted
      Tr_MsgBox("Portalbenutzer wurde gel”scht.")
      pusr->(dbSkip())
      IF pusr->(EOF())
         pusr->(dbGoBottom())
      ENDIF
   ELSE
      Tr_MsgBox("Portalbenutzer konnte nicht gel”scht werden.")
   ENDIF

RETURN .T.

STATIC FUNCTION __SendActivationEmail()
   LOCAL aTo,cName,cAnrede

   LoadPrg(Path("\www\api\index.prg"))

   conts->(dbSetOrder(3))
   conts->(dbSeek(Trim(Lower(pusr->Email))))   

   ku->(dbSetOrder(8))
   ku->(dbSeek(Str(pusr->Address,6)))

   cName := hb_strToUtf8(Trim(conts->Name))
   cAnrede := hb_strToUtf8(GetContactAnrede(conts->Number))

   aTo := {"email"=>Trim(pusr->Email),"name"=>cName}
   //aTo := {"email"=>"amos.engelking@engelking.de","name"=>cName}
 
   IF ! HB_ExecFromArray({"SendMailTemplate",aTo, IF(ku->Language=="D",21,22),{"anrede"=>cAnrede}})
      Tr_MsgBox("Fehler beim Senden der E-Mail. Bitte manuell informieren.")
      RETURN .F.
   ENDIF
RETURN .T.
