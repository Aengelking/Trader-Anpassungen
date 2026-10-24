#include 'y:\hb32\include\inkey.ch'
//#include  'y:\harbour\trader\source\include\trget.ch'
#command @ <row>, <col> GET <v> SUGGESTIONS <list> [PICTURE <pic>] [COLOR <color>] ;
                           [VALID <valid>] [WHEN <when>] [SEND <snd>] ;
                           [CAPTION <cap>] [MESSAGE <msg>] => ;
         AAdd( GetList,GetSuggestions():New( <row>,<col>,{|newv| IF(newv==NIL,<v>,<v>:=newv)}, <"v">, <pic>, <color> ) ) ;;
       [ ATail(getlist):preBlock :=  <{when}>;];
       [ ATail(getlist):postBlock := <{valid}>;];
       [ ATail(GetList):Caption := <cap> ;;
         ATail(GetList):CapRow := ATail(Getlist):row ;;
         ATail(GetList):CapCol := ATail(Getlist):col - __CapLength(<cap>) - 1 ;] ;
       [ ATail(GetList):message := <msg> ;] [ ATail(GetList):<snd> ;] ;
         ATail(GetList):aValues := <list> ;;
         ATail(GetList):Display()

#define CRLF "<br>" //Chr(13)+Chr(10)

#define PATH_SCN "Y:\Dokumente und Einstellungen\All Users\Dokumente\QS\SCN\"

