#include "hbclass.ch"

CLASS Perplexity FROM RestAPI
   DATA cBaseUrl INIT "https://api.perplexity.ai/chat/completions"
   DATA cToken INIT "SCHLUESSEL_ENTFERNT"

   DATA aMessages INIT {}

   METHOD Ask(cPrompt,cModel) 
ENDCLASS

METHOD Ask(cPrompt,cModel,hData) CLASS Perplexity
   LOCAL aHeaders := {"Authorization: Bearer "+::cToken,"Content-Type: application/json"}
   LOCAL cAnswer,hAnswer

   Default(@cModel,"sonar-pro")
   Default(@hData,{=>})

   Aadd(::aMessages,{"role"=>"user","content"=>hb_strToUtf8(cPrompt)})
   
   hData["model"] := cModel
   hData["messages"] := ::aMessages

   cAnswer := ::Execute("","POST",hData,aHeaders,.T.)
   Alert(cAnswer)
   hAnswer := hb_JsonDecode(cAnswer)
   IF HHasKey(hAnswer,"choices")
      cAnswer :=  hAnswer["choices"][1]["message"]["content"]
   ELSE
      cAnswer := "Error: "+(IF(HHasKey(hAnswer,"error"),hAnswer["error"]["message"],"No answer"))
   ENDIF
   
   //need to add the answer to messages to have a conversation


RETURN cAnswer
   

