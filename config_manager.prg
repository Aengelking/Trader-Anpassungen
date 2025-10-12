/**
 * Configuration Management Script
 * Use this script to manage product data export configurations
 */

#include 'x:\run\product_data\channel_config.ch'

PROCEDURE ConfigManager()
   LOCAL nChoice, cChannel, aChannels, nX, lValid
   LOCAL getlist := {}
   
   CLS
   ? "Product Data Export - Configuration Manager"
   ? "=========================================="
   ?
   
   DO WHILE .T.
      ? "1. List available channels"
      ? "2. Test channel configuration"
      ? "3. Validate all configurations"
      ? "4. Show configuration paths"
      ? "0. Exit"
      ?
      ?? "Select option: "
      
      nChoice := Val(Chr(Sinkey(0)))
      ?
      
      DO CASE
      CASE nChoice == 1
         aChannels := ListAvailableChannels()
         ? "Available channels:"
         FOR nX := 1 TO Len(aChannels)
            ? "  " + Str(nX, 2) + ". " + aChannels[nX]
         NEXT
         
      CASE nChoice == 2
         ?? "Enter channel name: "
         cChannel := Space(20)
         @ Row(), Col() GET cChannel PICTURE "@!"
         READ
         cChannel := AllTrim(cChannel)
         
         IF ! Empty(cChannel)
            TestChannelConfig(cChannel)
         ENDIF
         
      CASE nChoice == 3
         aChannels := ListAvailableChannels()
         ? "Validating all channel configurations..."
         ?
         FOR nX := 1 TO Len(aChannels)
            lValid := TestChannelConfig(aChannels[nX])
            ?
         NEXT
         
      CASE nChoice == 4
         ? "Configuration file locations:"
         ? "General config: x:\run\config\general_config.json"
         ? "Channel configs: x:\run\config\channels\*.json"
         ?
         
      CASE nChoice == 0
         EXIT
         
      OTHERWISE
         ? "Invalid option"
      ENDCASE
      
      ?
      ? "Press any key to continue..."
      Sinkey(0)
      CLS
   ENDDO
   
RETURN

#include "x:\run\product_data\config_validator.prg"
