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
'   /test     Varianten nacheinander pruefen (siehe TeamTalkTest unten)
'
' Teilnehmer werden als Address-Objekt aus dem lokalen bzw. globalen
' Adressbuch eingetragen (Suche ueber EMail). Als E-Mail-Text eingetragene
' Teilnehmer liessen StartChat mit 80004005 scheitern, Adressbuch-Objekte
' funktionieren (DavidTeamTalk.exe, TeamChat).
'
' Ausgabe: "OK <ThreadID>" oder "FEHLER <Schritt>: <Code> <Text>",
' Exitcode 0 bzw. 1 - fuer hb_processRun in der aufrufenden Aktion.
Option Explicit
Dim args, mailPfad, archivPfad, betreff, an, text
Dim api, acc, arch, msg, cm, addrs, th, a, adr
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
Set msg = Nothing
If mailPfad <> "" Then
  Set msg = MailNachPfad(arch, mailPfad)
Else
  Set msg = MailNachBetreff(arch, betreff)
End If
If msg Is Nothing Then Fehler "Mail", "nicht gefunden"
WScript.Echo "Mail: " & msg.Subject
Set cm = CreateObject("DVOBJAPILib.ChatManager")
Pruefe "ChatManager"
If args.Exists("test") Then TeamTalkTest
Set addrs = acc.CreateAddressList()
Pruefe "CreateAddressList"
For Each a In Split(an, ",")
  If Trim(a) <> "" Then
    Set adr = AdresseSuchen(acc, Trim(a))
    If adr Is Nothing Then Fehler "Adresse " & Trim(a), "in keinem Adressbuch gefunden"
    addrs.Add adr
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
  On Error Resume Next   ' gilt in VBScript nur je Prozedur
  Set MailNachPfad = Nothing
  Err.Clear
  Set kandidat = Nothing
  Set kandidat = arch.GetArchiveEntryById(pfad)
  If Err.Number = 0 And IsObject(kandidat) Then
    If Not kandidat Is Nothing Then
      Set MailNachPfad = kandidat
      Exit Function
    End If
    WScript.Echo "GetArchiveEntryById: kein Objekt zurueck"
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
  Set kandidat = MailNachEintragsId(arch, pfad)
  If Not kandidat Is Nothing Then
    Set MailNachPfad = kandidat
    Exit Function
  End If
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

