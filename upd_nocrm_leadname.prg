PROC Upd_NoCrm_LeadName
   LOCAL oNoCrm := NoCrmApi():New()
   LOCAL aGetData,nOff := 0

   Head("Lead Namen um ID erg„nzen")

   DO WHILE .T.
      aGetData := oNoCRM:Execute("leads","GET",{"include_unassigned"=>"true","limit"=>"100","offset"=>LTrim(Str(nOff))})

      AEval(aGetData,{|hLead| 
         IF ! HB_RegexMatch("\B#[0-9]+\b",hLead["title"])            
            ? Trim(hLead["title"])+" #"+LTrim(Str(hLead["id"]))
            oNoCRM:Execute("leads/"+Ltrim(Str(hLead["id"])),"PUT",{"title"=>Trim(hLead["title"])+" #"+LTrim(Str(hLead["id"]))})
         ENDIF
         RETURN NIL
      })
      nOff += Len(aGetData)
      IF Len(aGetData) < 100
         EXIT
      ENDIF
   ENDDO

   //SInkey(0)

   #include "nocrm.prg"

