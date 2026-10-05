' david_teamtalk.vbs - TeamTalk an einer David-Mail starten
'
' Fuer "Anliegen eroeffnen" (Rechtsklick in David, siehe crm_email.prg):
' Die Harbour-Aktion haengt den Token [#EK-A<n>] an den Betreff des Originals
' und ruft danach dieses Skript auf, das den TeamTalk mit dem Anliegen-Agenten
' startet. Der Umweg ueber VBScript ist noetig, weil CreateObject(
' "DVOBJAPILib.ChatManager") aus Harbour mit E_FAIL scheitert, aus VBScript
' aber funktioniert (geprueft mit DvApi32 12.0, test_david_teamtalk.prg).
'
' Aufruf (32 Bit wie Trader):
'   C:\Windows\SysWOW64\cscript.exe //nologo david_teamtalk.vbs /mail:"<Mailpfad>" [/an:"a@x,b@y"] [/text:"..."]
'   C:\Windows\SysWOW64\cscript.exe //nologo david_teamtalk.vbs /archiv:"<Archivpfad>" /betreff:"<Teil des Betreffs>" [...]
'
'   /mail     Archivpfad der Mail, z. B. \\ek-server3\david\archive\user\10004000\in\I44DE928.001
'   /archiv   Archiv fuer /betreff, z. B. \\ek-server3\david\archive\user\10004000\in
'   /betreff  Mail im Archiv ueber einen eindeutigen Teil des Betreffs suchen
'   /an       Teilnehmer, Komma-getrennt (Standard: anliegen@engelking.de)
'   /text     erste Nachricht im TeamTalk
'
' Ausgabe: "OK <ThreadID>" oder "FEHLER <Schritt>: <Code> <Text>",
' Exitcode 0 bzw. 1 - fuer hb_processRun in der aufrufenden Aktion.
Option Explicit
Dim args, mailPfad, archivPfad, betreff, an, text
Dim api, acc, arch, msg, cm, addrs, th, a
Set args = WScript.Arguments.Named
mailPfad = args("mail")
archivPfad = args("archiv")
betreff = args("betreff")
an = args("an")
If an = "" Then an = "anliegen@engelking.de"
text = args("text")
If text = "" Then text = "Test Anliegen eroeffnen [#EK-ATEST]. Bitte ignorieren."
If mailPfad <> "" Then archivPfad = Left(mailPfad, InStrRev(mailPfad, "\") - 1)
If mailPfad = "" And (betreff = "" Or archivPfad = "") Then Fehler "Aufruf", "/mail oder /archiv mit /betreff angeben"

On Error Resume Next
Set api = CreateObject("DVOBJAPILib.DvISEAPI")
Pruefe "DvISEAPI"
Set acc = api.GetAccount()
Pruefe "GetAccount"
WScript.Echo "Angemeldet als: " & acc.User.Name & " (" & acc.User.ID & ")"
Err.Clear
Set arch = acc.GetArchive(archivPfad)
Pruefe "GetArchive"
WScript.Echo "Archiv: " & arch.DisplayName & " / " & arch.FullPath & " / " & arch.MailItems.Count & " Mails"
Err.Clear
If mailPfad <> "" Then
  Set msg = MailNachPfad(arch, mailPfad)
Else
  Set msg = MailNachBetreff(arch, betreff)
End If
If msg Is Nothing Then Fehler "Mail", "nicht gefunden"
WScript.Echo "Mail: " & msg.Subject
Set cm = CreateObject("DVOBJAPILib.ChatManager")
Pruefe "ChatManager"
Set addrs = acc.CreateAddressList()
Pruefe "CreateAddressList"
For Each a In Split(an, ",")
  If Trim(a) <> "" Then
    addrs.Add Trim(a), Trim(a), 0   ' 0 = DvAddressEMail
    Pruefe "Add " & Trim(a)
  End If
Next
Set th = cm.StartChat(acc, addrs, msg)
Pruefe "StartChat"
WScript.Echo "Thread " & th.ID & ", LiveComment " & th.InstantComment
th.SendMessage text, 1              ' 1 = DvTextPlain
Pruefe "SendMessage"
th.CloseThread
Pruefe "CloseThread"
WScript.Echo "OK " & th.ID
WScript.Quit 0

' Mail ueber ihren Dateipfad holen. Schlaegt das fehl, melden, ob die Datei
' existiert, und Dateien mit gleichem Stamm (I44DE928.*) versuchen - der Name
' kann sich nach einem Speichern (z. B. geaendertem Betreff) aendern.
Function MailNachPfad(arch, pfad)
  Dim fso, ordner, stamm, f, kandidat, sa
  Set MailNachPfad = Nothing
  Err.Clear
  Set kandidat = arch.GetArchiveEntryById(pfad)
  If Err.Number = 0 Then
    Set MailNachPfad = kandidat
    Exit Function
  End If
  WScript.Echo "GetArchiveEntryById: " & Hex(Err.Number) & " " & Err.Description
  Err.Clear
  ' Zweiter Weg laut DvAPI32-Doku: ItemFromID mit dem vollen Pfad
  ' (vSa "for internal use only", 34 oder 99).
  For Each sa In Array(34, 99)
    Err.Clear
    Set kandidat = arch.ItemFromID(pfad, sa)
    If Err.Number = 0 Then
      If Not kandidat Is Nothing Then
        WScript.Echo "Gefunden ueber ItemFromID(" & sa & ")"
        Set MailNachPfad = kandidat
        Exit Function
      End If
    End If
    WScript.Echo "ItemFromID(" & sa & "): " & Hex(Err.Number) & " " & Err.Description
  Next
  Err.Clear
  Set fso = CreateObject("Scripting.FileSystemObject")
  WScript.Echo "Datei vorhanden: " & fso.FileExists(pfad)
  stamm = LCase(fso.GetBaseName(pfad))
  Set ordner = fso.GetFolder(fso.GetParentFolderName(pfad))
  If Err.Number <> 0 Then
    WScript.Echo "Ordner nicht lesbar: " & Hex(Err.Number) & " " & Err.Description
    Err.Clear
    Exit Function
  End If
  For Each f In ordner.Files
    If LCase(fso.GetBaseName(f.Name)) = stamm And LCase(f.Path) <> LCase(pfad) Then
      Err.Clear
      Set kandidat = arch.GetArchiveEntryById(f.Path)
      If Err.Number = 0 Then
        WScript.Echo "Gefunden unter: " & f.Path
        Set MailNachPfad = kandidat
        Exit Function
      End If
      WScript.Echo "  " & f.Path & ": " & Hex(Err.Number)
    End If
  Next
  Err.Clear
End Function

' Mail im Archiv ueber einen Teil des Betreffs suchen (genau ein Treffer).
Function MailNachBetreff(arch, teil)
  Dim items, i, it, treffer, n
  Set MailNachBetreff = Nothing
  Err.Clear
  Set items = arch.MailItems
  If Err.Number <> 0 Then
    WScript.Echo "MailItems: " & Hex(Err.Number) & " " & Err.Description
    Err.Clear
    Exit Function
  End If
  n = 0
  For i = 0 To items.Count - 1
    Set it = items.Item(i)
    If Err.Number = 0 Then
      If InStr(1, it.Subject, teil, vbTextCompare) > 0 Then
        n = n + 1
        Set treffer = it
        WScript.Echo "Treffer: " & it.Subject
      End If
    End If
    Err.Clear
  Next
  If n = 1 Then
    Set MailNachBetreff = treffer
  Else
    WScript.Echo n & " Treffer fuer '" & teil & "' - bitte eindeutiger"
  End If
End Function

Sub Pruefe(schritt)
  If Err.Number <> 0 Then Fehler schritt, Hex(Err.Number) & " " & Err.Description
End Sub

Sub Fehler(schritt, info)
  WScript.Echo "FEHLER " & schritt & ": " & info
  WScript.Quit 1
End Sub
