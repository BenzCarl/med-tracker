# 🔔 Medicine Tracker - Notification Testing Guide

## Overview
This guide helps you test the enhanced notification system for Android 12-14 with automatic stock reduction.

---

## ✅ Quick Test (Recommended)

### Step 1: Add Medicine with Schedule
1. Open the app and sign in
2. Tap **"Add Medicine"**
3. Fill in:
   - **Name**: Test Medicine
   - **Dosage**: 500 mg
   - **Initial Stock**: 10
4. Enable **"Schedule & Notifications"** toggle
5. Select time (2 minutes from now)
6. Choose **"Daily"**
7. Tap **"Save Medicine"**

### Step 2: What You'll See
✅ **Immediately**: "Schedule Set!" confirmation notification
✅ **After 10 seconds**: TEST notification showing how your reminder will look (with sound, vibration, full-screen)
✅ **At scheduled time**: Real medicine reminder notification

### Step 3: Verify Stock Reduction
1. Wait for the scheduled time to pass
2. Open the app after 2 hours
3. Check the medicine stock - it should be reduced by 1
4. Check History page - should show "Taken" entry

---

## 📋 Features Explained

### 1. **Triple Notification System**
- **Instant confirmation** when you save
- **Test notification** after 10 seconds (proves notifications work)
- **Scheduled notifications** at exact time with full-screen intent

### 2. **Automatic Stock Reduction**
When the scheduled time arrives:
- Stock automatically reduces by 1
- History log is created with "Taken" status
- Works even if notification is restricted

### 3. **Reconciliation Fallback**
When you open the app:
- Checks for missed doses in the last 2 hours
- Auto-reduces stock for any missed intakes
- Prevents duplicate reductions

---

## 🔧 Permissions Required

### On First Use
The app will request these permissions:

1. **Notifications** (Android 13+)
   - Tap "Allow" when prompted
   
2. **Exact Alarms** (Android 12+)
   - App may open settings
   - Enable "Alarms & reminders"
   
3. **Battery Optimization**
   - Disable battery optimization for reliable notifications
   - Settings > Apps > Med Tracker > Battery > Unrestricted

4. **System Alert Window**
   - For full-screen intent notifications
   - Allow when prompted

---

## 🧪 Advanced Testing

### Test Scenario 1: Immediate Notification
1. Add medicine with schedule 10 seconds from now
2. Wait 10 seconds
3. Notification should appear with sound and vibration

### Test Scenario 2: Daily Schedule
1. Add medicine scheduled for tomorrow 9:00 AM
2. Change device time to tomorrow 9:00 AM
3. Notification should fire immediately

### Test Scenario 3: Stock Reduction
1. Add medicine with stock 5
2. Set schedule for 2 minutes from now
3. Wait 2 minutes for notification
4. Wait another 2 hours
5. Open app - stock should be 4
6. Check History - should show "Taken" entry

### Test Scenario 4: Multiple Days
1. Add medicine
2. Select "Custom" days
3. Choose Mon, Wed, Fri
4. Notification will only fire on those days

---

## 🐛 Troubleshooting

### No Notifications Appearing?

**Check 1: Permissions**
```
Settings > Apps > Med Tracker > Permissions
- Notifications: Allowed
- Alarms & reminders: Allowed
```

**Check 2: Battery Optimization**
```
Settings > Apps > Med Tracker > Battery
- Set to "Unrestricted"
```

**Check 3: Do Not Disturb**
```
Notifications may be silenced
Disable DND or add Med Tracker to priority list
```

### Notifications Delayed?

**Xiaomi/Oppo/Huawei Devices:**
1. Settings > Apps > Med Tracker
2. Enable "Autostart"
3. Disable "Battery optimization"
4. Set to "No restrictions"

### Stock Not Reducing?

**Solution:**
1. Open the app (triggers reconciliation)
2. Wait 2 hours after scheduled time
3. Check History page for logs
4. Verify Firestore rules are deployed

---

## 📱 Device-Specific Settings

### Samsung
- Settings > Apps > Med Tracker > Battery > Unrestricted
- Settings > Apps > Med Tracker > Notifications > Allow

### Xiaomi/MIUI
- Settings > Apps > Manage apps > Med Tracker
- Enable "Autostart"
- Battery saver > No restrictions
- Notifications > Allow all

### Oppo/ColorOS
- Settings > Apps > Med Tracker
- Enable "Startup manager"
- Battery > Power consumption > High

### OnePlus
- Settings > Apps > Med Tracker
- Advanced > Battery optimization > Don't optimize

---

## 📊 Expected Behavior

| Time | Event |
|------|-------|
| Save medicine | ✅ Instant "Schedule Set!" notification |
| +10 seconds | ✅ TEST notification (proves system works) |
| Scheduled time | ✅ Medicine reminder notification |
| +2 hours later | ✅ Stock reduced when app opens |
| History page | ✅ "Taken" entry logged |

---

## 🔍 Debug Console Logs

When testing, check the console for:

✅ **Success messages:**
```
✅ Enhanced Notifications initialized successfully
📅 [EXACT+FULLSCREEN] Scheduled for Test Medicine on weekday 1
🧪 Test notification scheduled for 10 seconds from now
🔔 Instant notification shown: Schedule Set!
```

❌ **Error messages:**
```
❌ Error initializing enhanced notifications: [details]
Error requesting permissions: [details]
```

---

## 💡 Pro Tips

1. **Always grant all permissions** for best reliability
2. **Disable battery optimization** to ensure notifications fire
3. **Test with 10-second notification** to verify system is working
4. **Check History page** to see all logged events
5. **Stock reduction happens on app open** if notification was missed

---

## 🎯 What Makes This Special?

### Traditional Approach ❌
- Notifications may not fire (battery optimization)
- No fallback if notification is missed
- User must manually track intake

### Our Approach ✅
- **Multiple notification layers** (exact alarms + fallback)
- **Auto stock reduction** when time arrives
- **Reconciliation** on app open (catches missed doses)
- **Full-screen intent** for critical alerts
- **Test notification** to verify setup

---

## 📞 Support

If notifications still don't work:
1. Check all permissions are granted
2. Verify Firestore rules are deployed
3. Test with 10-second notification first
4. Check device-specific settings above
5. Review console logs for errors

**Your medicine reminders will work reliably even if some fail!** 🎉
