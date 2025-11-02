# iOS App Signing Guide

This guide walks you through creating and exporting the signing credentials needed for building the app.

## Prerequisites

1. Apple Developer Program membership
2. Access to Apple Developer Portal (developer.apple.com)
3. Xcode installed on your Mac
4. Admin access to your Mac (for Keychain)

## Step 1: Create App ID

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Click "Certificates, IDs & Profiles"
3. Under "Identifiers", click "+" to register a new App ID
4. Choose "App" and click "Continue"
5. Fill in:
   - Description: "SailTact"
   - Bundle ID: com.yourdomain.SailTact (use your domain)
6. Under Capabilities, enable:
   - Location Services
   - Maps
7. Click "Continue" and then "Register"

## Step 2: Create Certificate

1. In Developer Portal, go to "Certificates"
2. Click "+" to create a new certificate
3. For development:
   - Choose "iOS App Development"
   - For App Store, choose "Apple Distribution"
4. Click "Continue"
5. Follow instructions to create a Certificate Signing Request (CSR):
   ```
   On your Mac:
   1. Open "Keychain Access"
   2. From menu: Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority
   3. Fill in:
      - Email: Your email
      - Common Name: Your name
      - CA Email: Leave blank
      ✓ "Save to disk"
      ✓ "Let me specify key pair information"
   4. Click Continue
   5. Set Key Size: 2048 bits
   5. Algorithm: RSA
   6. Save the .certSigningRequest file
   ```
6. Upload the .certSigningRequest to Developer Portal
7. Download the generated certificate (.cer file)
8. Double-click the .cer to install in Keychain

## Step 3: Create Provisioning Profile

1. In Developer Portal, go to "Profiles"
2. Click "+" to create new profile
3. For development:
   - Choose "iOS App Development"
   - For App Store, choose "App Store"
4. Click "Continue"
5. Select your App ID (created in Step 1)
6. Select your certificate (created in Step 2)
7. Select test devices (for development profile)
8. Name the profile (e.g., "SailTact Development")
9. Download the .mobileprovision file

## Step 4: Export Certificate as .p12

1. Open Keychain Access
2. Find your certificate (look for "iPhone Developer: Your Name" or "Apple Distribution")
3. Right-click the certificate and choose "Export"
4. Choose Format: "Personal Information Exchange (.p12)"
5. Save as "ios_distribution.p12" (or similar)
6. Set a strong password (you'll need this for GitHub)

## Step 5: Set up GitHub Secrets

1. Base64-encode your credentials:
   ```powershell
   # From repo root
   .\scripts\encode_p12.ps1 -Path path\to\ios_distribution.p12 > p12_base64.txt
   .\scripts\encode_p12.ps1 -Path path\to\profile.mobileprovision > profile_base64.txt
   ```

2. Go to your GitHub repository → Settings → Secrets → Actions
3. Add these secrets:
   - `P12_BASE64`: Contents of p12_base64.txt
   - `P12_PASSWORD`: Password you set for .p12 export
   - `PROFILE_BASE64`: Contents of profile_base64.txt
   - `BUNDLE_ID`: Your app bundle ID (e.g., com.yourdomain.SailTact)
   - `XCODE_PROJECT`: "SailTact.xcodeproj"
   - `XCODE_SCHEME`: "SailTact"
   - `EXPORT_METHOD`: "development" (or "app-store")

## Local Development Setup

After installing the certificate and profile:

1. Open Xcode
2. In project settings:
   - Select your Team
   - Under Signing & Capabilities:
     - Check "Automatically manage signing"
     - Select your Provisioning Profile
3. Build and run on a device

## Troubleshooting

### Certificate Issues
- Error "Certificate not trusted": Double-click the .cer file in Finder first
- Missing private key: Ensure you exported the certificate WITH private key as .p12

### Profile Issues
- "No profiles for 'bundle.id'": Create the App ID first
- "No valid signing certificate": Create certificate first
- "Device not found": Add device UDID to profile (development only)

### GitHub Actions Issues
- "Could not read from keychain": Check P12_PASSWORD
- "Profile doesn't match": Verify BUNDLE_ID matches profile
- "No signing certificate": Check P12_BASE64 is valid

Need help? Contact your team's iOS provisioning admin or Apple Developer Support.