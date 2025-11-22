#define CRLF Chr(13)+Chr(10)

PROCEDURE Hook_on_assign_todo(oTodo,lTrigger)
   LOCAL hTypes := GetRecordTypes() //{"QS"=>"Fehler","PJ"=>"Projekt"}
   LOCAL cText := ""
   LOCAL oProj
   LOCAL oUser := User():New()
   LOCAL cSubject
   LOCAL cRefType := Trim(oTodo:RefType)
   LOCAL cLink

   Default(@lTrigger,.F.)

   oUser:Load(oTodo:User)
   IF !lTrigger .AND. oUSer:ID == SystemUSer():ID
      RETURN
   ENDIF

   IF HHasKey(hTypes,Trim(oTodo:RefType))
      cText := Pad(hTypes[Trim(oTodo:RefType)],7) 
   ELSE
      cText := Pad(oTodo:RefType,7)
   ENDIF
   SWITCH cRefType 
      CASE "PJ"
         cLink := "Project_Edit("+Ltrim(Str(oTodo:Ref,6))+")"
         EXIT
      CASE "QS"
         cLink := "EditQS("+Ltrim(Str(oTodo:Ref,6))+")"
         EXIT
   END
   IF ! Empty(cLink)
      cText += ': <a href="trader: -F '+cLink+' -C 2">'+Ltrim(Str(oTodo:Ref,6))+'</a>'
   ELSE
      cText += ": "+Ltrim(Str(oTodo:Ref,6))
   ENDIF
   IF Trim(oTodo:RefType) == "PJ"
      oProj := Project():New()
      oProj:Load(oTodo:Ref)
      
      cText += CRLF+"Kunde: "+oProj:cKunde         
      cText += CRLF+"Beschreibung: "+oProj:Beschreibu
      IF ! Empty(oProj:Notes)
         cText += CRLF+"Notizen:"+CRLF+oProj:Notes      
      ENDIF

   ELSEIF Trim(oTodo:RefType) == "QS"
      NetUse("qs","qs")
      IF ! qs->(dbSeek( Str(oTodo:Ref,6) ))
         //Alert("QS No. not found")
         //RETURN
      ENDIF
      cText += CRLF+"Artikel:   "+qs->Matchcode
      cText += CRLF+"Lieferant: "+qs->Liefma
      cText += CRLF+"Kunde:     "+qs->Kunde
      cText += CRLF+"Beschreibung: "+qs->Beschreibu
   ENDIF

   cText += CRLF+CRLF+"Aufgabe: "+'<a href="trader: -F TodoList('+"'"+Trim(oTodo:UUID)+"'"+')" -C 2>'+Trim(oTodo:Task)+"</a>"
   cText += CRLF+"Notizen: "+oTodo:Notes 
   cText += CRLF+"F„llig:  "+DToC(oTodo:Due)

   IF ! Empty(oTodo:PreID)
      cText += CRLF+"Vorherige Aufgabe: "+oTodo:oPreTodo:Task
   ENDIF

   cSubject := "Neue Aufgabe"

   IF Trim(oTodo:RefType) == "PJ"
      cSubject += " #EAP "+Ltrim(Str(oTodo:Ref,6))
   ELSEIF Trim(oTodo:RefType) == "QS"
      cSubject += " #QS "+LTrim(Str(oTodo:Ref,6))
   ENDIF
   IF Tr_Getini(28) != 9 .OR. GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Aufgabe versenden?",Trim(oTodo:Task),{"Ja","Nein"}) == 1
      SendMail({{Trim(oUser:Email),Trim(oUser:Buyer)}},cSubject,cText)
   ENDIF

   //SendMail({{"amos.engelking@engelking.de",Trim(oUser:Buyer)}},cSubject,cText)
