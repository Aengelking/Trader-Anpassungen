
Sub Initialize(oInfoCenter, key)
	Set oBar = oInfoCenter.GetCommandBar("Menu/entries")
	oBar.Insert "Extras/#start", "Separator",,,, true
	oBar.Insert "Extras/#start", "Werksbescheinigung archivieren", key, 88, "OnTrader", true, "coc"
'	oBar.Insert "Extras/#start", "Rechnung", key, 88, "OnTrader", true, "engre"
	oBar.Insert "Extras/#start", "Eingangsrechnung archivieren", key, 88, "OnTrader", true, "invoice"
	oBar.Insert "Extras/#start", "Gesprächsnotiz erstellen" , key, 88, "OnTrader", true, "notiz"
   'MBaseRun(Trim(Tr_getini(1))+'\run\notiz')"
	oBar.Insert "Extras/#start", "Separator",,,, true
'	oBar.Insert "Extras/#start", "Bestellbestätigung", key, 88, "OnTrader", true, "bestchk"
	oBar.Insert "Extras/#start", "Bestellbestätigung einlesen", key, 88, "OnTrader", true, "beschk"
	oBar.Insert "Extras/#start", "Angebot einlesen (Lieferant)", key, 88, "OnTrader", true, "quote"
	oBar.Insert "Extras/#start", "Separator",,,, true
   'MBaseRun(Trim(Tr_getini(1))+'\run\BesChk',{'%filename%'})"
	oBar.Insert "Extras/#start", "Angebot erstellen", key, 88, "OnTrader", true, "enquiry"
	oBar.Insert "Extras/#start", "Auftrag erstellen", key, 88, "OnTrader", true, "auftrag"
	oBar.Insert "Extras/#start", "Auftrag über Angebot erstellen", key, 88, "OnTrader", true, "angebot"
   oBar.Insert "Extras/#start", "Separator",,,, true
   oBar.Insert "Extras/#start", "An Lead/Opportunity anhängen", key, 88, "OnTrader", true, "crm"
   oBar.Insert "Extras/#start", "Anliegen eröffnen", key, 88, "OnTrader", true, "issue"
	

'	Set oBar = oInfoCenter.GetCommandBar("Main/Global")
'	oBar.Insert 4, "Test Button", key, "root.ico", "OnTestButton", true
'	oBar.Insert 1, "ungelesen", key, 1, "OnAddFile", true

'	Set oBar = oInfoCenter.GetCommandBar("Main/Search")
'	oBar.Insert 4, "Test Button", key, "root.ico", "OnTestButton", true
'oInfoCenter.MsgBox oBar.Name

	Set oBar = oInfoCenter.GetCommandBar("Main/WebSearch")
   'oBar.Insert -1,"Trader Suche", key, "engelking_emblem.ico", "OnSearch", true

  'Set oBar = oInfoCenter.GetCommandBar("MessageView/Standard")
  'oBar.Insert 4, "Ablage", key, "ablage.ico", "OnAuftragNew", true


	Set oBar = oInfoCenter.GetCommandBar("MessageEditor/Standard")
	oBar.Insert 4, "Dokument hinzufügen", key, 1, "OnAddFile", true
End Sub

