# Apple Endpoint Security Framework Test

A macOS system extension demonstrating the Apple Endpoint Security Framework with real-time process execution monitoring, cryptographic hashing (SHA256), and custom SSDEEP fuzzy hashing implementation for binary analysis and hash-based access control.

> **✅ Compatibility Note**: This project has been tested and works on **macOS Big Sur (11.0)** and later versions. Xcode 12+ on Big Sur is sufficient.

## Overview

This project showcases how to build a macOS endpoint security solution that:
- Monitors process execution events in real-time using the Endpoint Security framework
- Computes cryptographic and fuzzy hashes of executed binaries
- Implements hash-based allow/deny policies
- Logs detailed execution metadata in structured JSON format

## Features

- **Real-Time Process Monitoring**: Intercepts `ES_EVENT_TYPE_AUTH_EXEC` events before process execution
- **Multi-Hash Analysis**: Computes both SHA256 (cryptographic) and SSDEEP (fuzzy) hashes using custom implementation
- **Hash-Based Blocking**: Allow or deny process execution based on SHA256 hash matching
- **Comprehensive Logging**: JSON-formatted event logs including:
  - Process ID, path, and arguments
  - SHA256 and SSDEEP hashes
  - File size
  - Code signing information (signing ID, team ID)
- **Performance Testing**: Designed to measure SHA256 and SSDEEP hashing performance metrics in real-time execution monitoring

## Architecture

The project consists of two components:

### 1. System Extension (`Extension/`)
The core endpoint security client that:
- Subscribes to Endpoint Security AUTH events
- Processes execution requests on a concurrent dispatch queue
- Computes file hashes synchronously
- Responds with ALLOW or DENY authorization decisions
- Logs events to system log via `os_log`

### 2. Host Application (`MyEndPoint/`)
A minimal macOS Cocoa application that serves as the container for the system extension.

## Requirements

### System Requirements
- **macOS**: Big Sur (11.0) or later
  - ✅ Tested on macOS Big Sur
  - ✅ Compatible with Monterey, Ventura, Sonoma, Sequoia
- **Hardware**: Intel or Apple Silicon Mac
  - Intel Macs supported
  - Apple Silicon (M1/M2/M3/M4) recommended for best performance
- **Xcode**: 12.0 or later
  - ✅ Works with Xcode 12+ (tested on Big Sur)
  - No specific Xcode version required

