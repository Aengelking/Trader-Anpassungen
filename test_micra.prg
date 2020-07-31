#define HB_SOCKET_AF_INET                 2
#define HB_SOCKET_ERR_TIMEOUT             2
//include 'hbsocket.ch'

#define ADDRESS                     "192.168.2.92"

#define PORT                        9100
#define SOH                         Chr( 1 )
#define ETB                         Chr( 23 )
#define RECV_TIMEOUT                100           // 1s

if empty( hSocket := hb_socketOpen() )
    ? "socket create error " + hb_ntos( hb_socketGetError() )
endif
if !hb_socketConnect(hSocket, { HB_SOCKET_AF_INET, ADDRESS, PORT } )
    ? "socket connect error " + hb_ntos( hb_socketGetError() )
endif

//PRINT FILE - works!
/*cData := MemoRead("Y:\Dokumente und Einstellungen\Amos\Eigene Dateien\test.prn")
CLS
DO WHILE (nEnd := At(Chr(13),cData)) != 0
   cLine := SubStr(cData,1,nEnd-1)
   cData := SubStr(cData,nEnd+2)
   ? hb_socketSend(hSocket,cLine)
ENDDO*/

? "Drucke..."
DO WHILE Inkey(1,128) == 0
   __Send(hSocket,"SE")
   cStatus := __Recv(hSocket)
   IF cStatus == "#Idle"
      ? "READY"
   ELSE
      ? cStatus
   ENDIF
ENDDO

? __Send(hSocket,"FD----r0-------") //druck anhalten
? __Send(hSocket,"FD----r2-------") //druck stoppen

 hb_socketShutdown( hSocket )
 hb_socketClose( hSocket )

/*SET PRINTER ON
SET PRINTER TO X:\run\test.prn
?? Chr(1)+"FD----r0-------"+Chr(23)
? Chr(1)+"FD----r2-------"+Chr(23)
SET PRINTER OFF
SET PRINTER TO*/

STATIC Function __Send(hSocket,cCmd)
RETURN hb_socketSend(hSocket,SOH+cCmd+ETB)


STATIC Function __Recv(hSocket)
   LOCAL cRequest := ""
   LOCAL nLen := 1
   LOCAL cBuf

   DO WHILE at( Chr(23), cRequest ) == 0 .and. nLen > 0
      cBuf := space( 4096 )
      IF ( nLen := hb_socketRecv( hSocket, @cBuf, , , RECV_TIMEOUT ) ) > 0
          cRequest += left( cBuf, nLen )
      ELSE
          IF nLen == -1 .AND. hb_socketGetError() == HB_SOCKET_ERR_TIMEOUT
              ? "Timeout"
              nLen := 0
          ENDIF
      ENDIF
   ENDDO
   IF nLen == -1
      ? "hb_socketRecv error " + hb_ntos( hb_socketGetError() )
   ELSEIF nLen == 0
      ? "connection closed"
   ENDIF
RETURN cRequest