Sub OnSearch(oInfoCenter,oContext)
   Set WShell = CreateObject( "WScript.Shell" )

   WShell.Exec("C:\\Program Files (x86)\\Trader\\bin\\start.exe -S 4x39 -WC -NM -F MBaseRun(Trim(Tr_getini(1))+'\run\david_search',{'""" & oInfoCenter.ArchiveTree.SelectedArchive.ID & """'})")
End Sub

Sub OnTrader(oInfoCenter, oReader )
'   On Error Resume Next

  Set WShell = CreateObject( "WScript.Shell" )
  Set fso = CreateObject("Scripting.FileSystemObject")
  temp = WShell.ExpandEnvironmentStrings("%TEMP%")

  Set oEntryList = oInfoCenter.EntryList
  Set oSelection = oEntryList.Selection

  Set oItem = oSelection.Item(0)
  Set oMsgItem = oItem.GetInterface2
  Set oArchive = oMsgItem.Parent

  If oMsgItem.Type = DvEmailItem then
      Set oItem2 = oArchive.GetArchiveEntryById(oMsgItem.Fields.Item("FileName").Value) 'oMsgItem.ChangeType(DvUnknownItem)
      fname = oMsgItem.Subject
  elseIf oMsgItem.Type = DvFaxItem then
      Set oItem2 = oArchive.ItemFromID(oMsgItem.Fields.Item("FileName").Value,34)
      fname = oMsgItem.Fields("SRFrom").Value
  else
      oInfoCenter.MsgBox "Nur Emails und Faxe können übergeben werden"
      Exit Sub
  end if

  ' Anliegen eroeffnen: erst an Trader uebergeben, wenn die Mail eine JobID hat
  ' (ohne JobID scheitert der TeamTalk mit dem Agenten, siehe AnliegenBereit)
  if oInfoCenter.CurrentCommandEvent.Param = "issue" then
      if oMsgItem.Type <> DvEmailItem then
         oInfoCenter.MsgBox "Anliegen können nur aus E-Mails eröffnet werden.", 0
         Exit Sub
      end if
      if Not AnliegenBereit(oInfoCenter, oArchive, oMsgItem) then Exit Sub
  end if

  'create unique file name
  'On Error Resume Next
  undsc = Array("\","*","/")
  blank = Array(":","?","-","""","<",">","|","–","®","(",")")
  for Each i in undsc
   fname = Replace(fname,i,"_")
  next
  for Each i in blank
   fname = Replace(fname,i," ")
  next

  for i=1 to len(fname)
      char = Asc(mid(fname,i,1))
      
      If char < 32  OR char > 122 OR (char >= 58 AND char <= 64) OR (char >= 91 AND char <= 96) or char = 41 then
         fname = mid(fname,1,i-1) & "_" & mid(fname,i+1)
      end if
   next

  fadd = ""
  fno = 0
  Do while fso.FileExists(temp & "\" & fname & fadd & ".eml")
     fno = fno+1
     fadd = "_" & CStr(fno)
  Loop
  fname = fname&fadd

  'export data
   if oMsgItem.Type = DvEmailItem then
      If oMsgItem.Fields("SRFrom").Value = "scanner@engelking.de" then  'bei gescannten dokumenten wird nur der Anhang übergeben
      On Error Resume Next
         fname = fname & ".pdf"
         oMsgItem.Attachments(0).CopyOut temp , fname
   if Err.Number <> 0 then
      oInfoCenter.MsgBox "Error: " & Err.Description '& Err.Line
   end if

      else
         fname = fname & ".eml"
         Set oConverter = oInfoCenter.Account.CreateExporter
         Set oCollection = oConverter.GetCollection
         oCollection.Add oItem2
         'oInfoCenter.MsgBox "FormatEML: " & CStr(FormatEML)
         oConverter.Convert FormatEML,  temp & "\" & fname
      end if
      Set objShell = CreateObject("Shell.Application")
      objShell.NameSpace(temp).ParseName(fname).ModifyDate = oItem2.Fields("StatusTime").Value 'DateAdd("d", -1, Now())
   elseIf oMsgItem.Type = DvFaxItem then
      fname = fname & ".tif"
      fso.CopyFile oItem2.image,temp & "\" & fname
   end if
   cmd  = TraderExe(fso)
   if oInfoCenter.CurrentCommandEvent.Param = "crm" or oInfoCenter.CurrentCommandEvent.Param = "issue" then
      cmd = cmd & " -G"  'the CRM uses webview for the UI, so we need to use the GUI mode of trader.exe
   end if
   cmd = cmd & " -F MBaseRun(Trim(Tr_getini(1))+'\run\david_context',{'" &  oInfoCenter.CurrentCommandEvent.Param & "','" & oMsgItem.Fields.Item("FileName").Value &"'}) -A """ & temp & "\" & fname & """"
   WShell.Exec(cmd)
   Set WShell = Nothing
end sub

' Trader.exe aus dem Programmverzeichnis, sonst x:\prg\start.exe
Function TraderExe(fso)
   TraderExe = "C:\\Program Files (x86)\\Trader\\bin\\trader.exe"
   if Not fso.FileExists("C:\Program Files (x86)\Trader\bin\trader.exe") then TraderExe = "x:\prg\start.exe"
End Function

' Anliegen eroeffnen braucht eine Mail im persoenlichen Postfach mit JobID:
' Der TeamTalk mit dem Agenten (IChatManager.StartChat) scheitert an Mails
' ohne JobID. Die JobID vergibt David, sobald man in das TeamTalk-Feld der
' Mail klickt. Die Meldung des Clients sperrt das Fenster, deshalb nur ein
' Hinweis: schliessen, ins TeamTalk-Feld klicken, Aktion erneut waehlen.
Function AnliegenBereit(oInfoCenter, oArchive, oMsgItem)
   AnliegenBereit = False
   datei = oMsgItem.Fields.Item("FileName").Value
   if InStr(1, datei, "\archive\user\", vbTextCompare) = 0 then
      oInfoCenter.MsgBox "Anliegen können nur aus dem persönlichen Postfach eröffnet werden." & vbCrLf & _
         "Bitte die Mail zuerst in dein Postfach verschieben.", 0
      Exit Function
   end if
   info = ""
   job = JobId(oArchive, oMsgItem, datei, info)
   if job <> 0 then
      AnliegenBereit = True
      Exit Function
   end if
   oInfoCenter.MsgBox "Diese Mail hat noch keinen TeamTalk." & vbCrLf & vbCrLf & _
      "Bitte diese Meldung schließen, einmal in das TeamTalk-Feld der Mail" & vbCrLf & _
      "klicken (nichts schreiben) und 'Anliegen eröffnen' erneut wählen." & vbCrLf & vbCrLf & _
      "(" & info & ")", 0
End Function

' JobID lesen: erst am Objekt der Auswahl, dann frisch aus dem Archiv (die
' Auswahl kann veraltet sein). info sammelt, was gelesen wurde - fuer die
' Fehlersuche, falls die Meldung trotz JobID kommt.
Function JobId(oArchive, oMsgItem, datei, info)
   On Error Resume Next
   JobId = 0
   wert = Empty
   Err.Clear
   wert = oMsgItem.Fields.Item("JobID").Value
   if Err.Number <> 0 then
      info = "Auswahl: Fehler " & Hex(Err.Number) & " " & Err.Description
   else
      info = "Auswahl: " & TypeName(wert) & " '" & CStr(wert) & "'"
      if IsNumeric(wert) then JobId = CLng(wert)
   end if
   if JobId <> 0 then Exit Function
   Err.Clear
   Set oFrisch = Nothing
   Set oFrisch = oArchive.GetArchiveEntryById(datei)
   if Err.Number <> 0 or oFrisch Is Nothing then
      info = info & "; Archiv: Fehler " & Hex(Err.Number) & " " & Err.Description
   else
      Err.Clear
      wert = Empty
      wert = oFrisch.Fields.Item("JobID").Value
      if Err.Number <> 0 then
         info = info & "; Archiv: Fehler " & Hex(Err.Number) & " " & Err.Description
      else
         info = info & "; Archiv: " & TypeName(wert) & " '" & CStr(wert) & "'"
         if IsNumeric(wert) then JobId = CLng(wert)
      end if
   end if
   Err.Clear
End Function

Sub OnAddFile(oInfoCenter,oContext)
	On Error Resume Next
	Set WShell = CreateObject( "WScript.Shell" )
	Set oExec = WShell.Exec("C:\\Program Files (x86)\\Trader\\bin\\trader.exe -M -R david_file")
	Do While oExec.Status = 0
     		System.Threading.Thread.Sleep(100)
	Loop
   oContext.ExecCommand "InsertAttachment", CreateObject( "HTMLFile" ).parentWindow.clipboardData.getData( "Text" )
   	
	
end sub

Sub OnTestButton(oInfoCenter, oContent)
	oInfoCenter.MsgBox "Hallo Welt vom InfoCenter"

	'Set oArcTree = oInfoCenter.ArchiveTree
	'oArcTree.SearchItems "Test", CLng("&h" & oMask), -1, -1, true, false
End Sub