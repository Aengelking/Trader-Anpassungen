#include 'y:\hb32\include\inkey.ch'

PROC RUN_SPECCL_EDIT
   LOCAL oBrowse
   LOCAL cComment 
   LOCAL getlist := {}
   
   IF ! SystemUser():CheckPermission("U","ADR_CUSTOMER_SPECCREDITLIMIT")
      Return
   Endif

   NetUse("speccl","spcl",.F.,0)
   NetUse("engkund","ku",.F.,0)

   //update customer names for searching
   ku->(dbSetOrder(8))
   spcl->(dbGoTop())
   DO WHILE ! spcl->(EOF())
      spcl->(Rec_Lock(0))
      IF ku->(dbSeek(Str(spcl->KuNr,6)))
         spcl->Kunde := ku->Kunde
      ELSE
         spcl->Kunde := ""
      ENDIF
      spcl->(dbUnLock())
      spcl->(dbSkip())
   ENDDO

   Head("Special Credit Limits")
   spcl->(dbGoTop())
   oBrowse := spcl->(TBrowseTr():New(02,00,MaxRow()-1,MaxCol()))
   oBrowse:lBox := .F.

   oBrowse:OneColumn := .T.
   //NewColumn( cHead, bColumn, bColorBlock,nIndexOrder,cSearchPic,xDefault,bSeek )
   oBrowse:NewColumn("Kdn.Nr.",{|| Str(spcl->KuNr,6) },,1,"999999",0,{|x| Str(x,6) })
   oBrowse:NewColumn("Kunde",{|| spcl->Kunde},,2,"@K!",Space(8),{|x| x })
   oBrowse:NewColumn("Special Limit",{|| Transform(spcl->SpecLimit,"999,999.99")})
   //oBrowse:NewColumn("Valid From",{|| DToC(spcl->ValidFrom) })
   oBrowse:NewColumn("Valid Until",{|| IF(Empty(spcl->ValidUntil),"Unlimited",DToC(spcl->ValidUntil)) })
   oBrowse:NewColumn("Active",{|| IF(spcl->Active,"Yes","No") })

   oBrowse:AddKey(K_ESC,{|| .F. })
   oBrowse:AddKey(K_ENTER,{|| _SpecCLEdit(.F.),.T. })
   oBrowse:AddKey(K_INS,{|| _SpecCLEdit(.T.),.T. })
   oBrowse:AddKey(K_DEL,{||
      IF Tr_MsgBox(t("Delete special credit limit?"),,{"No","Yes"}) == 2
         cComment := Space(100)
         @ 10,10 CLEAR TO 15,70
         @ 10,10 TO 15,70
         @ 11,12 SAY "Reason for deletion:"
         @ 12,12 GET cComment PICTURE "@S55"
         READ
         IF ! Empty(AllTrim(cComment))
            _AddComment(spcl->(Recno()),"DELETED: " + AllTrim(cComment))
            spcl->(Rec_Lock())
            spcl->(dbDelete())
            spcl->(dbUnLock())
            spcl->(dbSkip())
         ENDIF
      ENDIF
      RETURN .T.
   })
   oBrowse:AddKey(K_F3,{|| _ShowComments(), .T. })
   oBrowse:AddKey(K_F9,{|| ku->(dbSeek(Str(spcl->KuNr,6))), enaddr() })

   @ MaxRow(),0 SAY "F3=Full Comments F9=Customer INS=New ENTER=Edit DEL=Delete ESC=Exit"

   oBrowse:EventLoop()

RETURN

STATIC FUNCTION _DeleteSpecCL()
   LOCAL cComment := Space(100)
   LOCAL getlist := {}
   
   IF Tr_MsgBox(t("Delete special credit limit?"),,{"No","Yes"}) == 2
      @ 10,10 CLEAR TO 15,70
      @ 10,10 TO 15,70
      @ 11,12 SAY "Reason for deletion:"
      @ 12,12 GET cComment PICTURE "@S55"
      read
      IF ! Empty(AllTrim(cComment))
         _AddComment(spcl->(Recno()),"DELETED: " + AllTrim(cComment))
         spcl->(Rec_Lock())
         spcl->(dbDelete())
         spcl->(dbUnLock())
         spcl->(dbSkip())
      ENDIF
   ENDIF
