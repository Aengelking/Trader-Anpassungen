//#define DEFAULT_FACTORER "DECIMO"
//#define DEFAULT_FACTORER "FUNDFLOW"
#define DEFAULT_FACTORER "TILTA"
FUNCTION PRINT_RECH_FACTORING(oPrinter)
   LOCAL oKuExtra := ku->(ExtraData():New(ku->Nummer))
   LOCAL oReExtra := reh->(ExtraData():New(re->rechnr))
   LOCAL cFile
   LOCAL cLang := "de"
   IF oKuExtra:Factoring
      IF Empty(oReExtra:Factorer)
         oReExtra:Factorer := Pad(DEFAULT_FACTORER,12)
         oReExtra:Save()
      ENDIF
      IF ku->Language != "D"
         cLang := "en"
      ENDIF
      cFile := Path("config\texts\factoring_"+Trim(oReExtra:Factorer)+"_"+cLang+".txt")
      IF File(cFile)         
         PrintTextFile(cFile)
      ENDIF
   ENDIF