FUNCTION TRD_NR_ZEICH
   LOCAL oBrowse,oFileBrowse
   LOCAL aBrowse := {}
   LOCAL nX,nB,aRegex
   LOCAL bChangeBrowse,nKey
   LOCAL nActiveBrowse := 1,aButtons := {},oButton
   LOCAL nF,aFiles
   MEMVAR c_five,c_four,c_four_list
   SetColor(c_five)
   @ 05,10 CLEAR TO 43,87
   @ 05,10 TO 43,87
   
   
   //GET_DRAWINGFILES(nr_zeich->Nummer)

   NetUse("apprreq","areq")
   NetUse("engkund","ku")
   NetUse("artikel","art")
   NetUse("ppf","ppf")
   NetUse("ppfdat","ppfd")
   NetUse("contacts","conts")
   NetUse("apprzeich","azeich")

   
   @ 06,11 SAY "Zeichnungsnr. "+LTrim(Str(nr_zeich->Nummer))
   @ 07,11 SAY "Datum         "+DToC(nr_zeich->Datum)
   @ 08,11 SAY "Beschreibung  "+Left(nr_zeich->Beschreibu,62)
   @ 09,25 SAY SubStr(nr_zeich->Beschreibu,63,62)
   
   @ 10,11 SAY Replicate(Chr(196),76)
   @ 10,12 SAY "[ Artikel ]"
   art->(dbSetOrder( 6 ))
   art->(dbSeek( LTrim(Str(nr_zeich->Nummer,6)) , .T. ))

   oBrowse :=art->(TBrowseTr():New(11,11,17,86))
   oBrowse:WhileBlock := {|| LTrim(Str(nr_zeich->Nummer,6)) == Trim(art->Zeichnung) }
   oBrowse:OneColumn := .T.
   oBrowse:headSep := ""
   oBrowse:NewColumn("Revision",{|| art->Zeichindex })
   oBrowse:NewColumn("Matchcode",{|| art->Matchcode })   

   oBrowse:AddKey(K_CTRL_ENTER,{|| _SendSCN() })

   Aadd(aBrowse,{oBrowse,SaveEnv()})

   @ 18,11 SAY Replicate(Chr(196),76)
   @ 18,12 SAY "[ Dateien ]"

   oFileBrowse := TABrowse():New(19,11,23,86)
   //oBrowse:WhileBlock := {|| LTrim(Str(nr_zeich->Nummer,6)) == Trim(art->Zeichnung) }   
   oFileBrowse:headSep := ""
   oFileBrowse:aData := GET_DRAWINGFILES(nr_zeich->Nummer)
   oFileBrowse:AddColumn(TBColumn():New(Pad("Revision",10)+" "+Pad("Datei",64),{|| 
      IF Len(oFileBrowse:aData) > 0
         RETURN Pad(oFileBrowse:CurrentDataRow()[1],10)+" "+Pad(oFileBrowse:CurrentDataRow()[2],64)
      ENDIF
      RETURN .T.
   }))
   oFileBrowse:AddKey(K_ENTER,{|| 
      WAPI_ShellExecute(,"open",oFileBrowse:CurrentDataRow()[3])         
      RETURN .T.
   })
   
   
   IF Len(oFileBrowse:aData) == 0
      @ 20,11 SAY "Keine Dateien vorhanden"
   ELSE
   //oBrowse:NewColumn("Datei",{|| oBrowse:CurrentDataRow()[2] })
      Aadd(aBrowse,{oFileBrowse,SaveEnv()})
   ENDIF

   @ 24,11 SAY Replicate(Chr(196),76)
   @ 24,12 SAY "[ Freigabeanforderungen ]"
   ku->(dbSetOrder( 8 ))
   areq->(dbSetOrder( 3 ))
   conts->(dbSetOrder( 2 ))
   areq->(dbSeek( LTrim(Str(nr_zeich->Nummer,6)) , .T. )) 
   oBrowse :=areq->(TBrowseTr():New(25,11,29,86))
   oBrowse:WhileBlock := {|| LTrim(Str(nr_zeich->Nummer,6)) == Trim(areq->Zeichnung) }
   oBrowse:OneColumn := .T.
   oBrowse:headSep := ""
   oBrowse:NewColumn("Revision",{|| areq->Zeichindex })
   oBrowse:NewColumn("Kunde",{|| ku->(dbSeek( Str(areq->Address,6) )),ku->Kunde })
   oBrowse:NewColumn("Person",{|| conts->(dbSeek(Str(areq->Address,6)+Str(areq->Contact,4))),conts->Name }) //ku->(dbSeek( Str(areq->Address,6) )),hContact := GetContact(areq->Contact,,.T.),hContact["name"] })
   oBrowse:NewColumn("Status",{|| 
      IF areq->Approved
         RETURN Pad("freigegeben",11)
      ELSEIF azeich->(dbSeek( Trim(areq->Zeichnung)+Trim(areq->Zeichindex) )) .AND. ! azeich->Approved
         RETURN Pad("abgelehnt",11)
      ENDIF
         
      RETURN Pad("wartet",11)
   })
   oBrowse:AddKey(K_INS,{|| __AddApprReq(),oBrowse:RefreshAll() })
   oBrowse:AddKey(K_DEL,{|| __DeleteApprReq(),oBrowse:RefreshAll(),oBrowse:Display() })
   Aadd(aBrowse,{oBrowse,SaveEnv()})

   @ 30,11 SAY Replicate(Chr(196),76)
   @ 30,12 SAY "[ Freigaben ]"

   ppf->(dbSetOrder( 4 ))
   ppf->(dbSeek( LTrim(Str(nr_zeich->Nummer,6)) ))
   ku->(dbSetORder( 8 ))
   ppfd->(dbSetOrder( 4 ))


   oBrowse :=ppf->(TBrowseTr():New(31,11,35,86))
   oBrowse:WhileBlock := {|| LTrim(Str(nr_zeich->Nummer,6)) == Trim(ppf->Zeichnung) }
   oBrowse:OneColumn := .T.
   oBrowse:headSep := ""
   oBrowse:NewColumn("Revision",{|| ppf->Zeichindex })
   oBrowse:NewColumn("Kunde",{|| IF(ppfd->(dbSeek( Str(ppf->Nummer,10)+"UNTK"+"Y", .T. )) .AND. ku->(dbSeek(Str(ppfd->Address,6))),ku->Kunde,"") })
   oBrowse:NewColumn("Status",{|| IF(ppfd->(dbSeek( Str(ppf->Nummer,10)+"UNTK"+"Y", .T. )),"freigegeben",Pad("offen",11)) })
   Aadd(aBrowse,{oBrowse,SaveEnv()})

   //LIST of SCN

   @ 36,11 SAY Replicate(Chr(196),76)
   @ 36,12 SAY "[ SpezifikationsÑnderungen ]"

   oBrowse := TABrowse():New(37,11,42,86)   
   oBrowse:headSep := ""
   aFiles := Directory(PATH_SCN+"SCN_*_"+LTrim(Str(nr_zeich->Nummer,6))+"*.*",.T.)

   oBrowse:aData := {} //GET_DRAWINGFILES(nr_zeich->Nummer)
   FOR nF := 1 TO Len(aFiles)
      aRegex := HB_Regex("SCN_([A-Za-z0-9_\.]+)_([0-9]+)(-([a-z]))?_.*$",aFiles[nF,1])      
      IF Len(aRegex) >= 3
         Aadd(oBrowse:aData,{StrTran(aRegex[2],"_","/"),IF(Len(aRegex)<5,"",aRegex[5]),aFiles[nF,1]})
      ELSE 
         Aadd(oBrowse:aData,{"????","",aFiles[nF,1]})
      ENDIF
   NEXT

   oBrowse:AddColumn(TBColumn():New(Pad("Artikel",25)+" "+Pad("Revision",10)+" "+Pad("Datei",64),{|| 
      IF Len(oBrowse:aData) > 0
         RETURN Pad(oBrowse:CurrentDataRow()[1],25)+" "+Pad(oBrowse:CurrentDataRow()[2],10)+" "+Pad(oBrowse:CurrentDataRow()[3],64)
      ENDIF
      RETURN "Keine SpezifikationsÑnderungen vorhanden"
   }))
   oBrowse:AddKey(K_ENTER,{|| 
      //WAPI_ShellExecute(,"open",oFileBrowse:CurrentDataRow()[3])         
      RETURN .T.
   })    
   Aadd(aBrowse,{oBrowse,SaveEnv()})



   bChangeBrowse := {|nNew|
      oBrowse:deHilite()
      aBrowse[nActiveBrowse,2] := SaveEnv()
      nActiveBrowse := nNew
      oBrowse := aBrowse[nActiveBrowse,1]
      RestEnv(aBrowse[nActiveBrowse,2],.F.)
      oBrowse:Display()
      RETURN NIL
   }

   IF Len(aBrowse) > 0
      FOR nX := 1 TO Len(aBrowse)
         aBrowse[nX,1]:lBox := .F.
         oBrowse:lArrow := .F.
         aBrowse[nX,1]:Display()
         aBrowse[nX,1]:deHilite()
      NEXT
      oBrowse := aBrowse[nActiveBrowse,1]
      RestEnv(aBrowse[nActiveBrowse,2],.F.)
      oBrowse:Display()
   ENDIF


   DO WHILE nKey != 27
      IF oBrowse == NIL .OR. oBrowse:Stable
         nKey := Inkey(0)
         IF (nKey == K_LBUTTONDOWN .AND. (nB := AScan(aButtons,{|oButton|oButton:HitTest(MRow(),MCol()) != 0})) != 0) .OR.;
         (! Empty(Chr(nKey)) .AND. (nB := AScan(aButtons,{|oButton| aRegex:= HB_Regex("\&([A-Za-z÷‹ƒˆ¸‰])",oButton:Caption), Len(aRegex) > 0 .AND. Upper(aRegex[2]) == Upper(Chr(nKey))} )) != 0)
            oButton := aButtons[nB]
            oButton:setFocus()
            oButton:select()
            oButton:killFocus()
         ELSEIF Len(aBrowse) > 0
            IF nKey == K_TAB
               IF nActiveBrowse < Len(aBrowse)
                  Eval(bChangeBrowse,nActiveBrowse+1)
               ELSE
                  Eval(bChangeBrowse,1)
               ENDIF
            ELSEIF nKey == K_SH_TAB .AND. nActiveBrowse > 1
               Eval(bChangeBrowse,nActiveBrowse-1)
            ELSEIF nKey == K_LBUTTONDOWN .AND. ((oBrowse:ClassName == "TBROWSETR" .AND. ! oBrowse:HitTest()) .OR. (oBrowse:ClassName == "TABROWSE" .AND. oBrowse:HitTest(mRow()+1,mcol()) == 0))
               FOR nX := 1 TO Len(aBrowse)
                  IF nX != nActiveBrowse .AND. ((aBrowse[nX,1]:ClassName == "TBROWSETR" .AND. aBrowse[nX,1]:HitTest()) .OR. (aBrowse[nX,1]:ClassName == "TABROWSE" .AND. aBrowse[nX,1]:HitTest(mrow()+1,mcol()) != 0))
                     Eval(bChangeBrowse,nX)
                  ENDIF
               NEXT
               LOOP
            ENDIF
      
            oBrowse:Event({nKey})
         ENDIF

      ELSE
         oBrowse:Display()
      ENDIF
   ENDDO

