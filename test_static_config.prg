/**
 * Test program for static configuration system
 */

#include "x:\run\product_data\channel_config.prg"

PROCEDURE Main()
   LOCAL aChannels, nX
   
   ? "Testing static configuration system..."
   ? 
   
   // Test loading all configurations
   ? "Loading all channel configurations..."
   IF LoadAllChannelConfigs()
      ? "? All configurations loaded successfully"
   ELSE
      ? "? Failed to load configurations"
      RETURN
   ENDIF
   
   ? 
   ? "Available channels:"
   aChannels := GetAvailableChannels()
   FOR nX := 1 TO Len(aChannels)
      ? "  " + aChannels[nX]
   NEXT
   
   ? 
   ? "Testing Conrad channel..."
   IF SetCurrentChannel("conrad")
      ? "? Conrad channel set successfully"
      ? "Current channel: " + GetCurrentChannel()
      
      ? "Company name: " + GetChannelSetting("company_settings.name")
      ? "WEEE number: " + GetChannelSetting("company_settings.weee_number")
      ? "Price multiplier: " + Str(GetChannelSetting("pricing_settings.price_multiplier"))
      ? "Max delivery weeks: " + Str(GetChannelSetting("inventory_settings.max_delivery_weeks"))
   ELSE
      ? "? Failed to set Conrad channel"
   ENDIF
   
   ? 
   ? "Testing general settings..."
   ? "Debug default: " + IF(GetGeneralSetting("system.debug_default"), "Yes", "No")
   ? "Waldom delivery days: " + Str(GetGeneralSetting("suppliers.waldom.default_delivery_days"))
   
   ? 
   ? "Testing filename convention..."
   ? "Export file for Conrad: export\product_data\" + GetCurrentChannel() + ".csv"
   ? "Full path: " + Path("export\product_data\" + GetCurrentChannel() + ".csv")
   
   ? 
   ? "Testing channel switch..."
   IF SetCurrentChannel("amazon")
      ? "? Amazon channel set successfully"
      ? "Current channel: " + GetCurrentChannel()
      ? "Company name: " + GetChannelSetting("company_settings.name")
   ELSE
      ? "? Amazon channel not found (expected)"
   ENDIF
   
   ? 
   ? "Test completed!"

RETURN
