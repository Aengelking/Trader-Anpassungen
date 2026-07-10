#define HB_CALL_FUNC_DIRECT      1

// Thread-local static variables for CRM picker result
THREAD STATIC tcCrmPickerId := ""
THREAD STATIC tcCrmPickerObjectType := ""
THREAD STATIC tlCrmPickerConfirmed := .F.

// Main thread static variables
STATIC gcCrmPickerId := ""
STATIC gcCrmPickerObjectType := ""
STATIC glCrmPickerConfirmed := .F.
STATIC pCrmPickerMutex

PROC RUN_CRM_EMAIL(cMsgPath)
	LOCAL oAccount, cArchive, oArchive, oMsg
	LOCAL cID, cObjectType, nX

	oAccount := DV_GetMailAccount()
	cArchive := SubStr(cMsgPath,1,RAT("\",cMsgPath)-1)
	oArchive := oAccount:GetArchive(cArchive)
	oMsg := oArchive:GetArchiveEntryById(cMsgPath)
	
	Head("Lead/Opportunity auswÑhlen")

	IF oMsg:Type != 2
		Tr_MsgBox("Nur Emails kînnen an das CRM weitergeleitet werden.")
		RETURN
	ENDIF


	@ 01,00,05,20 GET nType LISTBOX {"Lead","Opportunity"} STATE {||
		IF nType == 1
			cObjectType := "Lead"
		ELSEIF nType == 2
			cObjectType := "Opportunity"
		ENDIF
	}

	@ 02,00 SAY "ID" GET cID PICTURE "999999" VALID {||
		IF Empty(cID)
			RETURN .F.
		ENDIF
		RETURN .T.
	}
	READ

	// Validate selected values
	IF Empty(cID) .OR. Empty(cObjectType)
		Tr_MsgBox("UngÅltige Auswahl. Bitte versuchen Sie es erneut.")
		RETURN
	ENDIF
	
	// Forward email to CRM with selected ID and Object Type
	//this is a but cumbersome but otherwise we do not have the MailItem-Interface to call the Forward() method
	FOR nX := 0 TO oArchive:MailItems:Count
		IF oArchive:MailItems:Item(nX):_ID == oMsg:_ID
			BEGIN SEQUENCE
				oMsg := oArchive:MailItems:Item(nX)
				oMsg:Subject := oMsg:Subject + " [#EK-"+IF(nType==1,"L","O")-" + cID + "]"
				oMsg:Save()
				
				oMsg:Recipients:Clear()
				oMsg:Recipients:Add("crm@iokronuere.resend.app")
				oMsg:Forward(1,0)
				
				Tr_MsgBox({"Email erfolgreich an das CRM weitergeleitet." , "ID: " + cID ,"Object Type: " + cObjectType})
			RECOVER
				Tr_MsgBox("Fehler beim Weiterleiten der E-Mail aus dem CRM.")
			END
			EXIT
		ENDIF
	NEXT

RETURN