### Development Requirements
- **SIP Disabled**: System Integrity Protection must be disabled for development/testing
  - ⚠️ **CRITICAL**: This project is tested on SIP-disabled machines
  - ⚠️ **WARNING**: Only disable SIP on isolated development machines
  - See [Development Setup](#development-setup) below
- **Code Signing**: Local/ad-hoc signing is sufficient for SIP-disabled testing
  - No Apple Developer account required for development
  - Production deployment would require proper developer signing

### Runtime Permissions
- System extension activation (System Settings → Privacy & Security)
- Full Disk Access (for reading all executable files)
- Endpoint Security entitlement (`com.apple.developer.endpoint-security.client`)

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/AppleEndpointSecurityFrameworkTest.git
cd AppleEndpointSecurityFrameworkTest
```

### 2. Open in Xcode
```bash
open src/MyEndPoint.xcodeproj
```

### 3. Configure Code Signing
1. Select the project in Xcode
2. For SIP-disabled testing, use "Sign to Run Locally" or ad-hoc signing:
   - Select project → Signing & Capabilities
   - Choose "Sign to Run Locally" for both targets:
     - `MyEndPoint` (host app)
     - `Extension` (system extension)
3. No Apple Developer account needed for local testing

### 4. Build
```bash
xcodebuild clean build analyze -project src/MyEndPoint.xcodeproj
```

Or build directly in Xcode (⌘B)

## Development Setup

### Disable SIP (Development Only)

⚠️ **CRITICAL**: This project requires SIP disabled for development and testing.

1. Reboot into Recovery Mode (hold Command+R during startup)
2. Open Terminal from Utilities menu
3. Disable SIP:
   ```bash
   csrutil disable
   ```
4. Reboot normally
5. Verify SIP status:
   ```bash
   csrutil status
   # Should show: System Integrity Protection status: disabled.
   ```

### Enable SIP (Before Production)
```bash
# In Recovery Mode Terminal:
csrutil enable
```

⚠️ **Never deploy with SIP disabled in production environments**

## Manual Deployment Methodology

This section provides step-by-step instructions for manually deploying the system extension on a development/test machine.

### Prerequisites Checklist

Before deployment, ensure:
- ✅ SIP is disabled on the target machine
- ✅ Xcode 12+ is installed (any version from Big Sur onwards)
- ✅ Local code signing configured (ad-hoc signing sufficient)
- ✅ Target machine runs macOS Big Sur (11.0) or later

### Step 1: Build the Application

#### Option A: Build via Xcode (Recommended)
1. Open the project:
   ```bash
   open src/MyEndPoint.xcodeproj
   ```

2. Select build scheme:
   - Product → Scheme → MyEndPoint

3. Select target device:
   - My Mac (Designed for iPad/iPhone/Mac)

4. Build the project:
   - Product → Build (⌘B)
   - Or: Product → Build For → Running (⌘⇧R)

5. Locate the build output:
   ```bash
   # Default location
   ~/Library/Developer/Xcode/DerivedData/MyEndPoint-*/Build/Products/Debug/
   ```

#### Option B: Build via Command Line
```bash
# Clean build
xcodebuild clean build analyze \
  -project src/MyEndPoint.xcodeproj \
  -scheme MyEndPoint \
  -configuration Debug

# Build output location
BUILD_DIR="$(xcodebuild -project src/MyEndPoint.xcodeproj -showBuildSettings | grep BUILD_DIR | awk '{print $3}')"
echo "Build output: $BUILD_DIR"
```

### Step 2: Verify Build Artifacts

Check that both components were built successfully:

```bash
# Navigate to build directory
cd ~/Library/Developer/Xcode/DerivedData/MyEndPoint-*/Build/Products/Debug/

# Verify host application
ls -la MyEndPoint.app

# Verify system extension (embedded in app)
ls -la MyEndPoint.app/Contents/Library/SystemExtensions/

# Check extension bundle
ls -la MyEndPoint.app/Contents/Library/SystemExtensions/com.test.MyEndPoint.Extension.systemextension
```

### Step 3: Verify Code Signing

Ensure proper code signing for both components:

```bash
# Check host app signature
codesign -dv --verbose=4 MyEndPoint.app

# Check extension signature
codesign -dv --verbose=4 MyEndPoint.app/Contents/Library/SystemExtensions/com.test.MyEndPoint.Extension.systemextension

# Verify entitlements
codesign -d --entitlements - MyEndPoint.app/Contents/Library/SystemExtensions/com.test.MyEndPoint.Extension.systemextension
```

Expected entitlements should include:
```xml
<key>com.apple.developer.endpoint-security.client</key>
<true/>
```

**Note for SIP-Disabled Testing**: Ad-hoc signing (local development signing) is sufficient. The signature may show as "adhoc" which is expected and acceptable for testing.

### Step 4: Run the Application

Simply run the application from Xcode:
1. Product → Run (⌘R)
2. Application launches automatically
3. System will prompt for extension approval

Alternatively, run from the build output:
```bash
cd ~/Library/Developer/Xcode/DerivedData/MyEndPoint-*/Build/Products/Debug/
open MyEndPoint.app
```

### Step 5: Install and Activate System Extension

1. Launch the host application:
   ```bash
   open /Applications/MyEndPoint.app
   # Or from current directory:
   open MyEndPoint.app
   ```

2. System will prompt for system extension approval:
   - Click "Open System Settings" or "Open Security Preferences"
   - Alternative: Manually navigate to **System Settings → Privacy & Security → System Extensions**

3. Approve the extension:
   - Look for "System Extension Blocked" or similar notification
   - Click "Allow" or "Details" → "Allow"
   - Authenticate with admin credentials if prompted

4. Verify extension is loaded:
   ```bash
   systemextensionsctl list
   ```

   Expected output should show:
   ```
   1 extension(s)
   --- com.apple.system_extension.endpoint_security
       com.test.MyEndPoint.Extension (1.0/1.0) [activated enabled]
   ```

### Step 6: Grant Required Permissions

#### Full Disk Access (Required)
1. Navigate to: **System Settings → Privacy & Security → Full Disk Access**
2. Click the lock icon to make changes (authenticate)
3. Click the "+" button
4. Navigate to and add:
   - `/Applications/MyEndPoint.app/Contents/Library/SystemExtensions/com.test.MyEndPoint.Extension.systemextension`
5. Toggle the extension ON

#### Verify Permissions
```bash
# Check if extension has Full Disk Access
tccutil reset All com.test.MyEndPoint.Extension
```

### Step 7: Start Monitoring

1. The extension should now be running automatically
2. Verify it's active:
   ```bash
   ps aux | grep Extension
   ```

3. Check system logs for extension activity:
   ```bash
   log show --predicate 'sender == "com.test.MyEndPoint.Extension"' --last 5m
   ```

4. Test by executing a command:
   ```bash
   ls
   # Should generate an ES_EVENT_TYPE_AUTH_EXEC event
   ```

### Step 8: Verify Functionality

#### Test Event Capture
```bash
# Open a new terminal and run:
log stream --predicate 'sender == "com.test.MyEndPoint.Extension"' --level debug &

# Execute test commands
echo "Testing"
ls -la
whoami

# Check logs for JSON event data
```

#### Test Hash Computation
Look for log entries containing:
- `"sha256":"..."`
- `"ssdeep":"..."`
- `"event_type":"ES_EVENT_TYPE_AUTH_EXEC"`

### Troubleshooting Deployment

#### Extension Not Loading
```bash
# Check extension status
systemextensionsctl list

# Check for errors in system log
log show --predicate 'subsystem contains "com.apple.system" and category == "systemextensions"' --last 1h

# Reset extension (if needed)
systemextensionsctl reset
```

#### Extension Crashes on Load
```bash
# Check crash reports
ls -lt ~/Library/Logs/DiagnosticReports/ | grep Extension

# View most recent crash log
open ~/Library/Logs/DiagnosticReports/$(ls -t ~/Library/Logs/DiagnosticReports/ | grep Extension | head -1)
```

#### No Events Being Captured
```bash
# Verify extension is running
ps aux | grep "com.test.MyEndPoint.Extension"

# Check permissions
tccutil dump

# Restart extension
killall -9 com.test.MyEndPoint.Extension
# Then relaunch host app
```

#### Code Signing Issues
```bash
# Re-sign the extension
codesign -f -s "Your Developer ID" MyEndPoint.app

# Verify signature
spctl --assess --verbose=4 MyEndPoint.app
```

### Uninstalling the Extension

To remove the system extension:

1. Quit the host application
2. Remove the extension:
   ```bash
   # List extensions and note the UUID
   systemextensionsctl list

   # Reset all extensions (nuclear option)
   systemextensionsctl reset
   ```

3. Remove application bundle:
   ```bash
   rm -rf /Applications/MyEndPoint.app
   ```

4. Remove preferences (optional):
   ```bash
   defaults delete com.test.MyEndPoint
   ```

5. Reboot the system to ensure complete cleanup

### Deployment Checklist

Use this checklist for each deployment:

- [ ] SIP verified disabled: `csrutil status`
- [ ] Xcode build successful (no errors)
- [ ] Code signing verified for both app and extension
- [ ] Extension bundle present in app package
- [ ] Application launched on target machine
- [ ] System extension approved in System Settings
- [ ] Full Disk Access granted
- [ ] Extension appears in `systemextensionsctl list`
- [ ] Extension process running in Activity Monitor
- [ ] Log stream shows event capture
- [ ] Test execution captured (e.g., `ls` command)
- [ ] JSON logs contain SHA256 and SSDEEP hashes

## Usage

### Running the Extension

1. Build and run the host application from Xcode
2. System will prompt to allow the system extension
3. Navigate to: **System Settings → Privacy & Security → System Extensions**
4. Approve the extension
5. Grant Full Disk Access if prompted

### Viewing Logs

Monitor extension activity via Console.app or command line:

```bash
# Stream logs from the extension (by sender name)
log stream --predicate 'sender == "com.test.MyEndPoint.Extension"' --level debug

# Stream logs from the extension (alternative - by process name)
log stream --predicate 'process == "com.test.MyEndPoint.Extension"' --level debug

# Filter for specific events
log stream --predicate 'eventMessage CONTAINS "ES_EVENT_TYPE_AUTH_EXEC"' --level debug
```

### Customizing the Blocklist

Edit `src/Extension/main.m` around line 97:

```objective-c
// Change this SHA256 hash to block different executables
static const char *sha256_to_block = "0a557177175c8df2e39d4978eedc56433a2499eda5d606f28f24c80d2010d262";
```

To find a file's SHA256 hash:
```bash
shasum -a 256 /path/to/executable
```

## Project Structure

```
AppleEndpointSecurityFrameworkTest/
├── README.md                   # This file
├── LICENSE                     # GPL-3.0 License
├── .github/workflows/          # CI/CD configuration
└── src/
    ├── Extension/              # System extension (ES client)
    │   ├── main.m              # Entry point, event handling
    │   ├── NSDataHash.{h,m}    # SHA256/SHA1 hashing
    │   ├── NSDataSSDEEP.{h,m}  # Custom SSDEEP fuzzy hashing implementation
    │   ├── Extension.entitlements
    │   └── Info.plist
    ├── MyEndPoint/             # Host application
    │   ├── AppDelegate.{h,m}
    │   ├── ViewController.{h,m}
    │   ├── main.m
    │   ├── MyEndPoint.entitlements
    │   └── Resources/
    └── MyEndPoint.xcodeproj    # Xcode project
```

## Key Implementation Details

### Event Handling Flow

1. **Initialization**: Creates concurrent dispatch queue with `QOS_CLASS_USER_INITIATED`
2. **Client Setup**: Initializes Endpoint Security client with event callback
3. **Subscription**: Subscribes to `ES_EVENT_TYPE_AUTH_EXEC` events
4. **Event Processing**:
   - Extracts process metadata (PID, path, arguments, signing info)
   - Reads executable file into memory
   - Computes SHA256 and SSDEEP hashes
   - Checks hash against blocklist
   - Responds with `ES_AUTH_RESULT_ALLOW` or `ES_AUTH_RESULT_DENY`
5. **Logging**: Outputs JSON event data via `os_log`

### Critical Authorization Pattern

**IMPORTANT**: The ES client MUST respond to ALL AUTH events to prevent system deadlocks.

See `src/Extension/main.m:108-122` for the default case handler that responds with ALLOW for unhandled events.

### Performance Considerations

- Hashing is performed **synchronously** in the event handler
- Entire executable is loaded into memory for hashing
- May impact system performance for large executables
- Consider asynchronous hashing or streaming for production use

## Testing

### Basic Functionality Test

1. Run the extension
2. Open Terminal and execute any command:
   ```bash
   ls
   ```
3. Check logs to see the execution event captured

### Block List Test

1. Find the SHA256 hash of a safe test binary (e.g., Calculator):
   ```bash
   shasum -a 256 /System/Applications/Calculator.app/Contents/MacOS/Calculator
   ```
2. Update `sha256_to_block` in `main.m` with this hash
3. Rebuild and run the extension
4. Try to launch Calculator - it should be blocked
5. Check logs for "DENIED" message

## Troubleshooting

### Extension Not Loading
- Verify SIP is disabled: `csrutil status`
- Check System Settings → Privacy & Security → System Extensions
- Ensure proper code signing with Endpoint Security entitlement

### No Events Captured
- Grant Full Disk Access to the extension
- Check extension is running (Activity Monitor)
- Verify subscription succeeded in logs

### Build Errors
- Ensure Xcode 12 or later is installed
- Check code signing configuration
- Ensure all targets have proper entitlements
- Verify macOS version is Big Sur (11.0) or later

## Security Considerations

⚠️ **This is a demonstration/testing project**

- **Not production-ready**: Synchronous hashing impacts performance
- **Hardcoded blocklist**: Should use dynamic, signed configuration files
- **No signature validation**: Blocklist should be cryptographically signed
- **Basic logging**: Production systems need secure, tamper-proof logging
- **SIP disabled**: Development only - never deploy to production with SIP off
- **Ad-hoc signing**: Production requires proper Apple Developer signing and notarization

## Performance Metrics

This project is designed to measure and evaluate:
- **SHA256 hashing performance**: Execution time and overhead for cryptographic hashing
- **SSDEEP fuzzy hashing performance**: Execution time and overhead for fuzzy hashing
- **Hashing overhead impact**: How hash computation affects process execution latency
- **File size correlation**: Performance characteristics across different file sizes
- **System responsiveness**: Overall system behavior under hashing load

The goal is to collect performance data for both hashing algorithms to understand their individual characteristics and impact on endpoint security monitoring.

### Future Enhancements

⚡ **Planned Features** for future versions:

#### Performance Metrics System
- Automated timing instrumentation for hash operations
- Statistical analysis (min, max, average, percentile)
- Performance data export (CSV, JSON formats)
- Real-time metrics visualization
- Detailed performance reports and benchmarks

#### JSON-Based Rule Configuration
- Dynamic rule loading from external JSON files
- Hot-reload capability without extension restart
- Rule versioning and validation
- Cryptographically signed rule sets
- Support for multiple rule types (hash blocklist, allowlist, signing ID rules)

#### LuaJIT Integration for Advanced Rule Creation
- Embedded LuaJIT scripting engine for custom rule logic
- Runtime rule evaluation and decision making
- User-defined heuristics and analysis functions
- Access to process metadata and file attributes from Lua scripts
- Sandboxed execution environment for security

#### ML Exploration
- Machine learning model integration for malware detection
- On-device ML inference using Core ML framework
- Behavioral analysis and anomaly detection
- Model updates and versioning
- Hybrid approach: static analysis (hashing) + dynamic analysis (ML)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## References

- [Apple Endpoint Security Documentation](https://developer.apple.com/documentation/endpointsecurity)
- [System Extensions Documentation](https://developer.apple.com/documentation/systemextensions)
- [NSHash Library](https://github.com/jerolimov/NSHash) - Basis for NSDataHash implementation

## Author

Created by Zimry Ong (2020)

---

**⚠️ Disclaimer**: This software is for educational and testing purposes. Use at your own risk. The author is not responsible for any system damage or data loss resulting from the use of this software.
