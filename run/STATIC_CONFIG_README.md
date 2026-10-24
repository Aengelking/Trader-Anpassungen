# Static Configuration System

The channel configuration system has been updated to use static variables, eliminating the need to pass configuration objects between functions.

## Key Changes

### 1. Static Variables
- `s_hAllConfigs`: Holds all loaded configurations (general + all channels)
- `s_cCurrentChannel`: Tracks the currently selected channel

### 2. New Functions

#### Configuration Loading
- `LoadAllChannelConfigs()`: Loads all channel configurations at startup
- `SetCurrentChannel(cChannelName)`: Sets the active channel

#### Settings Access
- `GetChannelSetting(cKey)`: Gets setting from current channel
- `GetChannelSettingWithDefault(cKey, xDefault)`: Gets setting with fallback
- `GetGeneralSetting(cKey)`: Gets setting from general configuration
- `GetGeneralSettingWithDefault(cKey, xDefault)`: Gets general setting with fallback

#### Utility Functions
- `GetCurrentChannel()`: Returns the current channel name
- `GetAvailableChannels()`: Returns array of all available channels

### 3. Usage Example

```harbour
// Initialize and set channel
IF ! SetCurrentChannel("conrad")
   RETURN
ENDIF

// Get settings without passing config object
cWEEE := GetChannelSetting("company_settings.weee_number")
nMultiplier := GetChannelSettingWithDefault("pricing_settings.price_multiplier", 1.18)

// Use standardized filename convention
cQuoteFile := Path("export\product_data\" + GetCurrentChannel() + ".csv")
// Results in: "export\product_data\conrad.csv"
```

### 4. File Naming Convention

The system now uses a standardized file naming convention:
- **Export Directory**: Fixed to `export\product_data\`
- **Filename**: `{channel_name}.csv`
- **Examples**:
  - Conrad: `export\product_data\conrad.csv`
  - Amazon: `export\product_data\amazon.csv`
  - eBay: `export\product_data\ebay.csv`

This eliminates the need for file_settings in the configuration files.

### 5. Benefits

1. **Simplified Function Calls**: No need to pass hChannelConfig parameter
2. **Automatic Loading**: Configurations loaded once, used everywhere
3. **Easy Channel Switching**: Change active channel anytime
4. **Dot Notation**: Use "section.subsection.key" for nested values
5. **Default Values**: Built-in fallback support
6. **Standardized Filenames**: Consistent export file naming across all channels

### 6. Configuration Structure

```
s_hAllConfigs := {
   "general" => { ... general settings ... },
   "channels" => {
      "conrad" => { ... merged general + Conrad settings ... },
      "amazon" => { ... merged general + Amazon settings ... }
   }
}
```

### 7. Migration Notes

Old pattern:
```harbour
hConfig := LoadChannelConfig("conrad")
cValue := GetChannelSetting(hConfig, "section", "key", default)
cFile := Path(GetGeneralSetting(hConfig, "directories", "export_base") + 
         GetChannelSetting(hConfig, "file_settings", "export_subdir") + "\" +
         GetChannelSetting(hConfig, "file_settings", "export_filename"))
```

New pattern:
```harbour
SetCurrentChannel("conrad")
cValue := GetChannelSettingWithDefault("section.key", default)
cFile := Path("export\product_data\" + GetCurrentChannel() + ".csv")
```
