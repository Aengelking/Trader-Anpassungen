//#include 'y:\harbour\trader\source\include\trader.ch'
#include 'inkey.ch'

#define PATH_SCN "Y:\Dokumente und Einstellungen\All Users\Dokumente\QS\SCN\"
#define CRLF Chr(13)+Chr(10)

/******************************************************************************
 * SCN Sender Program
 * 
 * This program allows sending Specification Change Notices (SCNs) for multiple 
 * drawings at once. It generates PDF documents from OpenOffice templates and 
 * sends them via email using the existing SendMail infrastructure.
 * 
 * Based on the _SENDSCN function in trd_nr_zeich.prg
 ******************************************************************************/

FUNCTION SCN_Sender_Main()
   LOCAL oBrowse
   LOCAL aSCNList := {}   
   LOCAL cKunde := Space(8)
   LOCAL nContact := 0
   LOCAL hContact := {=>}
   LOCAL cSupplierName := ""
   LOCAL cLanguage := "D"
   LOCAL getlist := {}
   MEMVAR c_one_list

   HEAD("SpezifikationsÑnderungsmitteilungen versenden")

   // First select supplier and contact for all SCNs   
   NetUse("engkund","ku") 
   NetUse("contacts","conts")
    
   ku->(dbSetOrder(8))  // Kundennummer
   conts->(dbSetOrder(2)) // Address+Contact
   
   @ 01,00 SAY "Lieferant" GET cKunde PICTURE "@!" VALID {|| 
      IF FindAd(cKunde,"L",01,40)
         cSupplierName := Trim(ku->Name1)+" "+Trim(ku->Name2)
         cLanguage := Trim(ku->Language)
         RETURN .T.
      ENDIF
      RETURN .F.
   }    
   @ 02,00 SAY "Person"
   GET_Contact(getlist,02,10,{|v| If(v==NIL,nContact,nContact:=v)},,{||
      LOCAL lValid := .T.
      hContact := GetContact(nContact)
      IF Empty(hContact["email"])
         Tr_MsgBox("Kontakt hat keine Emailadresse")
         lValid := .F.
      ENDIF
      RETURN lValid
   },,c_one_list)
   READ

   IF LastKey() == 27
      RETURN .F.
   ENDIF
   
   @ MaxRow()-2,00 SAY Replicate(Chr(196),MaxCol())
   @ MaxRow()-1,00 SAY "EINFG=Artikel hinzufÅgen  ENTER=Bearbeiten  ENTF=Lîschen  ESC=Versenden/Beenden"
   
   // Initialize browse for SCN list
   oBrowse := TABrowse():New(07,00,MaxRow()-3,MaxCol())
   //oBrowse:headSep := ""
   oBrowse:lBox := .F.
   oBrowse:aData := aSCNList
   
   oBrowse:AddColumn(TBColumn():New(Pad("Artikel",25)+" "+Pad("Zeichnung",15)+" "+Pad("Rev",5)+" "+Pad("Prod.Stop",9)+" "+Pad("BOM énd.",8)+" "+Pad("Status",10),{|| 
      LOCAL hItem
      IF Len(oBrowse:aData) > 0 
         hItem := oBrowse:CurrentDataRow()
         IF ValType(hItem) == "H"
         //RETURN Pad(Pad(hItem["ARTIKEL"],25)+" "+Pad(hItem["ZEICHNUNG"],15)+" "+ValToPrg(aData),MaxCol())
            RETURN Pad(Pad(hItem["ARTIKEL"],25)+" "+Pad(hItem["ZEICHNUNG"],15)+" "+Pad(hItem["REVISION"],5)+" "+Pad(IF(hItem["STOP"],"Ja","Nein"),9)+" "+Pad(IF(hItem["BOM"],"Ja","Nein"),8)+" "+Pad(hItem["STATUS"],20),MaxCol())
         ENDIF
      ENDIF
      RETURN Pad("Keine Artikel ausgewÑhlt - >EINFG< zum HinzufÅgen",MaxCol())
   }))
   
   // Add hotkeys
   oBrowse:AddKey(K_INS, {|| SCN_AddArticle(@aSCNList), oBrowse:RefreshAll(), oBrowse:Display(), .T. })
   oBrowse:AddKey(K_ENTER, {|| SCN_EditItem(oBrowse:CurrentDataRow()), oBrowse:Display(), .T. })
   oBrowse:AddKey(K_DEL, {|| SCN_RemoveItem(@aSCNList, oBrowse:CurrentRow()), oBrowse:RefreshAll(), oBrowse:Display(), .T. })

   oBrowse:AddKey(K_ESC, {|| .F. })
   
   oBrowse:Display()   
   oBrowse:EventLoop()

   oBrowse:goTop()
   oBrowse:Display()
   oBrowse:dehilite()

   IF Len(aSCNLIST) > 0 .AND. AMenu({"PDFs erstellen und versenden","abbrechen"}) == 1      
      IF SCN_CreateAllPDFs(aSCNList, cSupplierName,oBrowse)
         SCN_SendAll(aSCNList,hContact)
      ENDIF
   ENDIF
    
