#include "y:\harbour\trader\source\include\david.ch"
#include "Y:\hb32\include\hbgtinfo.ch"
PARAMETERS cSearchIn

LOCAL oDB
LOCAL cErrorClass, cErrorMsg, nType
LOCAL oAccount
LOCAL hResults := {=>},aMessages
LOCAL hSettings
LOCAL cSearchItms := ""
LOCAL aSearchFields
LOCAL lFound := .F.
LOCAL lDummy,cErrorList

LOCAL cSaveFile := GetEnv("TEMP")+"\david_search.txt"



IF File(cSaveFile)
   hSettings := HB_DeSerialize(MemoRead(cSaveFile))
ENDIF

IF ValType(hSettings) != "H"
   hSettings := {=>}
   hSettings:cSearchTerm := Space(250)
   hSettings:lTo := .T.
   hSettings:lFrom := .T.
   hSettings:lSubject := .T.
   hSettings:lText := .F.
ENDIF


//CreateMainWindow()
//IF Tr_getini(28) != 9
   hb_gtInfo( HB_GTI_WINTITLE, "Suche im David Archiv")
   SetMode(04,39)
   hb_gtInfo( HB_GTI_SCREENHEIGHT, 70 )
   //hb_gtInfo( HB_GTI_SCREENWIDTH, 390  )
//ENDIF


DO WHILE .T.
   SetColor(c_one)
   CLS

   @ 00,00 SAY "Suchtext" GET hSettings:cSearchTerm PICTURE "@S30"
   @ 01,00 GET hSettings:lTo CHECKBOX CAPTION "An"
   @ 01,08 GET hSettings:lFrom CHECKBOX CAPTION "Von"
   @ 01,17 GET hSettings:lSubject CHECKBOX CAPTION "Betreff"
   @ 01,30 GET hSettings:lText CHECKBOX CAPTION "Text"
   @ 03,00 GET lDummy PUSHBUTTON CAPTION "Suchen" STATE {||  ReadKill(.T.) }
   @ 03,10 GET lDummy PUSHBUTTON CAPTION "Abbrechen" STATE {|| hSettings:cSearchTerm := "", ReadKill(.T.)  }
   READ

   IF LastKey() == 27 .OR. Empty(hSettings:cSearchTerm)
      RETURN
   ENDIF

   aSearchFields := {}
   IF hSettings:lTo
      Aadd(aSearchFields,"TO")
   ENDIF
   IF hSettings:lFrom
      Aadd(aSearchFields,"FROM")
   ENDIF
   IF hSettings:lSubject
      Aadd(aSearchFields,"SUBJECT")
   ENDIF
   IF hSettings:lText
      Aadd(aSearchFields,"BODY")
   ENDIF

   oAccount := DV_GetMailAccount()
   cResultPath := DV_GetSearchPath() //oAccount:GetSpecialArchive(DvArchivePersonal):Id+"\system\found"
   oSearch  := oAccount:ArchiveFromID(cResultPath)

   IF Empty(cSearchIn)
      cSearchIn := oAccount:GetSpecialArchive(DvArchivePersonal):Id
   ENDIF

   IF Upper(Trim(cSearchIn)) == Upper(Trim(oSearch:ID))
      cSearchIn := hSettings:cSearchIn
   ENDIF
   
   IF Tr_getini(28) == 9
      ? cSearchIN
      //Inkey(0,128)
   ENDIF

   IF ! DV_Search(cSearchIn,hSettings:cSearchTerm,aSearchFields,5000,02,00,@cErrorList)
      SetColor(c_five)
      CLS
      @ 01,(MaxCol()-23)/2 SAY t("Keine Einträge gefunden")
      @ 03,(MaxCol()-4)/2 SAY "<OK>" COLOR HB_ColorIndex(SetColor(),1)
      IF Inkey(0,128) != 27
         LOOP
      ENDIF
   ENDIF
   EXIT
ENDDO

IF ! Empty(cErrorList) .AND. Tr_Getini(28) == 9
   SetMode(24,80)
//   hb_gtInfo( HB_GTI_SCREENHEIGHT, 300 )

   MemoEdit(cErrorList)

ENDIF


hSettings:cSearchIn := cSearchIn
MemoWrit(cSaveFile,HB_Serialize(hSettings))

