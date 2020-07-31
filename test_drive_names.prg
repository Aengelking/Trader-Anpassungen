aDrives := {"W:"}
CLS
FOR nD := 1 TO Len(aDrives)
   ? aDrives[nD],GetVolInfo(aDrives[nD])
NEXT
? "done"
SInkey(0)