# 📅 Medicine Scheduling & Notifications Guide

## Overview
Your medication tracker now includes **in-app scheduling with local notifications** when adding medicines. This ensures you never miss a dose!

## ✨ Features

### 1. **Schedule While Adding Medicine**
When you add a new medicine, you can immediately set up a reminder schedule with:
- **Time Selection**: Pick the exact time for your medication reminder
- **Day Selection**: Choose from:
  - **Daily**: Every day of the week
  - **Weekdays**: Monday through Friday
  - **Weekends**: Saturday and Sunday
  - **Custom**: Select specific days
- **Interval Options**: Control how often reminders occur:
  - Daily (once per day)
  - Every 2 hours (q2h)
  - Every 4 hours (q4h)
  - Every 6 hours (q6h)
  - Every 12 hours (q12h)

### 2. **Smart Notifications**
- **Exact Alarms**: The app requests permission for precise notification timing on Android 12+
- **Background Notifications**: Works even when the app is closed
- **Recurring Reminders**: Automatically repeats based on your schedule
- **One-Shot Immediate**: Ensures near-time reminders fire today

### 3. **Notification History**
All notification events are logged to your history:
- `Scheduled`: When a schedule is created
- `Reminder`: When notification fires
- `Opened`: When you tap the notification
- `Test`: For test notifications

## 🚀 How to Use

### Adding Medicine with Schedule

1. **Navigate to Add Medicine**
   - Tap "Add Medicine" from your dashboard

2. **Fill in Medicine Details**
   - Name, dosage, description, dates, stock, etc.

3. **Enable Schedule & Notifications** (enabled by default)
   - Toggle ON to create a schedule with the medicine
   - If disabled, only the medicine will be saved (no notifications)

4. **Select Time**
   - Tap the "Select Time" field
   - Pick your preferred reminder time

5. **Choose Days**
   - Select from Daily, Weekdays, Weekends, or Custom
   - For Custom, tap individual day chips to select/deselect

6. **Set Interval**
   - Choose how often you need reminders
   - Daily for once-per-day medications
   - Hourly intervals for more frequent doses

7. **Submit**
   - Tap "Submit" to save medicine and schedule
   - Notifications are automatically configured!

### Managing Permissions

#### Android 13+ Notification Permission
The app will automatically request notification permission when you create a schedule.

#### Exact Alarms (Android 12+)
For precise timing, enable "Exact Alarms" in system settings:
1. Go to Settings > Apps > Med Tracker
2. Find "Alarms & Reminders" or "Exact Alarms"
3. Enable the permission

#### Battery Optimization (Recommended)
For reliable notifications on some devices (Oppo, Xiaomi, Huawei):
1. Disable battery optimization for Med Tracker
2. Allow "Autostart" for the app
3. This ensures notifications fire even in deep sleep

## 🔧 Technical Details

### Notification Architecture
- **Service**: `notification_service.dart` handles all notification logic
- **Scheduling**: Uses `flutter_local_notifications` with timezone support
- **Firestore Integration**: Schedules are saved to `users/{userId}/schedules`
- **History Logging**: Events logged to `users/{userId}/history`

### Firestore Data Structure

#### Medicine Document
```json
{
  "name": "Aspirin",
  "dosage": "100 mg",
  "frequency": "Daily",
  "description": "Pain relief",
  "startDate": "2025/01/01",
  "endDate": "2025/12/31",
  "initialStock": 30,
  "illness": "Headache",
  "createdAt": Timestamp
}
```

#### Schedule Document
```json
{
  "medicineName": "Aspirin",
  "dosage": "100 mg",
  "time": "9:00 AM",
  "days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
  "interval": "Daily",
  "createdAt": Timestamp
}
```

#### History Document
```json
{
  "medicineName": "Aspirin",
  "status": "Reminder",
  "timestamp": Timestamp
}
```

### Firestore Security Rules
The `firestore.rules` file ensures:
- Users can only access their own data
- Required fields are validated
- Data types are enforced
- Status values are restricted to valid options

## 🧪 Testing

### Test Notifications
From the Schedule page, you can:
1. **Instant Test**: Fires immediately
2. **Scheduled Test**: Fires after 10 seconds
3. **Debug**: View all pending notifications in console

### Verification Checklist
- [ ] Medicine saves successfully
- [ ] Schedule appears in Firestore
- [ ] Notification permissions granted
- [ ] Test notification received
- [ ] Scheduled notification fires at correct time
- [ ] Notification appears when app is closed
- [ ] Tapping notification opens app
- [ ] History logs notification events

## 📱 Deployment

### Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### Build & Test
```bash
flutter pub get
flutter run
```

## 🐛 Troubleshooting

### Notifications Not Firing
1. **Check Permissions**: Ensure notification permission is granted
2. **Exact Alarms**: Enable in system settings
3. **Battery Optimization**: Disable for the app
4. **Autostart**: Enable on OEM devices (Oppo, Xiaomi, etc.)
5. **Debug**: Use the debug button to view pending notifications

### Schedule Not Saving
1. **Check Firestore Rules**: Ensure rules are deployed
2. **Check Console**: Look for error messages
3. **Verify Fields**: Ensure all required fields are filled

### Time Zone Issues
The app uses the device's local timezone automatically via the `timezone` package.

## 🎯 Best Practices

1. **Test First**: Always test notifications before relying on them
2. **Battery Settings**: Configure device settings for reliability
3. **Regular Review**: Check your schedules periodically
4. **Backup**: Firestore provides automatic data backup
5. **Updates**: Keep the app updated for latest features

## 📚 Reference

### YouTube Tutorial
[Scheduled Notifications • Flutter Tutorial](https://www.youtube.com/watch?v=i98p9dJ4lhI)

### Packages Used
- `flutter_local_notifications` - Local notification scheduling
- `timezone` - Timezone handling
- `android_intent_plus` - System settings navigation
- `cloud_firestore` - Data persistence
- `firebase_auth` - User authentication

## 🆘 Support

If you encounter issues:
1. Check the console logs for error messages
2. Verify Firestore rules are deployed
3. Ensure all permissions are granted
4. Test with simple schedules first
5. Consult the YouTube tutorial for visual guidance

---

**Happy Scheduling! 💊⏰**