RETURN .T.

FUNCTION __AddApprReq()
   LOCAL aEnv := SaveEnv()
   LOCAL oRec := areq->(Record():New(.T.))
   LOCAL getlist := {}
   LOCAL hContact
   LOCAL cText, cSubject
   LOCAL cFile
   LOCAL cKunde := Space(8)
   LOCAL hRcvs := {=>},aEmails,nB
   LOCAL cCC := Space(255)

   MEMVAR c_four,c_four_list
  

   oRec:Zeichnung := Ltrim(Str(nr_zeich->Nummer,6))   

   SetColor(c_four)

   @ 10,45 CLEAR TO 31,85
   @ 10,45 TO 31,85 DOUBLE

   @ 11,46 SAY "Revision" GET oRec:ZeichIndex VALID {||
      IF areq->(dbSeek(oRec:Zeichnung+oRec:ZeichIndex))
         @ 11,64 SAY "bereits vorhanden"
         RETURN .F.
      ENDIF
      areq->(dbSeek(oRec:Zeichnung+oRec:ZeichIndex , .T. ))
      IF areq->Zeichnung == oRec:Zeichnung .AND. oRec:ZeichIndex < areq->ZeichIndex
         @ 11,64 SAY Pad("alter Index",17)
         RETURN .F.
      ENDIF
      @ 11,64 SAY Space(17)      
      cFile := Hook("get_drawingfile",{.F.,Pad(LTrim(Str(nr_zeich->Nummer,6)),30),oRec:ZeichIndex,.F.})

      IF Empty(cFile)
         Tr_MsgBox("Zeichnung nicht gefunden")
         RETURN .F.
      ENDIF
   
      RETURN .T.
   }

   READ

   IF LastKey() == 27 
      RestEnv(aEnv,.T.)
      RETURN .T.
   ENDIF

   NetUse("buyer","buy")
   buy->(dbSetFilter({|| buy->Aktive .AND. ! Empty(buy->Email) },"Active .AND. ! Empty(Email)"))
   buy->(dbGoTop())

   DO WHILE ! buy->(EOF())
      hRcvs[Trim(buy->Buyer)] = Trim(buy->Email)      
      buy->(dbSkip())
   ENDDO

   
   buy->(dbClearFilter())
   

   ppf->(dbSetOrder( 4 ))
   ppfd->(dbSetOrder( 4 ))

   ppf->(dbSeek( Pad(LTrim(Str(nr_zeich->Nummer,6)),30)+oRec:Zeichindex ))
   DO WHILE Trim(ppf->Zeichnung) == Ltrim(Str(nr_zeich->Nummer,6)) .AND. Trim(ppf->ZeichIndex) == Trim(oRec:ZeichIndex) .AND. ! ppf->(EOF()) //look for drawing approval
      IF ppfd->(dbSeek( Str(ppf->Nummer,10)+"UNTK"+"Y" )) //this approval has a drawing approval   
         IF Tr_MsgBox("Vorhandene Freigabe Åbernehemn (keine neu Anforderung versenden)?",,{"abbrechen","Ja"}) == 1
            RestEnv(aEnv,.T.)
            RETURN .F.
         ENDIF

         oRec:UUID := win_UuidCreateString()
         oRec:Approved := .T. 
         oRec:Address := ppfd->Address
         oRec:Contact := ppfd->Contact
         oRec:Datum := ppfd->Datum

         oRec:Type := "UNTK"
         oRec:User  := SystemUser():Id
         oRec:Save()
      
         RestEnv(aEnv,.T.)
         oRec:GotoRec()
         RETURN .T.
      
      ENDIF
      ppf->(dbSkip())
   ENDDO

   @ 12,46 SAY "Kunde   " GET cKunde PICTURE "@!" VALID {|| 
      IF FindAd(cKunde,"K",15,46)
         oRec:Address := ku->Nummer
         RETURN .T.
      ENDIF
      RETURN .F.
   }
   @ 13,46 SAY "Person" 
   GET_Contact(getlist,13,55,{|v| If(v==NIL,oRec:Contact,oRec:Contact:=v)},,{||
      hContact := GetContact(oRec:Contact)
      IF Empty(hContact["email"])
         Tr_MsgBox("Kontakt hat keine Emailadresse")
         RETURN .F.
      ENDIF
      RETURN .T.                 
   },,c_four_list) //,<.noblank.>,<{valid}>, <{when}>,<color>

   @ 14,46 SAY "CC"
   @ 14,55 GET cCC SUGGESTIONS HGetKeys(hRcvs) PICTURE "@S30" VALID Empty(cCC) .OR. HHasKey(hRcvs,Trim(cCC))
   READ

   IF LastKey() == 27 .OR. Tr_MsgBox("Freigabeanforderung anlegen und versenden?",,{"Ja","Nein"}) != 1
      RestEnv(aEnv,.T.)
      RETURN .T.  
   ENDIF

   aEmails := {}
   Aadd(aEmails,{hContact["email"],hContact["name"]})
   //Aadd(aEmails,{"amos.engelking@engelking.de",hContact["name"]})
   IF ! Empty(cCC)
      Aadd(aEmails,{hRcvs[Trim(cCC)],cCC})
   ENDIF

   oRec:Datum := Date()
   oRec:Type := "UNTK"
   oRec:UUID := win_UuidCreateString()
   oRec:User  := SystemUser():Id
   oRec:Save()  

   LoadEmailTemplate("zeichnung",ku->Language,.F.,@cText,hContact,{;
      "approval_link"=>'https://portal.engelking.com/link/drawing/'+oRec:UUID;
   },,"UTF-8")

   IF ku->Language != "D"
      cSubject := "Drawing No. "+Ltrim(Str(nr_zeich->Nummer,6))+IF(!Empty(oRec:ZeichIndex),"-"+Trim(oRec:ZeichIndex),"")+" for Approval"
   ELSE
      cSubject := "Zeichnung Nr. "+Ltrim(Str(nr_zeich->Nummer,6))+IF(!Empty(oRec:ZeichIndex),"-"+Trim(oRec:ZeichIndex),"")+" zur Freigabe"
   ENDIF
   
   SendMail(aEmails,cSubject,cText,{cFile,{"x:\images\engelking-logo-white.png","cid:engelking-logo"}},,,.T.,"info@engelking.de",.F.,.F.)   
   
   RestEnv(aEnv,.T.)
   
   oRec:GotoRec()
