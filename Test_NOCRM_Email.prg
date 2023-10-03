PROC Test_NOCRM_Email(cMsgId)
   LOCAL nLeadID := 24247894
   LOCAL nActivity := 362518
   LOCAL oNoCRM := NoCrmAPi():New()
   LOCAL oAccount := DV_GetMailAccount(),cArchive,oArchive,oMsg
   LOCAL oUser := SystemUser()
   LOCAL cContent

   //cContent := MemoRead( GetConfigValue("attachfile") )
   cArchive := SubStr(cMsgId,1,RAT("\",cMsgId)-1)
   oArchive := oAccount:GetArchive(cArchive)
   oMsg := oArchive:GetArchiveEntryById(cMsgId)      

   
   cContent := oMsg:Fields("RTF"):Value
   //cContent := StrTran(cContent,"<","")
   //cContent := StrTran(cContent,">","")
   //cContent := "Hello World"+Chr(13)+Chr(10)+"Line2"
   //Alert(cContent)

   oNoCRM:Connect()
   //gtSetClipboard(oNoCrm:Execute("leads/"+LTrim(Str(nLeadID))+"/comments","GET")[1])
   
   //Alert( ValToPrg(oNoCrm:Execute("leads/"+LTrim(Str(nLeadID))+"/comments","GET")[1]) )

   oNoCrm:Execute("leads/"+LTrim(Str(nLeadID))+"/comments","POST",{"lead_id"=>nLEADID,"content"=>cContent,"activity_id"=>nActivity,"user_id"=>oUser:Email})

   #include 'x:\run\nocrm.prg'