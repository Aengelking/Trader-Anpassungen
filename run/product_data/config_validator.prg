/**
 * Configuration Validation Functions
 */
#include 'x:\run\product_data\channel_config.ch'

FUNCTION ValidateChannelConfig(cChannelName)
   LOCAL lValid := .T.
   LOCAL aErrors := {}
   LOCAL cMethod

   IF ! LoadAllChannelConfigs()
      RETURN {.F., {"Failed to load configurations"}}
   ENDIF

   IF ! SetCurrentChannel(cChannelName)
      RETURN {.F., {"Failed to set channel: " + cChannelName}}
   ENDIF

   IF ! _ValidateKey("channel_info.name", @aErrors)
      lValid := .F.
   ENDIF
   IF ! _ValidateKey("channel_info.code", @aErrors)
      lValid := .F.
   ENDIF
   IF ! _ValidateKey("channel_info.type", @aErrors)
      lValid := .F.
   ENDIF
   IF ! _ValidateKey("company_settings.weee_number", @aErrors)
      lValid := .F.
   ENDIF
   IF ! _ValidateKey("upload_settings.method", @aErrors)
      lValid := .F.
   ENDIF

   cMethod := GetChannelSetting("upload_settings.method")
   IF cMethod == "API"
      IF ! _ValidateKey("upload_settings.api.url", @aErrors)
         lValid := .F.
      ENDIF
      IF ! _ValidateKey("upload_settings.api.authorization", @aErrors)
         lValid := .F.
      ENDIF
   ELSEIF cMethod == "DIGIKEY_API"
      IF ! _ValidateKey("upload_settings.digikey_api.supplier_id", @aErrors)
         lValid := .F.
      ENDIF
      IF ! _ValidateKey("upload_settings.digikey_api.client_id", @aErrors)
         lValid := .F.
      ENDIF
      IF ! _ValidateKey("upload_settings.digikey_api.authorize_url", @aErrors)
         lValid := .F.
      ENDIF
      IF ! _ValidateKey("upload_settings.digikey_api.token_url", @aErrors)
         lValid := .F.
      ENDIF
      IF ! _ValidateKey("upload_settings.digikey_api.redirect_uri", @aErrors)
         lValid := .F.
      ENDIF
   ENDIF

RETURN {lValid, aErrors}

STATIC FUNCTION ValidateSection(hConfig, cSection, aRequiredKeys, aErrors)
   LOCAL lValid := .T., cKey
   
   IF ! HHasKey(hConfig, cSection)
      AAdd(aErrors, "Missing section: " + cSection)
      RETURN .F.
   ENDIF
   
   FOR EACH cKey IN aRequiredKeys
      IF ! HHasKey(hConfig[cSection], cKey)
         AAdd(aErrors, "Missing key '" + cKey + "' in section '" + cSection + "'")
         lValid := .F.
      ENDIF
   NEXT
   
RETURN lValid

STATIC FUNCTION _ValidateKey(cKey, aErrors)
   LOCAL xValue := GetChannelSetting(cKey)
   IF xValue == NIL
      AAdd(aErrors, "Missing key: " + cKey)
      RETURN .F.
   ENDIF
RETURN .T.

FUNCTION ListAvailableChannels()
   LOCAL aChannels := {}, aFiles, nX
   
   aFiles := Directory("x:\run\config\channels\*.json")
   FOR nX := 1 TO Len(aFiles)
      AAdd(aChannels, Left(aFiles[nX,1], At(".", aFiles[nX,1]) - 1))
   NEXT
   
RETURN aChannels

FUNCTION TestChannelConfig(cChannelName)
   LOCAL aResult, lValid, aErrors, nX
   
   ? "Testing configuration for channel: " + cChannelName
   
   aResult := ValidateChannelConfig(cChannelName)
   lValid := aResult[1]
   aErrors := aResult[2]
   
   IF lValid
      ? "? Configuration is valid"
   ELSE
      ? "? Configuration has errors:"
      FOR nX := 1 TO Len(aErrors)
         ? "  - " + aErrors[nX]
      NEXT
   ENDIF
   
RETURN lValid

#include 'x:\run\product_data\channel_config.prg'
