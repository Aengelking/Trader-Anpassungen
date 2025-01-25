PROC RUN_TEST_PUTTY

LOCAL cPuttyPath := "C:\Program Files\PuTTY\"
LOCAL nStdIn,nStdOUT,nStdErr,nChild,nBytes
LOCAL cRead,cData


aCommands := {;           
   cPuttyPath+'\plink.exe tcos@192.168.2.185 -pw 0pen%TC "sudo mount /dev/sdb1 /media"',;
   cPuttyPath+'\plink.exe tcos@192.168.2.185 -pw 0pen%TC "ls /media/TESTER.RC"',;
      cPuttyPath+'\plink.exe tcos@192.168.2.185 -pw 0pen%TC "sudo umount /media"';
}
FOR nX := 1 TO Len(aCommands)
nChild := HB_OpenProcess( aCommands[nX], @nStdIn , @nStdOUT,@nStdErr,.F. )  //get the windows user information, of course this is not 100% secure as one could replace the whomai.exe

? "Process: "+Str(nChild)
              
IF nChild < 0
   
ELSE
   FWrite(nStdIn,"n")           
   HB_ProcessValue( nChild )
   //cRead := "!"
   cData := ""
   //DO WHILE (nVal := HB_ProcessValue( nChild,.F. )) < 0
      nBytes := 1000   
      DO WHILE nBytes == 1000
         cRead := Space(1000)
         nBytes := Fread( nStdErr, @cRead, Len(cRead) )
         cData += Left(cRead,nBytes)
      ENDDO
     // ? nVal
   //ENDDO
   //? nVal
   ? cData
   //Inkey(5,128)
   //? "Process Value: "+Str(HB_ProcessValue( nChild,.F. ))+Chr(13)+Chr(10)
ENDIF
NEXT

Sinkey(0)