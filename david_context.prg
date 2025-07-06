#define GS_EXE '"C:\Program Files\gs\gs9.22\bin\gswin64c.exe"'
#define WVT_BLOCK_IMAGE                           1
#include 'y:\hb32\include\hbgtinfo.ch' 

PROCEDURE RUN_DAVID_CONTEXT( cFunction,cMsgPath )
   LOCAL getlist := {}
   LOCAL cLiefma,cBeleg
   LOCAL aFiles := {},nFile := 1
   LOCAL cFileRegex := "\.pdf$",nAtt,oArchive,oMsg,cArchive,oAccount
   LOCAL cImageFile,cGSExe,cFileName,nStdOut,bDrawImage
   LOCAL aPaint := {},oAtt
   LOCAL cTempPath := GetEnv("temp")+"\"

   SWITCH Upper(cFunction)
      CASE "COC"
         IF ! Empty(cMsgPath)  //email
            oAccount := DV_GetMailAccount()
            cArchive := SubStr(cMsgPath,1,RAT("\",cMsgPath)-1)
            oArchive := oAccount:GetArchive(cArchive)
            oMsg := oArchive:GetArchiveEntryById(cMsgPath)
         
            FOR nAtt := 0 TO oMsg:Attachments:Count-1
               IF HB_RegExMatch(cFileRegex,oMsg:Attachments:Item(nAtt):FileName,.F.)
                  Aadd(aFiles,oMsg:Attachments:Item(nAtt):FileName)      
                  oAtt := oMsg:Attachments:Item(nAtt)
                  oAtt:CopyOut(cTempPath,oAtt:FileName)        

                  cFileName := cTempPath+oAtt:FileName
                  cImageFile := cTempPath+SubStr(cFileName,Rat("\",cFileName)+1)+".jpg"
                  cGSExe := GS_EXE+' -sDEVICE=jpeg -r300 -q -dBATCH -dNOPAUSE -sOutputFile="'+cImageFile+'" "'+cFileName+'"' //extract first page from PDF as JPEGs
                  HB_ProcessValue(HB_OpenProcess(cGSExe,,@nStdOut,,.T.),.T.) //run GS and wait until it terminates                  
                  
               ENDIF
            NEXT
         ELSEIF HB_RegExMatch("\.pdf$",GetConfigValue("attachfile"),.F.)
            Aadd(aFiles,GetConfigValue("attachfile"))
         ENDIF

         IF Len(aFiles) == 0
            Tr_MsgBox("Keine PDF Datei gefunden.")
            RETURN
         ENDIF
            

         NetUse("engkund","ku")
         cLiefma := Space(8)
         cBeleg := Space(15)
         Head("Werksbescheinigung archivieren")         
         
         bDrawImage := {||
            LOCAL nRatio,nWidth
            LOCAL nImageBottom,nImageRight,nImageTop
            IF ! Empty(cImageFile)
               nRatio := (210/HB_GTINFO( HB_GTI_FONTWIDTH))/(297/HB_GTINFO( HB_GTI_FONTSIZE))

               nWidth :=  Int(nRatio*(47-10))  //30

               nImageTop := 10
               nImageBottom := 47 //*nScale
               nImageRight := nWidth //*nScale

               Wvt_DrawImage( nImageTop,00,nImageBottom,nImageRight, cImageFile, {00, 00, 00, Mod(nRatio,47-10)*72 } )

            ENDIF
            RETURN NIL
         }
         
         //SetKey( 1101, bDrawImage)
         Aadd(aPaint,{ "Image" , bDrawImage , { WVT_BLOCK_IMAGE,  10, 00, 47, (210/HB_GTINFO( HB_GTI_FONTWIDTH))/(297/HB_GTINFO( HB_GTI_FONTSIZE))*(47-10) } })
         WvtSetPaint(aPaint)
         

         @ 01,00 SAY "Datei       "
         @ 01,13,09,70 GET nFile LISTBOX aFiles DROPDOWN STATE {||   
            IF getlist[1]:Control != NIL
               cFileName := cTempPath+aFiles[getlist[1]:Control:Buffer]
               cImageFile := cTempPath+SubStr(cFileName,Rat("\",cFileName)+1)+".jpg"
               /*cGSExe := GS_EXE+' -sDEVICE=jpeg -r300 -q -dBATCH -dNOPAUSE -sOutputFile="'+cImageFile+'" "'+cFileName+'"' //extract first page from PDF as JPEGs
               HB_ProcessValue(HB_OpenProcess(cGSExe,,@nStdOut,,.T.),.T.) //run GS and wait until it terminates
               Alert(cImageFile)*/
               Eval(bDrawImage)               
            ENDIF
            RETURN NIL
         }
         Eval(getlist[1]:Control:sBlock)
         @ 02,00 SAY "Lieferant   " GET cLiefma PICTURE "@!" VALID Empty(cLiefma) .OR. FindAd( cLiefma, "L",01,50 )
         @ 03,00 SAY "Lieferschein" GET cBeleg VALID ! Empty(cBeleg) PICTURE "@!"
         READ
         IF LastKey() == 27
            RETURN         
         ENDIF
         WvtSetPaint({})

         cBeleg := StrZero(ku->Nummer,6)+"-"+StrTran(Alltrim(cBeleg)," ","")
         AddFileToArchive("COC",cBeleg,cTempPath+aFiles[nFile])
         EXIT      
      CASE "INVOICE"
         MBaseRun(Trim(tr_getini(1))+"\run\Invoice_beleg",{"CONTEXT",cMsgPath})
         EXIT
      CASE "NOTIZ"
         MBaseRun(Trim(Tr_getini(1))+'\run\notiz')
         EXIT
      CASE "BESCHK"
         MBaseRun(Trim(Tr_getini(1))+'\run\BesChk',{cMsgPath})
         EXIT
      CASE "QUOTE"
         Quote_edit()
         EXIT   
      CASE "ENQUIRY"
         //MBaseRun(Path("\run\test_nocrm_email"),{cMsgPath})
         Enquiry()
         EXIT
      CASE "AUFTRAG"
         IF Tr_Getini(28) == 9
            __Run("Y:\harbour\trader\bin\trader.exe -C 1 -F MBaseRun(Path('run\docprocessing\Auto_Auftrag'),{'"+cMsgPath+"'})")
            //MBaseRun(Path("\run\docprocessing\Auto_Auftrag"),{cMsgPath})
         ELSE
            MBaseRun(Trim(tr_getini(1))+"\run\Auftrag_Beleg",{cMsgPath})
         ENDIF
         EXIT
      CASE "ANGEBOT"
         MBaseRun(Trim(tr_getini(1))+"\run\Angebot_order",{cMsgPath})
         EXIT
   END