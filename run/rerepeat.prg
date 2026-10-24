#include 'inkey.ch'
PROC Run_Edit_ReRepeat
   LOCAL oBrowse

   IF ! SystemUser():CheckPermission("R","PURCHASEINVOICE_REPEAT")
      RETURN
   ENDIF

   Head("Wiederkehrende Rechnungen")
   NetUse("rerepeat","rerep")
   NetUSe("engkund","ku")

   LX_Start()

   oBrowse := rerep->(TBrowseTr():New(03,00,MaxRow()-11,MaxCol()))
   oBrowse:OneColumn := .T.

   oBrowse:NewColumn("Konto",{||
      LOCAL cName
      cName := Str(rerep->Konto,6)+" "+Pad(LX_GetAccountName(rerep->Konto),50)
      RETURN cName

      },,8,"999999",0,{|x| Str(x,6) })

   oBrowse:NewColumn("Betrag",{||
      RETURN Transform(rerep->Betrag,"@E 9,999,999.99")   
   })
      
   oBrowse:NewColumn("Intevall",{||
      LOCAL cIntervall
      IF rerep->Intervall=="M" 
         cIntervall := "monatlich"         
      ELSEIF rerep->Intervall=="H"
         cIntervall := "halbj„hrlich"          
      ELSEIF rerep->Intervall=="J"
         cIntervall := "j„hrlich"          
      ELSE
         cIntervall := "?"
      ENDIF
      RETURN Pad(cIntervall,12)
   })

   oBrowse:NewColumn("Letzte",{||
      RETURN DtoC(rerep->Last)
   })


   oBrowse:NewColumn("N„chste",{||      
      LOCAL dNext
      IF rerep->Intervall=="M"          
         dNext := AddMonth(rerep->Last,1)
      ELSEIF rerep->Intervall=="H"         
         dNext := AddMonth(rerep->Last,6)
      ELSEIF rerep->Intervall=="J"         
         dNext := AddMonth(rerep->Last,12)
      ELSE
         dNext := StoD("")
      ENDIF
      RETURN DtoC(dNext)
   })

   oBrowse:NewColumn("Ende",{||
      RETURN DtoC(rerep->End)
   })
   
   
      
   IF SystemUser():HasPermission("U","PURCHASEINVOICE_REPEAT")
      oBrowse:AddKey(K_ENTER,{|| 
         LOCAL oRec := rerep->(Record():New())
         oRec:Last := GetBox(oRec:Last,"Datum letzte Rechnung setzen")
         IF LastKey() != 27
            oRec:Save()
         ENDIF
         RETURN .T.
      })

      oBrowse:AddKey(K_DEL,{|| 
         LOCAL oRec := rerep->(Record():New())
         oRec:End := GetBox(oRec:End,"Enddatum setzen")
         IF LastKey() != 27
            oRec:Save()
         ENDIF
         RETURN .T.
      })
   ENDIF

   oBrowse:AddKey(27,{|| .F. })
   oBrowse:EventLoop()
   