RETURN .T.

STATIC FUNCTION _SpecCLEdit(lNew)
   LOCAL cGroup,cKunde,nKuNr
   LOCAL cComment := Space(254)
   LOCAL getlist := {}
   LOCAL nRec := spcl->(Recno())
   LOCAL oRec
   LOCAL nOldLimit := 0
   LOCAL lLimitChanged
   LOCAL cNewComment
   LOCAL lRet

   MEMVAR c_four

   If ValType(lNew) != "L"
      lNew := .F.      
   Endif
   
   oRec := spcl->(Record():New(lNew))

   ku->(dbSetOrder( 8 ))
   If ! lNew
      ku->(dbSeek(Str(spcl->KuNr,6)))
      nOldLimit := spcl->SpecLimit
   Endif

   cKunde := If(lNew,Space(8),ku->Kunde)
   cGroup := If(lNew,"K",ku->Group)
   nKuNr  := If(lNew,0,spcl->KuNr)

   SetColor(c_four)

   @ 5,5 CLEAR TO MaxRow()-2,MaxCol()-5
   @ 5,5 TO MaxRow()-2,MaxCol()-5

   @ 6,7 SAY "Special Credit Limit Editor"

   @ 8,7 SAY "Customer"
   @ 8,22 GET cKunde PICTURE "@!" WHEN lNew VALID {|| lRet := Findad(cKunde,"K",8,43),nKuNr := ku->Nummer,lRet .AND. (lNew .OR. nKuNr == spcl->KuNr) }
   
   If ! lNew
      Eval(Atail(getlist):postBlock)
   Endif

   @ 9,7 SAY "Special Limit"
   @ 9,22 GET oRec:SpecLimit PICTURE "9999999.99" VALID oRec:SpecLimit >= 0

   //@ 10,7 SAY "Valid From"
   //@ 10,22 GET oRec:ValidFrom VALID ! Empty(oRec:ValidFrom)

   @ 10,7 SAY "Valid Until"
   @ 10,22 GET oRec:ValidUntil VALID Empty(oRec:ValidUntil) .OR. oRec:ValidUntil > oRec:ValidFrom

   @ 11,7 SAY "Active"
   @ 11,22 GET oRec:Active PICTURE "Y"

   @ 13,7 SAY "New Comment (required for changes):"
   @ 14,7 GET cComment PICTURE ("@S" + AllTrim(Str(MaxCol()-16))) VALID {||
      IF Empty(AllTrim(cComment))
         Tr_MsgBox("Comment is required when creating or changing credit limits!")
         RETURN .F.
      ENDIF
      RETURN .T. 
   }

   // Display existing comments
   IF ! lNew .AND. ! Empty(spcl->Comments)
      @ 16,7 SAY "Previous Comments:"
      _DisplayCommentsInEdit(17, 7, MaxCol()-13, MaxRow()-13-17+1)
   ENDIF


   READ

   // Check if limit was changed
   lLimitChanged := (lNew .OR. nOldLimit != oRec:SpecLimit)

   If Updated() .AND. (LastKey() != 27 .OR. Tr_MsgBox("Save changes?",,{"No","Yes"}) == 2)
      
      If lNew
         oRec:KuNr := nKuNr      
         oRec:Kunde := cKunde
         /*oRec:CreatedBy := SystemUser():Name
         oRec:CreatedDate := Date()
         oRec:CreatedTime := Time()*/
      Endif
      
      
      /*oRec:ModifiedBy := SystemUser():Name
      oRec:ModifiedDate := Date()
      oRec:ModifiedTime := Time()*/
      
      oRec:Save()

      // Add comment to memo field with timestamp if limit changed
      cNewComment := DToC(Date()) + " " + Time() + " [" + SystemUser():Name + "] "
      IF lNew
         cNewComment += "CREATED: Limit=" + Transform(oRec:SpecLimit,"999,999.99") + " - "
      ELSEIF nOldLimit != oRec:SpecLimit
         cNewComment += "CHANGED: " + Transform(nOldLimit,"999,999.99") + " -> " + Transform(oRec:SpecLimit,"999,999.99") + " - "
      ELSE
         cNewComment += "EXTENDED: Valid Until=" + DToC(oRec:ValidUntil) + " - "
      ENDIF
      cNewComment += AllTrim(cComment) + Chr(13) + Chr(10)
      

      oRec:Comments := cNewComment + IF(Empty(spcl->Comments),"",oRec:Comments)
      oRec:Save()
   Else
      spcl->(dbGoto(nRec))
   Endif

