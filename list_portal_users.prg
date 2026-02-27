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

   // ENTER to show details inline
   oBrowse:AddKey(K_ENTER, {|| _ShowPortalUserDetails(), .T. }, "Show Details")

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
   @ MaxRow(), 0 SAY "Type=Search BS=Clear Space=Reset F11=Filter F10=Export ENTER=Details ESC=Exit"

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
   MEMVAR c_five

   IF pusr->(EOF())
      RETURN .T.
   ENDIF

   cCol := SetColor(c_five)

   @ 1, 0 CLEAR TO 10, MaxCol()
   @ 1, 0 TO 10, MaxCol()

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

   SetColor(cCol)

RETURN .T.
