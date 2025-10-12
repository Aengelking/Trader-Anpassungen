/**
 * Configuration Validation Functions
 */
#include 'x:\run\product_data\channel_config.ch'

FUNCTION ValidateChannelConfig(cChannelName)
   LOCAL hConfig, lValid := .T., aErrors := {}
   
   hConfig := LoadChannelConfig(cChannelName)
   IF hConfig == NIL
      RETURN {.F., {"Failed to load configuration"}}
   ENDIF
   
   // Validate required sections
   IF ! ValidateSection(hConfig, "channel_info", {"name", "code", "type"}, @aErrors)
      lValid := .F.
   ENDIF
   
   IF ! ValidateSection(hConfig, "company_settings", {"weee_number"}, @aErrors)
      lValid := .F.
   ENDIF
   
   IF ! ValidateSection(hConfig, "upload_settings", {"method"}, @aErrors)
      lValid := .F.
   ENDIF
   
   // Validate upload method specific settings
   IF GetChannelSetting(hConfig, "upload_settings", "method", "") == "API"
      IF ! ValidateSection(hConfig["upload_settings"], "api", {"url", "authorization"}, @aErrors)
         lValid := .F.
      ENDIF
   ENDIF
   
   // Validate file settings
   IF ! ValidateSection(hConfig, "file_settings", {"export_filename", "export_subdir"}, @aErrors)
      lValid := .F.
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
