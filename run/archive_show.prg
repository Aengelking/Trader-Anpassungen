Head("List Documents to Sales Order")


aFiles := Hook("get_archive_files",{"AB",4062},{})
aShow := {}
AEval(aFiles,{|aFile| Aadd(aShow,Pad(aFile[1],20)+" "+DToC(aFile[3])+" "+aFile[4]) })

nChoice := AChoice(00,00,MaxRow(),MaxCol(),aShow)
IF nChoice != 0
   Alert(aFiles[nChoice][6])
   IF File(aFiles[nChoice][6])
      Alert("File found!")
   ENDIF
   WAPI_ShellExecute(,"open",aFiles[nChoice][6])
ENDIF