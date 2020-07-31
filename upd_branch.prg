NetUse("engkund","ku")
NetUse("wz08en","wzen")
NetUse("wz08de","wzde")
NetUse("branch","br")

ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))

DO WHILE ku->Group == "K" .AND. ! ku->(EOF())

   oXML := CS_GetCompanyReportFromArchive(ku->Nummer)
   IF oXml != NIL
      @ 30,00 SAY ku->Kunde
      cMarket := "CS"
      oMainActivity := TXmlIteratorScan():New(oXML:oRoot):Find("MainActivity")
      IF oMainActivity != NIL

          oActivityCode := TXmlIteratorScan():New(oMainActivity):Find("ActivityCode")
          IF oActivityCode != NIL
             cMarket += oActivityCode:cData
             cCode := ""
             FOR nX := 1 TO Len(oActivityCode:cData) STEP 2
                IF nX > 1
                  cCode += "."
                ENDIF
                cCode += SubStr(oActivityCode:cData,nX,2)
             NEXT
             IF ! br->(dbSeek( cCode )) .OR. Trim(br->Branch) != Trim(cCode)

               br->(Add_Rec())
               br->Branch := cCode
               IF wzde->(dbSeek( cCode ))
                  ?? wzde->Bezeichnun
                  br->Name := wzde->Bezeichnun
               ENDIF
               IF wzen->(dbSeek( cCode ))
                  br->Name_En := wzen->Bezeichnun
               ENDIF
               br->(dbUnLock())
             ELSE
               ?? br->Name
             ENDIF
             IF wzen->(dbSeek( cCode ))
               ku->(Rec_lock())
               ku->Branch := cCode
               ku->(dbUnLock())
             ENDIF
          ENDIF
       ENDIF
   ENDIF


   ku->(dbSkip())
ENDDO

#include 'X:\run\creditsafe.prg'