RETURN .T.


STATI FUNC GET_DRAWINGFILES( nZeich )

   LOCAl aDir,nX,nPos,nPos2,cInd
   LOCAL aSearch,nS
   LOCAL aFiles,cZeich,nF
   LOCAL aData := {}
   
   aDir := {"\\EK-SERVER4\Data\Technik\Prozessdoku\"}
   Aadd(aDir,aDir[1]+"obsolete\")

   cZeich := LTrim(Str(nZeich))
   aSearch := {cZeich+"*_*.*","0"+cZeich+"*_*.*"}
  
   FOR nX := 1 TO Len(aDir)
      FOR nS := 1 TO Len(aSearch)
         
         aFiles := Directory(aDir[nX]+aSearch[nS])
         
         FOR nF := 1 TO Len(aFiles)
            nPos := At(cZeich,aFiles[nF,1])+3 //+Len(cZeich)
            nPos2 := At("_",aFiles[nF,1])
            IF nPos2 == 0
               nPos2 := RAt(".",aDir[nF,1])
            ENDIF
            IF nPos != 0
               cInd := StrTran(SubStr(aFiles[nF,1],nPos+1,nPos2-nPos-1),"-","")
            ELSE
               cInd := ""
            ENDIF
            IF AScan(aData,{|x| x[1] == cInd}) == 0
               Aadd(aData,{cInd,aFiles[nF,1],aDir[nX]+aFiles[nF,1]})
            ELSE
               //Alert("Zwei Dateien fÅr eine Revision")
            ENDIF
            
         NEXT
      NEXT
   NEXT

   ASort(aData,,,{|a,b| a[1] < b[1] })

RETURN aData

FUNCTION __DeleteApprReq()
   LOCAL aEnv := SaveEnv()
   LOCAL lConfirm := .F.
   
   IF areq->(EOF()) .OR. areq->(BOF())
      RestEnv(aEnv,.T.)
      RETURN .F.
   ENDIF
   
   // Confirm deletion without customer notification
   IF Tr_MsgBox({"Freigabeanforderung lîschen?","Der Kunde wird NICHT informiert."},,{"Abbrechen","Lîschen"}) == 2
      lConfirm := .T.
   ENDIF
   
   IF lConfirm
      areq->(Rec_Lock())
      areq->(dbDelete())
      areq->(dbUnLock())
      areq->(dbSkip())
      IF areq->(EOF())
         areq->(dbSkip(-1))
      ENDIF
   ENDIF
   
   RestEnv(aEnv,.T.)
   RETURN .T.


/**
   Send specification change notification
**/

STATIC FUNCTION _SendSCN  
      LOCAL getlist := {}
      LOCAL aEnv := SaveEnv()
      LOCAL hContact,nContact,nAddress
      LOCAL cKunde := Space(8)
      LOCAL lStop := .F., lBOM := .F.
      LOCAL oScnDoc,cPdfPath,aPdfProps,oPdfProp,oServiceManager
      MEMVAR c_four,c_four_list

      

      SetColor(c_four)

      @ 10,45 CLEAR TO 31,85
      @ 10,45 TO 31,85 DOUBLE

      @ 10,46 SAY "[ SpezifikationsÑnderungsmitteilung ]"

      @ 12,46 SAY "Lieferant" GET cKunde PICTURE "@!" VALID {|| 
         IF FindAd(cKunde,"L",16,46)
            nAddress := ku->Nummer
            RETURN .T.
         ENDIF
         RETURN .F.
      }
      @ 13,46 SAY "Person" 
      GET_Contact(getlist,13,56,{|v| If(v==NIL,nContact,nContact:=v)},,{||
         hContact := GetContact(nContact)
         IF Empty(hContact["email"])
            Tr_MsgBox("Kontakt hat keine Emailadresse")
            RETURN .F.
         ENDIF
         RETURN .T.                 
      },,c_four_list) 
      @ 14,46 SAY "Produktionsstop       " GET lStop PICTURE "Y"
      @ 15,46 SAY "énderung in StÅckliste" GET lBOM PICTURE "Y"
      READ

      IF LastKey() == 27 
         RestEnv(aEnv,.T.)
         RETURN .T.
      ENDIF

      oScnDoc := OpenOOWriterTemplate('Y:\Dokumente und Einstellungen\All Users\Dokumente\Vorlagen\QM\fb123_SpezifikationsÑnderungsmitteilung_1.5.ott',{;
         'Lieferant'=>Trim(Trim(ku->Name1)+" "+ku->Name2),;         
         'ProductionstopYes'=>IF(lStop,"X",""),;
         'ProductionstopNo'=>IF(!lStop,"X",""),;
         "BOMYes"=>IF(lBOM,"X",""),;
         "BOMNo"=>IF(!lBOM,"X",""),;
         "Artikel"=>Trim(art->Matchcode),;
         "Zeichnungsnummer"=>Trim(art->Zeichnung),;
         "Zeichnungsrevision"=>Trim(art->Zeichindex);
      },.F.)
      
      // Export the document to PDF
      IF ValType(oScnDoc) == "O"
         
         cPdfPath := PATH_SCN+"SCN_"+StrTran(Trim(art->Matchcode),"/","_")+"_"+Trim(art->Zeichnung)+IF(!Empty(art->Zeichindex),"-"+Trim(art->Zeichindex),"")+"_"+DToS(Date())+"_"+StrTran(Time(),":","")+".pdf"
         aPdfProps := {}
         
         // Get the service manager (should already be available since we used OpenOOWriterTemplate)
         oServiceManager := CreateObject("com.sun.star.ServiceManager")
         
         IF ValType(oServiceManager) == "O"
            // Create property for PDF export filter
            Aadd(aPdfProps,OOProperty(oServiceManager, "FilterName", "writer_pdf_Export"))
               
            // Export to PDF using storeToURL
            oScnDoc:storeToURL("file:///"+StrTran(cPdfPath,"\","/"), aPdfProps)
            
            Tr_MsgBox("PDF wurde erstellt: "+cPdfPath)
            
            // Open the PDF file
            WAPI_ShellExecute(,"open",cPdfPath)
         ELSE
            Tr_MsgBox("Fehler beim Zugriff auf den Service Manager")
         ENDIF
      ELSE
         Tr_MsgBox("Fehler beim Erstellen des OpenOffice-Dokuments")
      ENDIF
      oScnDoc:close(.F.) // Close the document without saving changes

      RestEnv(aEnv,.T.)
   RETURN .T.