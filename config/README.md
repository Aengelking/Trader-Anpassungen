# Product Data Export Configuration

This directory contains the configuration files for the product data export system.

## Structure

### General Configuration
- `general_config.json` - Contains system-wide settings that apply to all channels

### Channel Configurations
- `channels/` - Directory containing individual channel configuration files
  - `conrad.json` - Conrad B2B marketplace configuration
  - `amazon.json` - Amazon Business marketplace configuration (example)

## Configuration Files

### general_config.json
Contains common settings used across all channels:
- Company information (WEEE numbers, etc.)
- File system paths
- System defaults (timeouts, debug settings)
- Supplier information
- Product defaults

### Channel Files (channels/*.json)
Each channel has its own configuration file with:
- Channel-specific information
- Pricing and inventory settings
- Upload/API configuration
- Notification settings
- Product data formatting
- Channel-specific filters

## Adding New Channels

1. Create a new JSON file in the `channels/` directory
2. Use the existing channel files as templates
3. Customize the settings for the new marketplace/channel
4. Test the configuration before production use

## Configuration Loading

The system loads configurations in this order:
1. General configuration (provides defaults)
2. Channel-specific configuration (overrides general settings)
3. Settings are merged with channel-specific taking precedence

## Usage

To use a specific channel configuration, pass the channel name to the ProductDataXML function:

```harbour
// Use Conrad configuration
ProductDataXML(.T., .F., "conrad")

// Use Amazon configuration  
ProductDataXML(.T., .F., "amazon")

// Default to Conrad if no channel specified
ProductDataXML(.T., .F.)
```
