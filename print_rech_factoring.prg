#define DEFAULT_FACTORER "DECIMO"
//#define DEFAULT_FACTORER "FUNDFLOW"
FUNCTION PRINT_RECH_FACTORING(oPrinter)
   LOCAL oKuExtra := ku->(ExtraData():New(ku->Nummer))
   LOCAL oReExtra := reh->(ExtraData():New(re->rechnr))
   LOCAL cFile
   IF oKuExtra:Factoring
      IF Empty(oReExtra:Factorer)
         oReExtra:Factorer := Pad(DEFAULT_FACTORER,12)
         oReExtra:Save()
      ENDIF
      cFile := Path("config\texts\factoring_"+Trim(oReExtra:Factorer)+".txt")
      IF File(cFile)         
         PrintTextFile(cFile)
      ENDIF
   ENDIF