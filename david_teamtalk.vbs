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
'
'   /mail  Archivpfad der Mail, z. B. \\ek-server3\david\archive\user\10004000\in\I44DE928.001
'   /an    Teilnehmer, Komma-getrennt (Standard: anliegen@engelking.de)
'   /text  erste Nachricht im TeamTalk
'
' Ausgabe: "OK <ThreadID>" oder "FEHLER <Schritt>: <Code> <Text>",
' Exitcode 0 bzw. 1 - fuer hb_processRun in der aufrufenden Aktion.
Option Explicit
Dim args, mailPfad, an, text, api, acc, arch, msg, cm, addrs, th, a
Set args = WScript.Arguments.Named
mailPfad = args("mail")
an = args("an")
If an = "" Then an = "anliegen@engelking.de"
text = args("text")
If text = "" Then text = "Test Anliegen eroeffnen [#EK-ATEST]. Bitte ignorieren."
If mailPfad = "" Then Fehler "Aufruf", "/mail fehlt"

On Error Resume Next
Set api = CreateObject("DVOBJAPILib.DvISEAPI")
Pruefe "DvISEAPI"
Set acc = api.GetAccount()
Pruefe "GetAccount"
Set arch = acc.GetArchive(Left(mailPfad, InStrRev(mailPfad, "\") - 1))
Pruefe "GetArchive"
Set msg = arch.GetArchiveEntryById(mailPfad)
Pruefe "GetArchiveEntryById"
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

Sub Pruefe(schritt)
  If Err.Number <> 0 Then Fehler schritt, Hex(Err.Number) & " " & Err.Description
End Sub

Sub Fehler(schritt, info)
  WScript.Echo "FEHLER " & schritt & ": " & info
  WScript.Quit 1
End Sub
