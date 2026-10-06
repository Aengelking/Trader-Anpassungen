
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

  ' Anliegen eroeffnen: laeuft ganz im CRM (Picker im Browser). Das CRM nimmt
  ' mit der David-Anmeldung des Benutzers Inga in den TeamTalk auf, schreibt
  ' die Anliegen-Nummer hinein und ergaenzt den Betreff (docs/kundenanliegen.md).
  if oInfoCenter.CurrentCommandEvent.Param = "issue" then
      if oMsgItem.Type <> DvEmailItem then
         oInfoCenter.MsgBox "Anliegen können nur aus E-Mails eröffnet werden.", 0
         Exit Sub
      end if
      AnliegenImCrm oInfoCenter, oMsgItem
      Exit Sub
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

' Anliegen eroeffnen: Picker im CRM mit Archivpfad, Absender und Betreff
' oeffnen. Nur Mails im persoenlichen Postfach: dort arbeitet das CRM mit der
' David-Anmeldung des Benutzers.
Sub AnliegenImCrm(oInfoCenter, oMsgItem)
   datei = oMsgItem.Fields.Item("FileName").Value
   if InStr(1, datei, "\archive\user\", vbTextCompare) = 0 then
      oInfoCenter.MsgBox "Anliegen können nur aus dem persönlichen Postfach eröffnet werden." & vbCrLf & _
         "Bitte die Mail zuerst in dein Postfach verschieben.", 0
      Exit Sub
   end if
   url = "https://nexus.engelking.it/picker/issue?mail=" & UrlKodieren(datei) & _
      "&email=" & UrlKodieren(oMsgItem.Fields.Item("SRFrom").Value) & _
      "&subject=" & UrlKodieren(oMsgItem.Subject)
   CreateObject("WScript.Shell").Run url
End Sub

' Prozent-Kodierung als UTF-8 (Umlaute im Betreff).
Function UrlKodieren(text)
   Dim i, c, r
   r = ""
   For i = 1 To Len(text & "")
      c = AscW(Mid(text, i, 1))
      If c < 0 Then c = c + 65536
      If (c >= 48 And c <= 57) Or (c >= 65 And c <= 90) Or (c >= 97 And c <= 122) Or c = 45 Or c = 46 Or c = 95 Or c = 126 Then
         r = r & ChrW(c)
      ElseIf c < 128 Then
         r = r & "%" & Right("0" & Hex(c), 2)
      ElseIf c < 2048 Then
         r = r & "%" & Hex(192 + (c \ 64)) & "%" & Hex(128 + (c Mod 64))
      Else
         r = r & "%" & Hex(224 + (c \ 4096)) & "%" & Hex(128 + ((c \ 64) Mod 64)) & "%" & Hex(128 + (c Mod 64))
      End If
   Next
   UrlKodieren = r
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