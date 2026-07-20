FUNCTION HOOK_GET_ARCHIVE_FILES(hTyp)

#include 'archive.ch'

LOCAL cArchDir := GetConfigValue("ARCHIVE_DIR")
LOCAL aDirs := {}
LOCAL nNo,cTyp,cContent
LOCAL hFields
LOCAL aMonths := {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
LOCAL cDate
LOCAL aTemp,aSearchDirs,cDir
LOCAL cExtension,aMatches
LOCAL oAgorum,aFile
LOCAL cDocType
LOCAL aHistory
LOCAL bAdd
LOCAL hDocTypes := {;
         "ek_customer_order_confirmation"=>"Auftragsbest„tigung",;
         "ek_customer_order"=>"Auftrag",;
         "ek_supplier_order"=>"Bestellung";
      }

SET TIME FORMAT TO "hh:mm:ss"
IF .F. //Tr_getini(28) $ {9,45}
   oAgorum := AgorumCustomApi():New() 
   bAdd := {|cDate|
      LOCAL dDT := StoT(StrTran(StrTran(StrTran(cDate,"-",""),"T",""),":",""))+2/24
      Aadd(aDirs,{cDocType+" (Agorum)",,StoD(TtoS(dDT)),SubStr(TtoC(dDT),10,8),,'agorum:open:path:get:'+aFile["uuid"]})
      RETURN NIL
   }
   FOR EACH aFile IN oAgorum:Search(HGetKeyAt(hTyp,1),HGetValueAt(hTyp,1))
      IF aFile != NIL
         IF hHasKey(hDocTypes,aFile["metadata"]["ag_metadata_collection"]) 
            cDocType := hDocTypes[aFile["metadata"]["ag_metadata_collection"]]
         ELSE
            cDocType := aFile["metadata"]["ag_metadata_collection"]
         ENDIF
         Eval(bAdd,aFile["date"])
         FOR EACH aHistory IN aFile["history"]
            Eval(bAdd,aHistory["date"])
         NEXT
      ENDIF
   NEXT

ENDIF


DispEnd()
FOR EACH nNo IN hTyp
   cTyp := nNo:__eNumKey()   
   
   //cDir := cArchDir+"\"+hTypes[cTyp]:Dir+"\"
   aSearchDirs := GetArchiveDirList(hTypes[cTyp])   
   FOR EACH cDir IN aSearchDirs
      
      aTemp := Directory(cDir+GetArchivePrefix(hTypes[cTyp],nNo)+"*.*")
      AEval(aTemp,{|aFile|
         Aadd(aFile,cDir+aFile[1])         
         cExtension := Lower(SubStr(aFile[1],Rat(".",aFile[1])))
         IF cExtension == ".eml"
            hFields := _GetFieldData(aFile[6],{"Subject:","From:","Date:"},,Chr(13))
            aFile[1] := hFields["Subject:"]+" ("+Trim(hFields["From:"])+")"
   //         Tue, 5 Aug 2014 09:33:29 +0000
   //
            aMatches := HB_RegExAll("[^\s]*\s([0-9]{1,2})\s*([^\s]*)\s*([0-9]{4})\s*([0-9:]{8})",hFields["Date:"])
            IF aMatches != NIL .AND. Len(aMatches) > 0
               aFile[3] := SToD(aMatches[1,4]+StrZero(AScan(aMonths,aMatches[1,3]),2)+PadL(aMatches[1,2],2,"0"))
               aFile[4] := aMatches[1,5]
            ENDIF
   //         AEval(aMatches,{|aMatch| AEval(aMatch,{|cMatch| Alert(cMatch)}) })
         ELSEIF cExtension == ".pdf"
            hFields = _GetFieldData(aFile[6],{"/Subject","/CreationDate"},@cContent,")")
            cDate := SubStr(hFields["/CreationDate"],At("D:",hFields["/CreationDate"])+2)
            IF ! Empty(cDate)
               aFile[3] := StoD(SubStr(cDate,0,8))
               aFile[4] := SubStr(cDate,9,2)+":"+SubStr(cDate,11,2)+":"+SubStr(cDate,13,2)
            ENDIF
            IF hFields["/Subject"] != "(" .AND. ! Empty(hFields["/Subject"])
               aFile[1] := HB_AnsiToOem(SubStr(hFields["/Subject"],2,Len(hFields["/Subject"])-2))
            ELSE
               aFile[1] := HB_AnsiToOem(hTypes[cTyp]:Name)
            ENDIF
         ELSEIF cExtension == ".tif"
            aFile[1] := hTypes[cTyp]:Name+" (Fax von: "+Lower(SubStr(aFile[1],AT("_",aFile[1])+1,Rat(".",aFile[1])-AT("_",aFile[1])-1))+")"
         ENDIF
         //FileStats(cDir+aFile[1],,,,,@dChangeDate,@nChangeTime)
         //aFile[3] := dChangeDate
         //aFile[4] := SecToTime(nChangeTime)         
         Aadd(aDirs,aFile)
         RETURN NIL
      })
   NEXT
NEXT

ASort(aDirs,,,{|x,y| x[3] < y[3] .OR. (x[3] == y[3] .AND. x[4] < y[4]) })

RETURN aDirs

STATIC Function _GetFieldData(cFile,aFields,cContent,cEndChar,cAltEndChar)
      LOCAL hFields := {=>},cField,cFieldData
      //LOCAL cContent
      cContent := FileStr(cFile)
      FOR EACH cField IN aFields
         nPos := AT(Chr(10)+cField,cContent) //at beginning of line
         IF nPos == 0
            nPos := AT(cField,cContent)
            IF nPos != 1
               nPos := 0
            ENDIF
         ENDIF
         IF nPos > 0
            cFieldData := SubStr(cContent,nPos+Len(cField)+1)
            nPos := AT(cEndChar,cFieldData)
            cFieldData := AllTrim(SubStr(cFieldData,0,nPos-1))
         ELSE
            cFieldData := ""
         ENDIF
         hFields[cField] := cFieldData
      NEXT
RETURN hFields

#include 'archive.prg'
//#include '../run/agorum.prg'