RETURN .T.

/******************************************************************************
 * Add new article to SCN list
 ******************************************************************************/
FUNCTION SCN_AddArticle(aSCNList)
   LOCAL cMatchcode := Space(30)
   LOCAL cRevision := Space(8)
   LOCAL lStop := .F.
   LOCAL lBOM := .F.
   LOCAL getlist := {}
   LOCAL aEnv := SaveEnv()
   LOCAL hItem := {=>}
   LOCAL aDrawingFiles
   MEMVAR c_four, c_four_list

   SetColor(c_four)
   @ 10,25 CLEAR TO 18,100
   @ 10,25 TO 18,100 DOUBLE
   @ 10,26 SAY "[ Artikel hinzufÅgen ]"

   NetUse("artikel","art")
   art->(dbSetOrder(1)) // Matchcode

   @ 12,26 SAY "Artikel     " GET cMatchcode PICTURE "@K" VALID {|| 
      IF ValidVar( @cMatchcode, 12, 26+12+2, , , , .T. )          
         @ 13,39 SAY art->Zeichnung
         
         hItem["ARTIKEL"] := Trim(cMatchcode)
         hItem["ZEICHNUNG"] := Trim(art->Zeichnung)

         aDrawingFiles := GET_DRAWINGFILES( )
         IF Len(aDrawingFiles) == 0
           Tr_MsgBox("Keine Zeichnungsdatei gefunden")
            RETURN .F.
         ENDIF
         cRevision := Pad(ATail(aDrawingFiles)[1],8)

         //cRevision := art->Zeichindex
         getlist[2]:Display()  //display zeichnungsrevision
         RETURN .T.
      ENDIF
      RETURN .F.
   }
   ATail( getlist ):Reader := {| oGet, oGetlist, oMenu, oGetMsg| SwapReader( oGet, oGetList, oMenu, oGetMsg ) }

   @ 13,26 SAY "Zeichnung: "
   @ 14,26 SAY "Revision    " GET cRevision VALID {||
      LOCAL cFile
      cFile := Hook("get_drawingfile",{.F.,Trim(art->Zeichnung),Trim(cRevision),art->Kuzeichnun}) 
      IF Empty(cFile)
         @ 14,48 SAY "Zeichnungsdatei nicht gefunden"
         RETURN .F.
      ELSE
         // Show found drawing file path
         @ 13,48 SAY SubStr(cFile,RAT("\",cFile)+1)
         // Store drawing file path in item
         hItem["DRAWING_FILE"] := cFile
      ENDIF
      RETURN .T.
   }
   @ 15,26 SAY "Produktionsstop        " GET lStop PICTURE "Y"
   @ 16,26 SAY "énderung in StÅckliste " GET lBOM PICTURE "Y"

   read

   IF LastKey() == 27
      RestEnv(aEnv,.T.)
      RETURN .F.
   ENDIF

   // Create SCN item   
   hItem["REVISION"] := Trim(cRevision)
   hItem["STOP"] := lStop
   hItem["BOM"] := lBOM
   hItem["STATUS"] := "HinzugefÅgt"
   hItem["PDF_FILE"] := ""
   hItem["ART_REC"] := art->(RecNo())

   Aadd(aSCNList, hItem)

   RestEnv(aEnv,.T.)
    
RETURN .T.

/******************************************************************************
 * Edit existing SCN item
 ******************************************************************************/
FUNCTION SCN_EditItem(hItem)
    LOCAL getlist := {}
    LOCAL aEnv := SaveEnv()
    LOCAL lStop, lBOM
    MEMVAR c_four
    
    IF hItem == NIL .OR. Len(hItem) == 0
        RETURN .F.
    ENDIF
    
    lStop := hItem["STOP"]
    lBOM := hItem["BOM"]
    hItem["REVISION"] := PAd(hItem["REVISION"],8)
    
    SetColor(c_four)
    @ 10,25 CLEAR TO 17,75
    @ 10,25 TO 17,75 DOUBLE
    @ 10,26 SAY "[ " + hItem["ARTIKEL"] + " bearbeiten ]"
    
    @ 12,26 SAY "Artikel: " + hItem["ARTIKEL"]
    @ 13,26 SAY "Zeichnung: " + hItem["ZEICHNUNG"]
    @ 14,26 SAY "Revision: " GET hItem["REVISION"]
    @ 15,26 SAY "Produktionsstop        " GET lStop PICTURE "Y"
    @ 16,26 SAY "énderung in StÅckliste " GET lBOM PICTURE "Y"
    
    read
    
    IF LastKey() != 27
        hItem["STOP"] := lStop
        hItem["BOM"] := lBOM
        hItem["REVISION"] := Trim(hItem["REVISION"])        
    ENDIF
    
    RestEnv(aEnv,.T.)
    
RETURN .T.

/******************************************************************************
 * Remove item from SCN list
 ******************************************************************************/
FUNCTION SCN_RemoveItem(aSCNList, nPos)
    IF nPos > 0 .AND. nPos <= Len(aSCNList)
        IF Tr_MsgBox("Artikel '" + aSCNList[nPos]["ARTIKEL"] + "' entfernen?",,{"Nein","Ja"}) == 2
            HB_ADel(aSCNList, nPos, .T.)
        ENDIF
    ENDIF
RETURN .T.

/******************************************************************************
 * Create PDFs for all SCN items
 ******************************************************************************/
FUNCTION SCN_CreateAllPDFs(aSCNList, cSupplierName,oBrowse)
    LOCAL nX
    LOCAL hItem
    LOCAL lSuccess := .T.
    
    // Use supplier name parameter if provided, otherwise use name from first item
    IF Empty(cSupplierName) .AND. Len(aSCNList) > 0
        cSupplierName := aSCNList[1]["LIEFERANT"]
    ENDIF
    
    IF Len(aSCNList) == 0
        Tr_MsgBox("Keine Artikel zum Bearbeiten")
        RETURN .F.
    ENDIF
    
    FOR nX := 1 TO Len(aSCNList)      
      hItem := aSCNList[nX]
      IF Empty(hItem["PDF_FILE"])
         hItem["STATUS"] := "PDF wird erstellt..."
         oBrowse:RefreshAll()
         oBrowse:Display()
         oBrowse:dehilite()

         IF SCN_CreateSinglePDF(hItem,cSupplierName)            
            hItem["STATUS"] := "PDF erstellt"
         ELSE            
            hItem["STATUS"] := "PDF Fehler"
            lSuccess := .F.
         ENDIF

         oBrowse:RefreshAll()
         oBrowse:Display()
         oBrowse:dehilite()
      ENDIF
    NEXT       
   
RETURN lSuccess

/******************************************************************************
 * Create single PDF for SCN item
 ******************************************************************************/
FUNCTION SCN_CreateSinglePDF(hItem,cSupplierName)
    LOCAL oScnDoc, cPdfPath, aPdfProps, oServiceManager
    LOCAL cTemplateFile := 'Y:\Dokumente und Einstellungen\All Users\Dokumente\Vorlagen\QM\fb123_SpezifikationsÑnderungsmitteilung_1.5.ott'
    LOCAL hTemplateData
    
    // Prepare template data
    hTemplateData := {=>}
    hTemplateData["Lieferant"] := cSupplierName
    hTemplateData["ProductionstopYes"] := IF(hItem["STOP"],"X","")
    hTemplateData["ProductionstopNo"] := IF(!hItem["STOP"],"X","")
    hTemplateData["BOMYes"] := IF(hItem["BOM"],"X","")
    hTemplateData["BOMNo"] := IF(!hItem["BOM"],"X","")
    hTemplateData["Artikel"] := hItem["ARTIKEL"]
    hTemplateData["Zeichnungsnummer"] := hItem["ZEICHNUNG"]
    hTemplateData["Zeichnungsrevision"] := hItem["REVISION"]
    
    // Generate PDF filename
    cPdfPath := PATH_SCN+"SCN_"+StrTran(hItem["ARTIKEL"],"/","_")+"_"+hItem["ZEICHNUNG"]+IF(!Empty(hItem["REVISION"]),"-"+hItem["REVISION"],"")+"_"+DToS(Date())+"_"+StrTran(Time(),":","")+".pdf"
    
    // Open OpenOffice template
    oScnDoc := OpenOOWriterTemplate(cTemplateFile, hTemplateData, .F.)
    
    IF ValType(oScnDoc) == "O"
        // Get the service manager
        oServiceManager := CreateObject("com.sun.star.ServiceManager")
        
        IF ValType(oServiceManager) == "O"
            // Create property for PDF export filter
            aPdfProps := {}
            Aadd(aPdfProps, OOProperty(oServiceManager, "FilterName", "writer_pdf_Export"))
            
            //TRY
                // Export to PDF using storeToURL
                oScnDoc:storeToURL("file:///"+StrTran(cPdfPath,"\","/"), aPdfProps)
                
                // Store PDF file path in item
                hItem["PDF_FILE"] := cPdfPath
                
                // Close the document
                oScnDoc:close(.F.)
                
                RETURN .T.
            /*CATCH oError
                Tr_MsgBox("PDF Export Fehler: " + oError:description)
                oScnDoc:close(.F.)
                RETURN .F.
            END*/
        ELSE
            Tr_MsgBox("Fehler beim Zugriff auf den Service Manager")
            oScnDoc:close(.F.)
            RETURN .F.
        ENDIF
    ELSE
        Tr_MsgBox("Fehler beim Erstellen des OpenOffice-Dokuments fÅr " + hItem["ARTIKEL"])
        RETURN .F.
    ENDIF
    
RETURN .F.

/******************************************************************************
 * Send all SCN emails
 ******************************************************************************/
FUNCTION SCN_SendAll(aSCNList,hContact,cLanguage)
   LOCAL nX      
   LOCAL aRcvs
   LOCAL hEmailData, hTemplateData

   
   hEmailData := {=>}
   hEmailData["EMAIL"] := hContact["email"] //, hContact["name"]}
   hEmailData["ATTACHEMENTS"] := {}
    
   hTemplateData := {=>}
   hTemplateData["parts_list_subject"] := ""
   hTemplateData["parts_list"] := ""

    // Prepare attachments
    FOR nX := 1 TO Len(aSCNList)
        
        Aadd(hEmailData["ATTACHEMENTS"], aSCNList[nX]["PDF_FILE"])        
        Aadd(hEmailData["ATTACHEMENTS"], aSCNList[nX]["DRAWING_FILE"])
        
        IF nX > 1
            hTemplateData["parts_list_subject"] += ", "
            hTemplateData["parts_list"] += CRLF
        ENDIF
        hTemplateData["parts_list_subject"] += aSCNList[nX]["ARTIKEL"]
        hTemplateData["parts_list"] += Pad(aSCNList[nX]["ARTIKEL"],25)+" "+aSCNList[nX]["ZEICHNUNG"]+IF(!Empty(aSCNList[nX]["REVISION"]),"-"+aSCNList[nX]["REVISION"],"")
    NEXT
    
   SendMailInterface(hEmailData,hContact,"scn",hTemplateData,cLanguage,.T.)   
    
RETURN .T.


/******************************************************************************
 * Include required functions from existing codebase
 ******************************************************************************/

// Include OOProperty function
FUNCTION OOProperty( oServiceManager, cName, uValue )
   LOCAL cStructure
   LOCAL oProperty

   cStructure := "com.sun.star.beans.PropertyValue"

   oProperty := oServiceManager:bridge_GetStruct( cStructure )
   oProperty:Name := cName
   oProperty:Value := uValue
   
RETURN oProperty

// Include FindAd function (simplified version)
FUNCTION FindAd(cKunde, cGroup, nRow, nCol)
    LOCAL lFound := .F.
    
    ku->(dbSetOrder(8))
    IF ku->(dbSeek(Str(Val(cKunde),6) + cGroup))
        @ nRow,nCol SAY ku->Name1 + " " + ku->Name2
        lFound := .T.
    ELSEIF ku->(dbSeek(cKunde + cGroup))
        @ nRow,nCol SAY ku->Name1 + " " + ku->Name2  
        lFound := .T.
    ELSE
        @ nRow,nCol SAY "*** NICHT GEFUNDEN ***"
    ENDIF
    
RETURN lFound

/**
   Get all drawing files for a drawing number
**/
FUNC GET_DRAWINGFILES( )

   LOCAL cDir,nPos,nPos2,cInd
   LOCAL aSearch,nS
   LOCAL aFiles,nF
   LOCAL aData := {}
   LOCAL cZeich := Trim(art->Zeichnung)
   
   cDir := "\\EK-SERVER4\Data\Technik\Prozessdoku\"+If(art->Kuzeichnun,"Kunden\","")   
   
   aSearch := {cZeich+"*_*.*","0"+cZeich+"*_*.*"}
  
   
   FOR nS := 1 TO Len(aSearch)
      
      aFiles := Directory(cDir+aSearch[nS])
      
      FOR nF := 1 TO Len(aFiles)
         nPos := At(cZeich,aFiles[nF,1])+3 //+Len(cZeich)
         nPos2 := At("_",aFiles[nF,1])
         IF nPos2 == 0
            nPos2 := RAt(".",aFiles[nF,1])
         ENDIF
         IF nPos != 0
            cInd := StrTran(SubStr(aFiles[nF,1],nPos+1,nPos2-nPos-1),"-","")
         ELSE
            cInd := ""
         ENDIF
         IF AScan(aData,{|x| x[1] == cInd}) == 0
            Aadd(aData,{cInd,aFiles[nF,1],cDir+aFiles[nF,1]})
         ELSE
            //Alert("Zwei Dateien fÅr eine Revision")
         ENDIF
         
      NEXT
   NEXT
   

   ASort(aData,,,{|a,b| a[1] < b[1] })

RETURN aData

