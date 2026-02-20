/*
   Archive Order Log Files to Standard Archive System
   
   Moves order log files from logs/orders/ to the archive using the
   standard HOOK_ADD_ARCHIVE_FILE function with a new "ORDER" type.
   
   Run this periodically (daily/weekly) to clean up old order logs
*/

#define CRLF CHR(13)+CHR(10)

PROCEDURE RUN_Archive_Order_Logs(nDaysOld)
   LOCAL cBasePath, cLogsPath
   LOCAL aFiles, aFile
   LOCAL nMoved := 0, nFailed := 0, nSkipped := 0
   LOCAL dFileDate
   LOCAL cSourceFile
   LOCAL nOrderNum
   LOCAL lSuccess,oAuftrag

   // Default to archiving files older than 30 days
   IF nDaysOld == NIL
      nDaysOld := 30
   ENDIF
   
   cBasePath := "X:\www\api\"
   cLogsPath := cBasePath + "logs\orders\"
   
   // Check if logs directory exists
   IF !hb_DirExists(cLogsPath)
      ? "Error: Logs directory does not exist: " + cLogsPath
      SendMail({{"amos.engelking@engelking.de"}},"Archive order logs failed","Directory not found: " + cLogsPath)
      RETURN
   ENDIF

   // Get all .txt files in the logs/orders directory
   aFiles := Directory(cLogsPath + "AUF_*.txt")
   
   IF Len(aFiles) == 0
      ? "No order log files found to archive."
      RETURN
   ENDIF

   CLS
   ? "Order Log Archiver"
   ? "===================="
   ? ""
   ? "Found " + LTrim(Str(Len(aFiles))) + " order log file(s)"
   ? ""

   FOR EACH aFile IN aFiles
      // Use file modification date
      dFileDate := aFile[3]
      
      cSourceFile := cLogsPath + aFile[1]
      
      // Extract order number from filename: AUF_12345_20260201_143022.txt
      nOrderNum := Val(SubStr(aFile[1], 5, At("_", SubStr(aFile[1], 5)) - 1))

      IF nOrderNum > 0
         oAuftrag := Auftrag():New()
         oAuftrag:Load(nOrderNum)
         BEGIN SEQUENCE
            // Use AddFileToArchive function (which calls HOOK_ADD_ARCHIVE_FILE)
            IF ! Empty(AddFileToArchive("AUF", nOrderNum, cSourceFile,.F.,oAuftrag))
               // Delete source file after successful archiving
               FErase(cSourceFile)
               IF FError() == 0
                  nMoved++
                  ? "√ Archived: " + aFile[1] + " -> Order " + LTrim(Str(nOrderNum))
               ELSE
                  ? "! Error deleting source: " + aFile[1]
                  nFailed++
               ENDIF
            ELSE
               ? "× Failed to archive: " + aFile[1]
               nFailed++
            ENDIF
         RECOVER
            ? "× Exception archiving: " + aFile[1]
            nFailed++
         END SEQUENCE
      ELSE
         ? "! Skipped (invalid filename): " + aFile[1]
         nSkipped++
      ENDIF
      
   NEXT

   ? ""
   ? "Archive completed:"
   ? "  Files moved: " + LTrim(Str(nMoved))
   ? "  Files failed: " + LTrim(Str(nFailed))
   ? "  Files skipped: " + LTrim(Str(nSkipped)) + " (invalid)"

   /*LogInfo("Order logs archived", {;
      "moved"=>nMoved,;
      "failed"=>nFailed,;
      "skipped"=>nSkipped,;
      "total_files"=>Len(aFiles),;
      "cutoff_date"=>DToC(dCutoffDate);
   })*/
   IF nFailed > 0 .OR. nSkipped > 0      
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Order Log Archive Report",;
         "Archive completed:" + CRLF + ;
         "  Files moved: " + LTrim(Str(nMoved)) + CRLF + ;
         "  Files failed: " + LTrim(Str(nFailed)) + CRLF + ;
         "  Files skipped: " + LTrim(Str(nSkipped)) + " (invalid)" + CRLF;
      )
   ENDIF

   IF ! GetConfigValue("BATCHMODE")
      ? ""
      ? "Press any key to continue..."
      Inkey(0, 128)
   ENDIF
RETURN
