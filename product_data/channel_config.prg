/**
 * Channel Configuration Loader for Product Data Export
 * Loads all channel configs into separate sections with STATIC storage
 */

#ifndef __CHANNEL_CONFIG__
#define __CHANNEL_CONFIG__

FUNCTION LoadAllChannelConfigs()
   LOCAL cGeneralFile, hGeneralConfig
   LOCAL aChannelFiles, nX, cChannelFile, cChannelName, hChannelConfig
   LOCAL hAllConfigs := {=>}
   
   // Load general configuration
   cGeneralFile := "x:\run\config\general_config.json"
   hGeneralConfig := LoadJsonConfig(cGeneralFile)
   IF hGeneralConfig == NIL
      Alert("Failed to load general configuration")
      RETURN .F.
   ENDIF
   
   // Store general config
   hAllConfigs["general"] := hGeneralConfig
   hAllConfigs["channels"] := {=>}
   
   // Get list of channel files
   aChannelFiles := Directory("x:\run\config\channels\*.json")
   
   // Load each channel configuration
   FOR nX := 1 TO Len(aChannelFiles)
      cChannelName := Left(aChannelFiles[nX,1], At(".", aChannelFiles[nX,1]) - 1)
      cChannelFile := "x:\run\config\channels\" + aChannelFiles[nX,1]
      
      hChannelConfig := LoadJsonConfig(cChannelFile)
      IF hChannelConfig != NIL
         // Merge with general configuration
         hAllConfigs["channels"][cChannelName] := MergeConfigurations(hGeneralConfig, hChannelConfig)
      ELSE
         Alert("Failed to load channel configuration: " + cChannelName)
      ENDIF
   NEXT
   
   // Store in static variable
   s_hAllConfigs := hAllConfigs
   
RETURN .T.

FUNCTION SetCurrentChannel(cChannelName)
   // Default to Conrad if no channel specified
   IF Empty(cChannelName)
      cChannelName := "conrad"
   ENDIF
   
   // Load all configs if not already loaded
   IF s_hAllConfigs == NIL
      IF ! LoadAllChannelConfigs()
         RETURN .F.
      ENDIF
   ENDIF
   
   // Check if channel exists
   IF ! HHasKey(s_hAllConfigs["channels"], cChannelName)
      Alert("Channel '" + cChannelName + "' not found in configuration")
      RETURN .F.
   ENDIF
   
   s_cCurrentChannel := cChannelName
   
RETURN .T.

FUNCTION LoadJsonConfig(cConfigFile)
   LOCAL nHandle, nBytes, cBuffer, cJsonContent, hConfig
   
   IF ! File(cConfigFile)
      Alert("Configuration file not found: " + cConfigFile)
      RETURN NIL
   ENDIF
   
   nHandle := FOpen(cConfigFile, 0)  // Read only
   IF nHandle == -1
      Alert("Cannot open configuration file: " + cConfigFile)
      RETURN NIL
   ENDIF
   
   cBuffer := Space(FileSize(cConfigFile))
   nBytes := FRead(nHandle, @cBuffer, Len(cBuffer))
   FClose(nHandle)
   
   cJsonContent := Left(cBuffer, nBytes)
   
   // Parse JSON
   hConfig := HB_JsonDecode(cJsonContent)
   IF ValType(hConfig) != "H"
      Alert("Invalid JSON in configuration file: " + cConfigFile)
      RETURN NIL
   ENDIF
   
RETURN hConfig

FUNCTION MergeConfigurations(hGeneral, hChannel)
   LOCAL hMerged := {=>}
   LOCAL cKey, xValue
   
   // Start with general configuration
   IF HHasKey(hGeneral, "general")
      FOR EACH xValue IN hGeneral["general"]
         cKey := xValue:__eNumKey()
         hMerged[cKey] := HB_HClone(xValue)
      NEXT
   ENDIF
   
   // Add channel-specific settings (these override general ones)
   FOR EACH xValue IN hChannel
      cKey := xValue:__eNumKey()
      hMerged[cKey] := HB_HClone(xValue)
   NEXT
   
RETURN hMerged

FUNCTION GetChannelSetting(cKey)
   // Load configs if not already loaded
   IF s_hAllConfigs == NIL
      IF ! LoadAllChannelConfigs()
         RETURN NIL
      ENDIF
   ENDIF
   
   // Check if current channel is set
   IF Empty(s_cCurrentChannel)
      Alert("No channel selected. Use SetCurrentChannel() first.")
      RETURN NIL
   ENDIF
   
   // Navigate through nested keys
   RETURN GetNestedValue(s_hAllConfigs["channels"][s_cCurrentChannel], cKey)

FUNCTION GetChannelSettingWithDefault(cKey, xDefault)
   LOCAL xValue := GetChannelSetting(cKey)
   RETURN IIF(xValue == NIL, xDefault, xValue)

FUNCTION GetGeneralSetting(cKey)
   // Load configs if not already loaded
   IF s_hAllConfigs == NIL
      IF ! LoadAllChannelConfigs()
         RETURN NIL
      ENDIF
   ENDIF
   
   // Navigate through nested keys  
   RETURN GetNestedValue(s_hAllConfigs["general"], cKey)

FUNCTION GetGeneralSettingWithDefault(cKey, xDefault)
   LOCAL xValue := GetGeneralSetting(cKey)
   RETURN IIF(xValue == NIL, xDefault, xValue)

FUNCTION GetCurrentChannel()
   RETURN s_cCurrentChannel

FUNCTION GetAvailableChannels()
   LOCAL aChannels := {}
   LOCAL cKey
   
   // Load configs if not already loaded
   IF s_hAllConfigs == NIL
      IF ! LoadAllChannelConfigs()
         RETURN {}
      ENDIF
   ENDIF
   
   FOR EACH cKey IN s_hAllConfigs["channels"]
      AAdd(aChannels, cKey:__enumKey())
   NEXT
   
   RETURN aChannels

FUNCTION GetNestedValue(hHash, cKey)
   LOCAL aParts, nX, xCurrent
   
   IF ValType(hHash) != "H"
      RETURN NIL
   ENDIF
   
   // Handle dot notation for nested keys
   IF "." $ cKey
      aParts := HB_ATokens(cKey, ".")
      xCurrent := hHash
      
      FOR nX := 1 TO Len(aParts)
         IF ValType(xCurrent) == "H" .AND. HHasKey(xCurrent, aParts[nX])
            xCurrent := xCurrent[aParts[nX]]
         ELSE
            RETURN NIL
         ENDIF
      NEXT
      
      RETURN xCurrent
   ELSE
      // Simple key lookup
      IF HHasKey(hHash, cKey)
         RETURN hHash[cKey]
      ENDIF
   ENDIF
   
   RETURN NIL

#endif
