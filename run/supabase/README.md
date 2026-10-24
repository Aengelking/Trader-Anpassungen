# Trader User Sync to Multiple Supabase Auth Systems

This program synchronizes trader users from the local buy table to multiple Supabase authentication systems. Users are created as authenticated users in Supabase Auth rather than as records in custom tables, enabling direct authentication and authorization.

## Features

- **Multiple Auth System Support**: Sync to multiple Supabase Auth systems simultaneously
- **Native Authentication**: Users become actual authenticated users in Supabase
- **Configurable Sync Modes**: Support for INSERT and UPSERT operations
- **External Configuration**: JSON-based configuration for easy management
- **Comprehensive Logging**: Detailed logging with multiple log levels
- **Error Handling**: Robust error handling and validation
- **Interactive Management**: Built-in configuration manager
- **Connection Testing**: Test Auth API connections before sync
- **Enable/Disable**: Individual database configurations can be enabled/disabled
- **Rich Metadata**: Store trader-specific data in user and app metadata

## Files Overview

- `trader_user_sync.prg` - Main sync engine with all core functions
- `sync_runner.prg` - Interactive runner and configuration manager
- `supabase_configs.json` - Configuration file for multiple databases
- `setup_tables.sql` - SQL script to create tables in Supabase
- `README.md` - This documentation file

## Quick Start

### 1. Set up Supabase Auth and Optional Tables

1. Run the SQL in `setup_tables.sql` in each of your Supabase projects
2. This sets up:
   - Helper functions for auth user management
   - Optional `trader_user_profiles` table for extended data
   - Views for easy data access
   - Row Level Security policies

### 2. Configure Auth Systems

1. Edit `supabase_configs.json` with your actual Supabase details:
   - Replace URLs with your Supabase project URLs
   - Replace API keys with your actual anon and service role keys
   - Set `enabled: true` for auth systems you want to sync to
   - Set `create_users: true` to actually create users
   - Choose sync mode: "UPSERT" (update or create) or "INSERT" (create only)
   - Set `send_email: false` to skip email verification

### 3. Run the Sync

#### Option A: Use the Interactive Runner
```harbour
// Compile and run
RunConfigBasedSync()
```

#### Option B: Use Direct Function
```harbour
// Compile and run
SYNC_Trader_Users()
```

#### Option C: Manage Configurations
```harbour
// Compile and run
ManageConfigurations()
```

## Configuration File Format

The `supabase_configs.json` file contains an array of auth system configurations:

```json
[
  {
    "name": "Production Auth Database",
    "url": "https://your-project.supabase.co",
    "anon_key": "your-anon-key",
    "service_role_key": "your-service-role-key",
    "auth_endpoint": "auth/v1/admin/users",
    "enabled": true,
    "sync_mode": "UPSERT",
    "create_users": true,
    "send_email": false,
    "description": "Main production auth system"
  }
]
```

### Configuration Parameters

- **name**: Descriptive name for the auth system
- **url**: Supabase project URL
- **anon_key**: Supabase anonymous key (optional, mainly for testing)
- **service_role_key**: Supabase service role key (required for auth operations)
- **auth_endpoint**: Auth API endpoint (usually "auth/v1/admin/users")
- **enabled**: Whether this auth system should be synced (true/false)
- **sync_mode**: "UPSERT" or "INSERT"
- **create_users**: Whether to actually create users (true/false)
- **send_email**: Whether to send confirmation emails (true/false)
- **description**: Optional description

## Sync Modes

### UPSERT Mode (Recommended)
- Checks if user exists based on email address
- Updates existing users' metadata
- Creates new users if they don't exist
- Best for keeping auth data current

### INSERT Mode
- Always creates new auth users
- May fail if user already exists with same email
- Useful for initial population or backup scenarios

## User Data Mapping

The sync maps trader user fields to Supabase Auth user structure:

### Basic Auth Fields
| Trader Field | Auth Field | Description |
|--------------|------------|-------------|
| buy->Email or generated | email | Email address (generated if empty) |
| Generated | password | Default password (should be changed) |
| - | email_confirm | Set to true (skip confirmation) |

### User Metadata (user-editable)
| Trader Field | Metadata Field | Description |
|--------------|----------------|-------------|
| Recno() | trader_user_id | Original user ID |
| buy->Buyer | full_name | Full name |
| buy->Initials | initials | User initials |
| buy->Short | short_name | Short name |
| buy->Telefon | phone | Phone/extension |
| buy->Verrsatz | rate | Hourly rate |
| buy->aktive | active | Active status |
| Computed | display_name | "Initials - Name" format |
| Current time | last_sync | Sync timestamp as text |
| Current time | sync_timestamp | ISO timestamp |

### App Metadata (system-controlled)
| Field | Value | Description |
|-------|--------|-------------|
| provider | "trader" | Source system identifier |
| trader_user_id | Recno() | Backup user ID |
| role | "user" or "inactive" | User role based on active status |
| department | "trader" | Department classification |

## Logging

