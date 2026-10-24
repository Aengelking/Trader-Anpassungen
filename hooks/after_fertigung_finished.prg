#define CRLF Chr(13)+Chr(10)
FUNCTION HOOK_on_fertigung_finished(nAufno)
   LOCAL cText := "Auftrag: "+LTrim(Str(nAufno))+CRLF
   NetUSe("artikel","art")
   art->(dbSeek(wer->Matchcode))
   cText += "Artikel: "+wer->Matchcode+CRLF
   cText += "Menge: "+Transform(wer->Qty,Me(art->Me))+" "+art->Me
   MailConnect()
   SendMail({{"chris.chertes@engelking.de","Chris"}/*,{"amos.engelking@engelking.de","Amos","BCC"}*/},"Fertigungsauftrag "+LTrim(Str(nAufno))+" abgeschlossen",cText)
RETURN .T.