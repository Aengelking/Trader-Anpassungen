
#define CRLF Chr(13)+Chr(10)
PROC Test_Timebutler_Orga()
   LOCAL oAPI := TimeButlerAPI():New()
   LOCAL aUsers
	? "Benutzer werdern heruntergeladen..."
   aUsers := oAPI:Execute("users")
   Timbutler_orga(aUsers)
RETURN

PROC Timbutler_orga(aUsers)	
   LOCAL nX
   LOCAL aGroups := {}
   LOCAL hF
   LOCAL cManagerKey := "User ID list of the user's manager (comma separated list, in case more than one user ID exists)"
   LOCAL cManager
   LOCAL aData := {}

   LOCAL hAvatars := {=>}
   LOCAL aExternal := {}

   hAvatars[9] := "https://timebutler.de/images/avatar//9/372469-26128-c4d6408f263886172e79b2360d6896c7.jpg?v=4"
   hAvatars[62] := "https://timebutler.de/images/avatar//9/514109-26128-8b9b30785a05ad883480a4fdf5e32a23.jpg?v=1"
   hAvatars[47] := "https://timebutler.de/images/avatar//8/374358-26128-f3404894f6f836fddd69ff1b2703fa5a.jpg?v=3"
   //hAvatars[] := "https://timebutler.de/images/avatar//6/628146-26128-08ef4f318e96423988ff1a3d5bc3c35a.jpg?v=2"
   hAvatars[58] := "https://timebutler.de/images/avatar//9/374359-26128-3a1b95e83be37dd357cc47b9ad495dfb.jpg?v=1"
   
   Aadd(aExternal,{"name"=>"Jochen Zoller","function"=>"QM-beauftragter"})
   Aadd(aExternal,{"name"=>"Mustafa Koc","function"=>"Sicherheitsbeauftrager"})
   
   CLS
   
   IF ! HHasKey(aUsers[Len(aUsers)],"First name") //we seem to get an empty user at the end of the list which we ignore      
      HB_Adel(aUsers,Len(aUsers),.T.)
   ENDIF
   
   AEval(aUsers,{|x| 
      IF ! Empty(x["User ID"]) .AND. x["User ID"] == x[cManagerKey]
         x["level"] := 0
         __CreateLevels(aUsers,0,x["User ID"])
      ENDIF
      RETURN .T.
   })
   ASort(aUsers,,,{|x,y| x["level"] < y["level"]})

   FOR nX := 1 TO Len(aUsers)
      IF ! aUsers[nX]['User account locked']
         ? aUsers[nX]["First name"],aUsers[nX]["Department"],aUsers[nX][cManagerKey],aUsers[nX]["User ID"]         

         IF ! aUsers[nX]["Department"] $ aGroups
            Aadd(aGroups,aUsers[nX]["Department"])
            //FWrite(hF,'chart.addGroup("Top", "'+aUsers[nX]["Department"]+'" ,"'+ aUsers[nX]["Department"]+'")'+CRLF)
         ENDIF
         IF !Empty(aUSers[nX][cManagerKey]) .AND. aUsers[nX][cManagerKey] != aUSers[nX]["User ID"]
            cManager := '"'+LTrim(Str(aUSers[nX][cManagerKey]))+'"'
         ELSE
            cManager := "undefined"
         ENDIF
            //'+aUsers[nX]["Department"]+'
         //FWrite(hF,'chart.addNode("Top", '+cManager+', "'+LTrim(Str(aUsers[nX]["User ID"]))+'", "'+aUsers[nX]["First name"]+" "+aUsers[nX]["Last name"]+'", ["'+aUsers[nX]["Department"]+'"]);'+CRLF)
//? hAvatars[aUsers[nX]["Employee number"]]
//? ValToPrg(aUsers[nX])
         Aadd(aData,{;
            "name"=>aUsers[nX]["First name"]+" "+aUsers[nX]["Last name"],;
            "fire"=>IF(AT("Brandschutzhelfer",aUsers[nX]["Additional Information"]) > 0,.T.,.F.),;
            "rescue"=>IF(AT("Ersthelfer",aUsers[nX]["Additional Information"]) > 0,.T.,.F.),;
            "imageUrl"=>IF(aUsers[nX]["Employee number"]$hAvatars,hAvatars[aUsers[nX]["Employee number"]],"https://timebutler.de/images/avatar/noavatar.png"),;
            "area"=>aUsers[nX]["Department"],;
            "employee"=>aUsers[nX]["Employee number"],;
            "id"=>aUsers[nX]["User ID"],;
            "phone"=>aUsers[nX]["Phone"],;
            "mobile"=>aUsers[nX]["Mobile phone"],;
            "parentId"=>IF(!Empty(aUSers[nX][cManagerKey]) .AND. aUsers[nX][cManagerKey] != aUSers[nX]["User ID"],aUsers[nX][cManagerKey],"");
         })

         
      ENDIF

   NEXT

   nX := AScan(aUsers,{|x| x["level"] == 1})
   IF nX > 0
      FOR nY := 1 TO Len(aExternal)
         Aadd(aData,{;
            "name"=>aExternal[nY]["name"]+" (ext.)",; 
            "imageUrl"=>"https://timebutler.de/images/avatar/noavatar.png",;           
            "area"=>aExternal[nY]["function"],;
            "employee"=>"",;
            "id"=>"ext_"+LTrim(Str(nY)),;
            "parentId"=>aUsers[nX][cManagerKey];
         })
      NEXT
   ENDIF

   
   hF := HB_FCreate("x:\www\orga.json")
   FWrite(hF,HB_JsonEncode(aData))
   fClose(hF)
   

   STATIC FUNCTION __CreateLevels(aUsers,nLevel,cManager)
      LOCAL cManagerKey := "User ID list of the user's manager (comma separated list, in case more than one user ID exists)"
      AEval(aUsers,{|x| 
         IF x[cManagerKey] == cManager
            IF x["User ID"] != cManager
               x["level"] := nLevel+1          
               __CreateLevels(aUsers,nLevel+1,x["User ID"])
            ENDIF
         ENDIF
         RETURN .T.
      })
      RETURN NIL


   //#include "x:\run\timebutlerapi.prg"