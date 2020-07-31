//#define DvArchiveRoot	 	0
//#define DvArchivePersonalIn	101
//#include "hbdyn.ch"

#include "y:\harbour\trader\source\include\david.ch"
#include "y:\hb32\include\dll.ch"


MEMVAR mnhDll

LOCAL oAccount := DV_GetMailAccount()
LOCAL oArchive  := oAccount:GetSpecialArchive(DvArchivePersonalIn)

mnhDLL := DllLoad("c:\windows\dvapi32.dll")

_Recurse(oAccount,oArchive)

STATIC FUNCTION _Recurse(oAccount,oArchive)
   LOCAL oItems := oArchive:AllItems
   LOCAL nX,oItem
   LOCAL cFile,cEnd

   LOCAL cDir := "\\EK-SERVER4\data\Dokumente und Einstellungen\amos\Eigene Dateien\TestArchive\"

   FOR nX := 0 To Min(oItems:Count-1,5)
	   oItem := oItems:Item(nX)

      //Create File Name

	   IF oItem:Type == DvFaxItem
		   cFile := oItem:Fields:Item("SRFrom"):Value
         cEnd := "fax"
	   ELSEIF oItem:Type == DvEMailItem
         cFile := oItem:From:Email+"_"+oItem:Subject
		   cEnd := "eml"
		ENDIF
		cFile += "_"+TtoS(oItem:Fields:Item("StatusTime"):Value)

      cChars := "\*/"
      cFile := CharRepl(cChars,cFile,Replicate("_",Len(cChars)))
      cChars := ':?-"<>|-'
      cFile := CharRepl(cChars,cFile,Space(Len(cChars)))

      cFile += "."+cEnd

      ? cFile
	NEXT

   IF oItem:Type == DvFaxItem
	ELSEIF oItem:Type == DvEMailItem
	  cFN := Space(260)
//	  DllCall(mnhDLL,DLL_OSAPI,"DVMailItemFromEml","Y:\Dokumente und Einstellungen\amos\Eigene Dateien\AUTO_OC\test.eml", oAccount);
	  DllCall(mnhDLL,DLL_OSAPI,"DVEmlFromMailItem",{=>},@cFN)
	  Alert(cFN)
	  //Alert(ValType(oItem))
//	  hb_DynCall( { "DVEmlFromMailItem", mnHDll, hb_bitor(HB_DYN_CALLCONV_SYSCALL,HB_DYN_CTYPE_STRUCTURE) },  )

      /*oConverter = oAccount:CreateExporter()
      oCollection = oConverter:GetCollection()
      oCollection:Add(oItem)
      oConverter:Convert(5,  cDir+cFile ) *///5=FormatEML
   ENDIF

   Inkey(0,128)

   //DllUnload(nDll)



/*
         Set oConverter = oInfoCenter.Account.CreateExporter
         Set oCollection = oConverter.GetCollection
         oCollection.Add oItem2
         oConverter.Convert FormatEML,  temp & "\" & fname
*/
