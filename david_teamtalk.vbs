' david_teamtalk.vbs - TeamTalk an einer David-Mail starten
'
' Fuer "Anliegen eroeffnen" (Rechtsklick in David, crm_email.prg Modus issue):
' Trader ruft das Skript auf, um den TeamTalk mit dem Anliegen-Agenten an der
' ORIGINAL-Mail zu starten. Der Umweg ueber VBScript ist noetig, weil
' CreateObject("DVOBJAPILib.ChatManager") aus Harbour mit E_FAIL scheitert.
'
' Zwei Voraussetzungen (siehe tools/DavidTeamTalk):
'  - Die Mail braucht eine JobID. Ohne sie scheitert StartChat mit 80004005.
'    David vergibt sie beim ersten Klick in das TeamTalk-Feld; das David-
'    Skript common.vbs prueft das vor dem Aufruf von Trader.
'  - Teilnehmer muessen Address-Objekte aus einem Adressbuch sein. Als
'    E-Mail-Text (Addresses.Add "x@y", ...) scheitert StartChat ebenfalls.
'
' Aufruf (32 Bit wie Trader):
'   C:\Windows\SysWOW64\cscript.exe //nologo david_teamtalk.vbs /mail:"<Mailpfad>" [/an:"a@x,b@y"] [/text:"..."]
'
'   /mail  Archivpfad der Mail wie aus dem David-Kontext, z. B.
'          \\ek-server3\david\archive\user\10004000\in\I44DE928
'          (ohne Endung wird .001 angehaengt - ausserhalb des Clients noetig)
'   /an    Teilnehmer, Komma-getrennt (Standard: inga@engelking.de)
'   /text  erste Nachricht im TeamTalk
'
' Ausgabe: "OK <ThreadID>" oder "FEHLER <Schritt>: <Text>",
' Exitcode 0 bzw. 1 - fuer hb_processRun in der aufrufenden Aktion.
Option Explicit
Dim args, mailPfad, an, text
Dim api, acc, arch, msg, cm, addrs, th, a, adr, job
Set args = WScript.Arguments.Named
mailPfad = args("mail")
an = args("an")
If an = "" Then an = "inga@engelking.de"
text = args("text")
If mailPfad = "" Then Fehler "Aufruf", "/mail angeben"
If InStr(Mid(mailPfad, InStrRev(mailPfad, "\") + 1), ".") = 0 Then mailPfad = mailPfad & ".001"

On Error Resume Next
Set api = CreateObject("DVOBJAPILib.DvISEAPI")
Pruefe "DvISEAPI"
Set acc = api.GetAccount()
Pruefe "GetAccount"
Set arch = acc.GetArchive(Left(mailPfad, InStrRev(mailPfad, "\") - 1))
Pruefe "GetArchive"
Set msg = arch.GetArchiveEntryById(mailPfad)
Pruefe "Mail " & mailPfad
job = 0
job = CLng(msg.Fields.Item("JobID").Value)
Err.Clear
If job = 0 Then Fehler "Mail", "keine JobID - bitte einmal in das TeamTalk-Feld der Mail klicken"

Set addrs = acc.CreateAddressList()
Pruefe "CreateAddressList"
For Each a In Split(an, ",")
  If Trim(a) <> "" Then
    Set adr = AdresseSuchen(acc, Trim(a))
    If adr Is Nothing Then Fehler "Teilnehmer " & Trim(a), "in keinem Adressbuch gefunden"
    addrs.Add adr
    Pruefe "Teilnehmer " & Trim(a)
  End If
Next

Set cm = CreateObject("DVOBJAPILib.ChatManager")
Pruefe "ChatManager"
Set th = cm.StartChat(acc, addrs, msg)
Pruefe "StartChat"
If text <> "" Then
  th.SendMessage text, 1              ' 1 = DvTextPlain
  Pruefe "SendMessage"
End If
th.CloseThread
WScript.Echo "OK " & th.ID
WScript.Quit 0

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
            Set AdresseSuchen = it
            Exit Function
          End If
        End If
      Next
    End If
  Next
  Err.Clear
End Function

Sub Pruefe(schritt)
  If Err.Number <> 0 Then Fehler schritt, Hex(Err.Number) & " " & Err.Description
End Sub

Sub Fehler(schritt, info)
  WScript.Echo "FEHLER " & schritt & ": " & info
  WScript.Quit 1
End Sub
