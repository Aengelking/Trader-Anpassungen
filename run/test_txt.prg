CLS
cFile := "D:\trader30\pdf\AB005238_20070621.pdf"
cProtokoll := "D:\trader30\export\lexware_protocol_20101114_08-47-27.txt"
//? ShellExecute(NIL,"open",cFile,"","")
? ShellExecute(NIL,"open",cProtokoll,NIL,NIL)
__Run("notepad "+cProtokoll)
Inkey(0,128)