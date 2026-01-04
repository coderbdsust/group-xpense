import 'app_constants.dart';

class PrivacyPolicy {

  static const String content =
      '''
# Privacy Policy for ${AppConstants.appName}

**Last Updated: ${AppConstants.releaseDate}**
**Version: ${AppConstants.privacyPolicyVersion}**

## Introduction 

Welcome to ${AppConstants.appName} ("we," "our," or "us"). We are committed to protecting your privacy and ensuring you have a positive experience while using our application. This Privacy Policy explains how we collect, use, and protect your information.

## Information We Collect

### Data You Provide
- **Group Information**: Group names, descriptions, and creation dates
- **Member Information**: Names and email addresses (optional) of group members
- **Expense Records**: Expense descriptions, amounts, categories, dates, and payment details
- **Biometric Data**: If you enable biometric authentication, your fingerprint or face data is stored locally on your device only

### Automatically Collected Data
- **App Settings**: Your preferences for currency, biometric authentication status
- **Device Information**: We do not collect device-specific information

## How We Use Your Information

We use the collected information for:
- Tracking and managing group expenses
- Calculating balances and settlements between group members
- Providing expense reports and analytics
- Securing your app with biometric authentication (if enabled)
- Displaying amounts in your preferred currency

## Data Storage and Security

### Local Storage
- **All your data is stored locally** on your device using SQLite database
- Data is **never transmitted** to our servers or any third-party services
- **No cloud backup** - your data stays on your device
- **No internet connection required** for app functionality

### Security Measures
- SQLite database encryption (when biometric auth is enabled)
- Biometric authentication protection (fingerprint/face recognition)
- No external data transmission
- No third-party analytics or tracking

### Data You Control
You have complete control over your data:
- **Create, Edit, Delete**: Manage all groups, members, and expenses
- **Export**: Data can be backed up manually
- **Delete**: Uninstalling the app removes all data from your device

## Biometric Authentication

If you enable biometric authentication:
- Fingerprint/face data is processed by your device's operating system
- We **never access, store, or transmit** your biometric data
- Biometric data remains on your device and is managed by Android/iOS
- You can disable this feature anytime in Settings

## Data Sharing and Third Parties

We **do not**:
- Share your data with third parties
- Sell your personal information
- Use tracking or analytics services
- Display advertisements
- Require user accounts or login
- Transmit data over the internet

## Children's Privacy

${AppConstants.appName} does not knowingly collect data from children under 13. The app is designed for general use and does not target children. If you are a parent or guardian and believe your child has provided us with information, please contact us.

## Your Rights

You have the right to:
- **Access**: View all your data within the app
- **Modify**: Edit any information you've entered
- **Delete**: Remove individual items or all data by uninstalling the app
- **Export**: Back up your data manually
- **Opt-out**: Disable biometric authentication anytime

## Data Retention

- Data is retained locally on your device until you delete it
- Uninstalling the app permanently deletes all local data
- No data is retained on external servers

## International Data Transfers

Since all data is stored locally on your device:
- No international data transfers occur
- Your data never leaves your device
- No cross-border data processing

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by:
- Updating the "Last Updated" date
- Displaying a notification in the app
- Requiring acceptance of the updated policy

Continued use of the app after changes constitutes acceptance of the updated Privacy Policy.

## Third-Party Services

${AppConstants.appName} uses the following device services:
- **Local Authentication** (Android/iOS): For biometric authentication
- **SQLite Database** (local storage): For data persistence
- **Shared Preferences** (local storage): For app settings

None of these services transmit data externally.

## Permissions Explained

### Required Permissions:
- **Biometric/Fingerprint**: To enable optional biometric authentication
- **Storage**: To store app data locally on your device

### Not Used:
- Location services
- Camera (except for biometric face recognition by OS)
- Contacts
- Internet (no data transmission)

## Contact Us

If you have questions about this Privacy Policy or our privacy practices:

**Email**: ${AppConstants.developerEmail}  
**Website**: ${AppConstants.appWebsite}  
**Response Time**: Within 48 hours

## Compliance

This Privacy Policy complies with:
- General Data Protection Regulation (GDPR)
- California Consumer Privacy Act (CCPA)
- Children's Online Privacy Protection Act (COPPA)
- Other applicable data protection laws

## User Consent

By using ${AppConstants.appName}, you consent to:
- Collection of data as described in this policy
- Local storage of your data
- Use of biometric authentication (if you enable it)

You can withdraw consent by:
- Disabling biometric authentication in Settings
- Deleting specific data within the app
- Uninstalling the application

## Open Source

${AppConstants.appName} is built with Flutter and uses open-source libraries. For transparency:
- No proprietary tracking code
- No hidden data collection
- No backdoors or unauthorized access

## Summary

**In Simple Terms:**
- ✅ All data stays on your device
- ✅ No internet connection required
- ✅ No accounts or registration
- ✅ No ads or tracking
- ✅ Complete control over your data
- ✅ Delete anytime by uninstalling

**We DO NOT:**
- ❌ Collect personal information
- ❌ Share data with anyone
- ❌ Use cloud storage
- ❌ Track your activity
- ❌ Display advertisements

---

**Effective Date**: January 1, 2025

Thank you for trusting ${AppConstants.appName} with your expense tracking needs!
''';
}