Logs are saved to `X:\run\supabase\logs\` with timestamps:
- **INFO**: General information
- **DEBUG**: Detailed operations
- **WARNING**: Non-critical issues
- **ERROR**: Critical errors

Log files are named: `{operation}_{date}_{time}.log`

## Functions Overview

### Main Functions
- `SYNC_Trader_Users()` - Main sync using hardcoded configs
- `SYNC_Trader_Users_FromConfig(aConfigs)` - Sync using provided configs
- `RunConfigBasedSync()` - Interactive sync with file-based config
- `ManageConfigurations()` - Configuration manager

### Configuration Functions
- `GetSupabaseConfigs()` - Returns hardcoded configurations
- `LoadSupabaseConfigsFromFile(cFileName)` - Load configs from JSON file
- `SaveSupabaseConfigsToFile(aConfigs, cFileName)` - Save configs to JSON file

### Validation Functions
- `ValidateAllConfigs(aConfigs, cLogFile)` - Validate all configurations
- `TestSupabaseAuthConnection(hConfig, cLogFile)` - Test single auth connection

### Database Functions
- `OpenTraderDatabase(cLogFile)` - Open trader database
- `CloseTraderDatabase()` - Close trader database
- `SyncToSupabaseDatabase(hConfig, cLogFile)` - Sync to one auth system
- `SyncSingleAuthUser(oSupa, hConfig, hUserData, cLogFile)` - Sync one user
- `PrepareUserAuthData(hConfig)` - Prepare user data for auth sync

### Utility Functions
- `CreateLogFile(cBaseName)` - Create log file
- `WriteLog(cLogFile, cLevel, cMessage)` - Write to log
- `DateTime()` - Get ISO datetime string

## Error Handling

The system includes comprehensive error handling:
- Connection validation before sync
- Database availability checks
- JSON parsing error handling
- Individual user sync error handling
- Detailed error logging

## Security Considerations

1. **API Keys**: Store service role keys securely - they have admin access to auth
2. **File Permissions**: Protect configuration files containing sensitive keys
3. **Network**: Ensure secure HTTPS connections to Supabase
4. **Logging**: Log files may contain email addresses and sensitive information
5. **Passwords**: Generated passwords should be changed on first login
6. **Email Verification**: Consider enabling email verification in production

## Authentication Flow

After sync, users can authenticate using:
1. **Email/Password**: Using generated or updated passwords
2. **SSO Integration**: If configured in Supabase
3. **Magic Links**: If enabled in Supabase Auth

## Accessing User Data

### Via Auth API
```javascript
// Get current user metadata
const { data: { user } } = await supabase.auth.getUser()
console.log(user.user_metadata.trader_user_id)
```

### Via SQL (with helper functions)
```sql
-- Get trader data for a user
SELECT get_trader_user_data('user-uuid-here');

-- Find user by trader ID
SELECT get_user_by_trader_id(1);

-- View all trader users
SELECT * FROM trader_users_complete;
```

### Via REST API
```http
GET /rest/v1/trader_users_complete
Authorization: Bearer your-anon-key
```

## Scheduling

To run automatically, you can:
1. Create a batch file that calls the sync
2. Use Windows Task Scheduler
3. Call from your main application at intervals

Example batch file:
```batch
@echo off
cd /d "X:\run\supabase"
harbour trader_user_sync.prg sync_runner.prg
your_harbour_executable.exe
```

## Troubleshooting

### Common Issues

1. **"Configuration validation failed"**
   - Check your service role API keys
   - Verify Supabase URLs are correct
   - Ensure auth endpoints are accessible

2. **"Failed to open trader database"**
   - Check database file paths
   - Ensure proper database permissions

3. **"Auth connection test failed"**
   - Verify network connectivity
   - Check Supabase project status and auth settings
   - Validate service role key permissions

4. **"User already registered" errors**
   - Normal for UPSERT mode with existing users
   - Check if email addresses are unique
   - Consider using different sync mode

5. **Sync errors for specific users**
   - Check email address validity
   - Verify user data completeness
   - Review log files for detailed errors

### Log Analysis

Check log files for:
- Connection issues
- Data validation problems
- API rate limiting
- Network timeouts

## Customization

### Adding New Metadata Fields
1. Update `PrepareUserAuthData()` function to include new fields
2. Decide whether to store in user_metadata or app_metadata
3. Update documentation and helper functions

### Custom Auth Logic
Modify the sync logic in:
- `SyncSingleAuthUser()` - Individual user auth sync
- `SyncToSupabaseDatabase()` - Auth system-level sync
- `PrepareUserAuthData()` - Auth data preparation

### Additional Auth Systems
Add new configurations to `supabase_configs.json` or modify `GetSupabaseConfigs()`.

### Extended Profile Data
Use the optional `trader_user_profiles` table for data that doesn't fit in auth metadata.

## Support

For issues or questions:
1. Check log files for detailed error messages
2. Verify configuration settings
3. Test connections individually
4. Review Supabase project settings

## Version History

- v1.0 - Initial release with multiple database support
- Features: JSON configuration, comprehensive logging, error handling
