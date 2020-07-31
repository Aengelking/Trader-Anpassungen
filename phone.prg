PROCEDURE Phone
   LOCAL aParam := HB_AParams()
   LOCAL cPhone
   LOCAL cPhoneShort
   LOCAL cFilter
   LOCAL hContact
   LOCAL lD := Tr_Getini(28) == 9

   IF AT("#",aParam[1]) == 1
      aParam[1] := Substr(aParam[1],2)      
   ENDIF
   
   IF Len(aParam) >= 1 .AND. ValType(aParam[1]) == "C" .AND. AT("0",aParam[1]) == 1 
      NetUse("phonebook","pbk")
      pbk->(dbSetOrder(1))
      //Alert(NormalizeTelno(Substr(aParam[1],2)))
      cPhone := NormalizeTelno(Substr(aParam[1],2))
      IF lD
         Alert(cPhone)
      ENDIF
      IF pbk->(dbSeek( cPhone ))
         _ShowInfo()
      ELSE //number mot found, we will attempt finding the main number
         FOR nX := 1 TO 3 //max 3 digit extension
            cPhone := SubStr(cPhone,1,Len(cPhone)-IF(nX==1,1,2))+"0"
            IF pbk->(dbSeek( cPhone ))
               _ShowInfo()
               EXIT
            ENDIF
         NEXT
      ENDIF
      /*IF AT("0",aParam[1]) != 1 //using this for testing         
         cPhoneShort := "074649865"
         cPhone := cPhoneShort+aParam[1]
      ELSE
         cPhone := SubStr(aParam[1],2) //strip first zero 
         cPhoneShort := SubStr(cPhone,1,Len(cPhone)-2) //leave last two digits off
      ENDIF      
      NetUse("engkund","ku")
      ku->(dbSetOrder(2))
      cFilter := 'At("'+cPhoneShort+'",StrTran(StrTran(StrTran(StrTran(Telefon,"+","00"),"-",""),"/","")," ","")) != 0'
      ku->(dbSetFilter({|| &cFilter },cFilter))
      ku->(dbGoTop())
      DO WHILE ! ku->(EOF())
         IF Trim(_NormNumber(ku->Telefon)) == cPhone //main phone number of customer
            _ShowInfo()            
         ELSE //we need to go through the contacts
            FOR EACH hContact IN GetAddressContacts(,.T.)               
               IF _NormNumber(hContact["fullphone"]) == cPhone                  
                  _ShowInfo(hContact:__eNumKey())
                  RETURN
               ENDIF
            NEXT
         ENDIF
         ku->(dbSkip())
      ENDDO */    
      
   ENDIF

STATIC FUNCTION _ShowInfo(nContact)
   SetMode(48,90)
   CreateMainWindow()      
   CLS
   NetUse("engkund","ku")
   ku->(dbSetOrder(8))
   ku->(dbSeek(str(pbk->Address,6)))
   MBaseRun(Path("trd_02","MASK"),{pbk->Contact},.F.)
RETURN NIL

STATIC Function _NormNumber(cNumber)
RETURN StrTran(StrTran(StrTran(StrTran(cNumber,"+","00"),"-",""),"/","")," ","")