' Mail ueber die Eintrags-ID der MailItems finden (wie crm_email.prg ueber
' _ID): Die _ID wird mit Dateiname bzw. Pfad der Mail verglichen. Die ersten
' Werte werden ausgegeben, damit das Format sichtbar ist.
Function MailNachEintragsId(arch, pfad)
  Dim items, i, it, id, datei, n
  On Error Resume Next
  Set MailNachEintragsId = Nothing
  datei = LCase(Mid(pfad, InStrRev(pfad, "\") + 1))
  Set items = arch.MailItems
  If Err.Number <> 0 Then
    WScript.Echo "MailItems: " & Hex(Err.Number) & " " & Err.Description
    Exit Function
  End If
  n = 0
  For i = 0 To items.Count - 1
    Err.Clear
    Set it = items.Item(i)
    id = ""
    id = CStr(it.[_ID])
    If Err.Number = 0 Then
      If n < 3 Then WScript.Echo "  _ID[" & i & "] = " & id
      n = n + 1
      If LCase(id) = LCase(pfad) Or LCase(id) = datei Or InStr(1, id, datei, vbTextCompare) > 0 Then
        WScript.Echo "Gefunden ueber _ID: " & id
        Set MailNachEintragsId = it
        Exit Function
      End If
    ElseIf i = 0 Then
      WScript.Echo "  _ID nicht lesbar: " & Hex(Err.Number) & " " & Err.Description
    End If
  Next
  WScript.Echo "Keine _ID passt zu " & datei & " (" & n & " Eintraege gelesen)"
End Function

' Mail im Archiv ueber einen Teil des Betreffs suchen (genau ein Treffer).
Function MailNachBetreff(arch, teil)
  Dim items, i, it, treffer, n
  On Error Resume Next
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

' Address-Objekt zu einer E-Mail-Adresse aus dem lokalen, globalen oder
' persoenlichen Adressbuch. Die Adressbuecher kennen nur Item(i)/Count.
Function AdresseSuchen(acc, email)
  Dim buch, name, i, it
  On Error Resume Next
  Set AdresseSuchen = Nothing
  For Each name In Array("LocalAddressBook", "GlobalAddressBook", "PersonalAddressBook")
    Err.Clear
    Set buch = Nothing
    Set buch = Eval("acc." & name)
    If Err.Number = 0 And Not buch Is Nothing Then
      For i = 0 To buch.Count - 1
        Err.Clear
        Set it = buch.Item(i)
        If Err.Number = 0 Then
          If LCase(Trim(it.EMail)) = LCase(email) Then
            WScript.Echo "Adresse " & email & ": " & name & "[" & i & "] " & it.DisplayName
            Set AdresseSuchen = it
            Exit Function
          End If
        End If
      Next
    End If
  Next
  Err.Clear
End Function

' Probiert StartChat an der Mail in mehreren Varianten, jeweils mit leerer
' Teilnehmerliste (wie das Doku-Beispiel, das funktioniert) und danach mit
' den Teilnehmern aus /an. Jede erfolgreiche Variante sendet die
' Testnachricht in ihren Thread. Unterschiede zum Doku-Beispiel:
'   1 Mail wie bisher (GetArchive(Pfad).GetArchiveEntryById)
'   2 Archiv ueber GetSpecialArchive(DvArchivePersonalIn) statt GetArchive
'   3 Mail vorher speichern (Save), wie im Doku-Beispiel
'   4 Mail ueber GetArchiveEntries("Default").Item(i), Abgleich ueber _ID
Sub TeamTalkTest()
  Dim m, eingang, items, i, it, id, voll, a, adr
  On Error Resume Next
  id = ""
  id = CStr(msg.[_ID])
  WScript.Echo "Mail _ID: " & id & ", Typ " & msg.Type & ", Archiv " & msg.Parent.FullPath
  Err.Clear
  Set voll = acc.CreateAddressList()
  For Each a In Split(an, ",")
    If Trim(a) <> "" Then
      Set adr = AdresseSuchen(acc, Trim(a))
      If Not adr Is Nothing Then voll.Add adr Else WScript.Echo "Adresse " & Trim(a) & ": nicht gefunden"
    End If
  Next
  Err.Clear

  Variante "1 GetArchive", msg, voll

  Set eingang = acc.GetSpecialArchive(101)          ' DvArchivePersonalIn
  If Err.Number <> 0 Then
    WScript.Echo "FEHLER GetSpecialArchive(101): " & Hex(Err.Number) & " " & Err.Description
    Err.Clear
  Else
    WScript.Echo "Posteingang: " & eingang.FullPath
    Set m = Nothing
    Set m = eingang.GetArchiveEntryById(mailPfadVoll(mailPfad))
    If Err.Number <> 0 Or m Is Nothing Then
      WScript.Echo "FEHLER Posteingang GetArchiveEntryById: " & Hex(Err.Number) & " " & Err.Description
      Err.Clear
    Else
      Variante "2 GetSpecialArchive", m, voll
    End If
  End If

  msg.Save
  If Err.Number <> 0 Then
    WScript.Echo "FEHLER Save: " & Hex(Err.Number) & " " & Err.Description
    Err.Clear
  Else
    Variante "3 nach Save", msg, voll
  End If

  Set items = arch.GetArchiveEntries("Default")
  If Err.Number <> 0 Then
    WScript.Echo "FEHLER GetArchiveEntries: " & Hex(Err.Number) & " " & Err.Description
    Err.Clear
  Else
    Set m = Nothing
    For i = 0 To items.Count - 1
      Err.Clear
      Set it = items.Item(i)
      If Err.Number = 0 Then
        If CStr(it.[_ID]) = id Then
          Set m = it
          Exit For
        End If
      End If
    Next
    Err.Clear
    If m Is Nothing Then
      WScript.Echo "FEHLER GetArchiveEntries: _ID " & id & " nicht unter " & items.Count & " Eintraegen"
    Else
      Variante "4 GetArchiveEntries", m, voll
    End If
  End If
  WScript.Quit 0
End Sub

' Pfad mit Endung (.001), wie GetArchiveEntryById ihn ausserhalb des Clients braucht.
Function mailPfadVoll(p)
  If InStr(Mid(p, InStrRev(p, "\") + 1), ".") = 0 Then mailPfadVoll = p & ".001" Else mailPfadVoll = p
End Function

Sub Variante(name, m, voll)
  Dim t, liste, nr
  On Error Resume Next
  For nr = 1 To 2
    If nr = 1 Then
      Set liste = acc.CreateAddressList()
    Else
      Set liste = voll
    End If
    Err.Clear
    Set t = Nothing
    Set t = cm.StartChat(acc, liste, m)
    If Err.Number <> 0 Or t Is Nothing Then
      WScript.Echo "FEHLER " & name & IIf(nr = 1, " leer", " Teilnehmer") & ": " & Hex(Err.Number) & " " & Err.Description
    Else
      WScript.Echo "OK     " & name & IIf(nr = 1, " leer", " Teilnehmer") & ": Thread " & t.ID & ", LiveComment " & t.InstantComment
      t.SendMessage text & " (" & name & ")", 1
      If Err.Number <> 0 Then WScript.Echo "       SendMessage: " & Hex(Err.Number) & " " & Err.Description
      Err.Clear
      t.CloseThread
    End If
    Err.Clear
  Next
End Sub

Function IIf(b, x, y)
  If b Then IIf = x Else IIf = y
End Function

Sub Pruefe(schritt)
  If Err.Number <> 0 Then Fehler schritt, Hex(Err.Number) & " " & Err.Description
End Sub

Sub Fehler(schritt, info)
  WScript.Echo "FEHLER " & schritt & ": " & info
  WScript.Quit 1
End Sub
