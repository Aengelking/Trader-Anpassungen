FUNCTION HOOK_After_Approve_MUS( nNummer, xObject, tLastChange )
   // CRM: Musterauftrag nach der Freigabe einer Opportunity zuordnen (wie
   // Angebote in before_print_angebot). Ist er bereits zugeordnet, passiert
   // nichts; sonst oeffnet sich der Opportunity-Picker (Auswahl oder
   // Neuanlage). Den Versand meldet after_pack dann ohne Rueckfrage an diese
   // Opportunity. Best-effort: ein Fehler oder Abbruch haelt das Muster nicht auf.
   LOCAL lCrmSamples := .T.
   LOCAL aContact
   LOCAL cContactName := "", cContactEmail := ""
   LOCAL nRef

   HB_SYMBOL_UNUSED( xObject )
   HB_SYMBOL_UNUSED( tLastChange )

   IF ! lCrmSamples
      RETURN NIL
   ENDIF

   BEGIN SEQUENCE
      NetUse("muster","mus",.F.,0)
      NetUse("mushead","muh")
      mus->(dbSetOrder( 1 ))
      IF mus->(dbSeek( nNummer )) .AND. muh->(dbSeek( Str(nNummer,6) ))
         IF AT("CONRAD",Upper(muh->Beleg)) == 1  //Conrad-Muster nicht ins CRM (wie approve_mus)
            BREAK
         ENDIF
         NetUse("engkund","ku",.F.,0)
         ku->(dbSetOrder( 1 ))
         IF ku->(dbSeek( mus->Kunde+"K" ))
            IF mus->Person > 0
               aContact := GetContact(mus->Person)
               IF ValType(aContact) == "H"
                  cContactName  := AllTrim(aContact["name"])
                  cContactEmail := AllTrim(aContact["email"])
               ENDIF
            ENDIF
            LoadPrg(Path("run\crm_email.prg"))
            HB_ExecFromArray({"CRM_SampleAssign", nNummer, LTrim(Str(ku->Nummer)), ku->Name1, ;
               cContactName, cContactEmail, @nRef})
         ENDIF
      ENDIF
   RECOVER
      //nicht fatal
   END SEQUENCE

RETURN NIL
