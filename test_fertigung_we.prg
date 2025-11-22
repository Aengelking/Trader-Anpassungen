NetUse("werkauf","wer")
NetUse("artikel","art")
wer->(dbSeek(Str(13703,6)))
art->(dbSetOrder(2))
art->(dbSeek( Str(wer->Artno),6))
oWerk := WA():new()

Hook("after_fertigung_we",{oWerk,426})