PROC RUN_KundenPreisliste
   LOCAL cKunde := Space(8)
   LOCAL getlist := {}
   LOCAL aList := {},nX
   LOCAL cFileName

   Head("Kundenpreisliste als Excel")

   NetUse("angebot","ang")
   NetUse("artkund","aku")
   NetUse("engkund","ku")
   NetUse("artikel","art")

   DO WHILE .T.

      @ 01,00 SAY "Kunde" GET cKunde VALID ku->(Check(cKunde+"K","ku->Name1",01,30)) PICTURE "@!"
      READ

      IF LastKey() == 27
         EXIT
      ENDIF

      cFileName := Path("export\"+Trim(cKUnde)+"_pricelist.xlsx")

      nH := FCreate(cFileName)
      IF nH <= 0
         Tr_MsgBox("Datei kann nicht erstellt werden. Ist diese noch ge”ffnet?")
         LOOP
      ENDIF

      Aadd(aList,{"Item","Quantity","Price","Delivery time","Quote"})

      ang->(dbSetOrder( 2 ))
      ang->(dbSeek( cKunde ))
      DO WHILE ang->Kundma == cKunde .AND. ang->Bestat < 3 .AND. ! ang->(EOF())
         IF ! Trim(ang->Matchcode) $ {"@","TEXT","TEXT-RAHMEN","WERKZEUGKOSTEN"}
            ? ang->Matchcode,ang->VkQty,ang->VkPr/ang->Pe,ang->Dterm
            IF (nX := AScan(aList,{|x| x[1] == ang->Matchcode .AND. x[2] == ang->VkQty})) != 0
               //Tr_MsgBox({"Doppelter Preis",ang->Matchcode,Str(ang->VkQty),"Angebot: "+Ltrim(Str(ang->Angnr))+" "+Ltrim(Str(ang->VkPr/ang->Pe)),"Angebot: "+LTrim(str(aList[nX,5])+" "+LTrim(str(aList[nX,3])))})
               IF aList[nX,5] < ang->Angnr
                  aList[nX,3] := ang->VkPr/ang->Pe
                  aList[nX,4] := ang->Dterm
                  aList[nX,5] := ang->Angnr
               ENDIF
            ELSE
               Aadd(aList,{ang->Matchcode,ang->VkQty,ang->VkPr/ang->Pe,ang->Dterm,ang->Angnr})
            ENDIF
         ENDIF
         ang->(dbSkip())
      ENDDO

      //SInkey(0)

      FClose(nH)

      SaveToOO(cFileName,{"Pricelist"=>aList},,"XLSX")
      Wapi_ShellExecute(,"open",cFileName)
      EXIT
   ENDDO
RETURN

#include 'x:\run\savetooo.prg'