RETURN NIL

STATIC FUNCTION _DisplayCommentsInEdit(nStartRow, nStartCol, nWidth, nMaxLines)
   LOCAL aLines
   LOCAL i := 1
   LOCAL nRow := nStartRow
   
   IF ! Empty(spcl->Comments)
      aLines := _SplitMemo(spcl->Comments, nWidth)
      
      WHILE i <= Len(aLines) .AND. (nRow - nStartRow) < nMaxLines
         @ nRow, nStartCol SAY Left(aLines[i], nWidth)
         nRow++
         i++
      ENDDO
      
      IF i <= Len(aLines)
         @ nRow, nStartCol SAY "... (Press F3 for full comments)"
      ENDIF
   ELSE
      @ nStartRow, nStartCol SAY "No previous comments"
   ENDIF

RETURN NIL

STATIC FUNCTION _ShowComments()
   LOCAL cComments
   LOCAL nRow := 5   
   LOCAL aLines
   LOCAL i := 1
   
   IF ! Empty(spcl->Comments)
      cComments := spcl->Comments
   ELSE
      cComments := "No comments available for this record."
   ENDIF

   SetColor("W+/B")
   @ 4,5 CLEAR TO MaxRow()-5,MaxCol()-5
   @ 4,5 TO MaxRow()-5,MaxCol()-5
   @ 4,7 SAY " Comments for Customer: " + AllTrim(spcl->Kunde) + " "
   
   // Display comments line by line
   aLines := _SplitMemo(cComments, MaxCol()-12)
   
   WHILE i <= Len(aLines) .AND. nRow < MaxRow()-6
      @ nRow,7 SAY Left(aLines[i], MaxCol()-12)
      nRow++
      i++
   ENDDO
   
   @ MaxRow()-6,7 SAY "Press any key to continue..."
   Inkey(0)

RETURN NIL

STATIC FUNCTION _SplitMemo(cMemo, nWidth)
   LOCAL aLines := {}
   LOCAL cLine := ""
   LOCAL i := 1
   LOCAL c
   
   WHILE i <= Len(cMemo)
      c := SubStr(cMemo, i, 1)
      IF c == Chr(13) .OR. c == Chr(10)
         IF ! Empty(cLine)
            AAdd(aLines, cLine)
            cLine := ""
         ENDIF
      ELSEIF Len(cLine) >= nWidth
         AAdd(aLines, cLine)
         cLine := c
      ELSE
         cLine += c
      ENDIF
      i++
   ENDDO
   
   IF ! Empty(cLine)
      AAdd(aLines, cLine)
   ENDIF

RETURN aLines

STATIC FUNCTION _AddComment(nRecNo, cComment)
   LOCAL nCurrentRec := spcl->(Recno())
   LOCAL cNewComment
   
   spcl->(dbGoto(nRecNo))
   spcl->(Rec_Lock())
   
   cNewComment := DToC(Date()) + " " + Time() + " [" + SystemUser():Name + "] " + cComment + Chr(13) + Chr(10)
   spcl->Comments := cNewComment + IF(Empty(spcl->Comments),"",spcl->Comments)
   
   spcl->(dbUnLock())
   spcl->(dbGoto(nCurrentRec))

RETURN NIL
