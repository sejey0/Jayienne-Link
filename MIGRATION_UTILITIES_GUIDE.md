# 🔄 Firebase to Supabase Data Migration Guide

## 📦 Migration Utilities Complete!

You now have **automated tools** to migrate your existing Firebase data to Supabase with just a few button clicks!

---

## 🎯 What's Been Added

### **3 New Migration Tools**

1. **FirebaseDataExporter** (`lib/utils/firebase_data_exporter.dart`)
   - Exports all Firebase Firestore data
   - Supports users, couples, invite codes, and locations
   - Generates JSON export file
   - Progress tracking and error handling

2. **SupabaseDataImporter** (`lib/utils/supabase_data_importer.dart`)
   - Imports Firebase export into Supabase
   - Maintains referential integrity
   - Maps Firebase IDs to Supabase UUIDs
   - Batch processing for performance
   - Verification and statistics

3. **MigrationManagerScreen** (`lib/features/migration/migration_manager_screen.dart`)
   - Beautiful UI for migration process
   - Real-time progress tracking
   - Export/Import with visual feedback
   - Statistics and verification
   - Error handling with user-friendly messages

### **Easy Access**

- Navigate to: **Settings → Debug Tools → Firebase → Supabase Migration**
- Available in debug mode only

---

## 🚀 Quick Migration (3 Steps)

### **Step 1: Export Firebase Data**

```
1. Open the app in debug mode
2. Go to Settings → Debug Tools
3. Click "Firebase → Supabase Migration"
4. Click "Step 1: Export Firebase Data"
5. Wait for export to complete (usually < 1 minute)
```

### **Step 2: Setup Supabase** (One-time)

```
1. Create Supabase project at supabase.com
2. Run supabase_migration.sql in SQL Editor
3. Create 'profile-photos' storage bucket
4. Update .env with your credentials
5. Restart the app
```

### **Step 3: Import to Supabase**

```
1. In Migration Manager, click "Step 3: Import to Supabase"
2. Confirm the import
3. Wait for import to complete
4. Verify the results
```

**Total Time**: ~10-20 minutes (depending on data size)

---

## 📊 What Gets Migrated

| Data Type          | Description            | Firebase → Supabase              |
| ------------------ | ---------------------- | -------------------------------- |
| **Users**          | All user profiles      | ✅ Full migration                |
| **Couples**        | Relationship data      | ✅ Full migration                |
| **Invite Codes**   | Active & expired codes | ✅ Full migration                |
| **Locations**      | GPS history            | ✅ Full migration                |
| **Profile Photos** | User images            | ⚠️ URLs migrated, see note below |

### **Important: Profile Photos**

- **Firebase Storage URLs**: Migrated as-is, still point to Firebase
- **Base64 photos**: Automatically migrated
- **Recommendation**: Re-upload photos after migration for Supabase Storage

---

## 🔍 Migration Features

### **Smart ID Mapping**

- Firebase UIDs → Supabase UUIDs
- Maintains all relationships automatically
- Couple linkages preserved
- Location ownership intact

### **Batch Processing**

- Locations imported in batches of 100
- Prevents memory issues
- Progress tracking
- Retry logic

### **Error Handling**

- Continues on individual failures
- Logs all errors
- Reports success/failure counts
- Rollback safe (no Firebase data deleted)

### **Verification**

- Post-import statistics
- Database health check
- Integrity verification
- Visual confirmation

---

## 📋 Pre-Migration Checklist

### **Before You Start**

- [ ] Supabase project created
- [ ] Migration SQL script executed
- [ ] Storage bucket created
- [ ] .env file configured with credentials
- [ ] App restarted after .env changes
- [ ] Backup of Firebase data (it's not deleted, but good practice)

### **Test Environment First**

- [ ] Create test Supabase project
- [ ] Run migration on test project
- [ ] Verify all data imported correctly
- [ ] Test app functionality with Supabase
- [ ] Only then migrate production data

---

## 🎮 Using the Migration Manager

### **Interface Overview**

```
┌─────────────────────────────────────┐
│  Firebase → Supabase Migration      │
├─────────────────────────────────────┤
│  📋 Migration Instructions          │
│  1. Export Firebase data            │
│  2. Setup Supabase                  │
│  3. Import to Supabase              │
│  4. Verify migration                │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  📊 Firebase Data Statistics        │
│  Users:         42                  │
│  Couples:       21                  │
│  Invite Codes:  15                  │
│  Locations:     1,234               │
└─────────────────────────────────────┘

  [Step 1: Export Firebase Data]

┌─────────────────────────────────────┐
│  ✅ Data Exported                   │
│  Size: 45.2 KB                      │
└─────────────────────────────────────┘

  [Step 3: Import to Supabase]

┌─────────────────────────────────────┐
│  ✅ Import Complete                 │
│  Users Imported:       42           │
│  Couples Imported:     21           │
│  Invite Codes:         15           │
│  Locations Imported:   1,234        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  💡 Pro Tips                        │
│  • Firebase data NOT deleted        │
│  • Migrate during low-traffic       │
│  • Verify before switching users    │
└─────────────────────────────────────┘
```

---

## ⚡ Advanced Usage

### **Programmatic Export**

```dart
final exporter = FirebaseDataExporter();

// Export all data
final jsonData = await exporter.exportToJson();

// Get statistics
final stats = await exporter.getMigrationStats();
print('Users: ${stats['users']}');

// Test connection
final connected = await exporter.testConnection();
```

### **Programmatic Import**

```dart
final importer = SupabaseDataImporter();

// Import from JSON
final results = await importer.importFromJson(jsonData);
print('Imported ${results['users']} users');

// Verify import
final stats = await importer.verifyImport();

// Get ID mappings
final mappings = importer.getIdMappings();
```

### **Custom Migration Script**

```dart
// For advanced users who want more control
final exporter = FirebaseDataExporter();
final importer = SupabaseDataImporter();

// Export
final data = await exporter.exportAllData();

// Modify data if needed
// ... custom transformations ...

// Import
final results = await importer.importAllData(data);
```

---

## 🔒 Safety Features

### **Non-Destructive**

- ✅ Firebase data is **NEVER deleted**
- ✅ Firebase remains fully functional during migration
- ✅ Can rollback by simply using Firebase services
- ✅ Hybrid mode supported (use both simultaneously)

### **Idempotent**

- ✅ Can run import multiple times safely
- ✅ Existing Supabase data won't cause errors
- ✅ ID mappings prevent duplicates
- ✅ Clear mappings for fresh imports

### **Transaction-Safe**

- ✅ Batch operations with retry logic
- ✅ Continues on individual failures
- ✅ Reports all errors clearly
- ✅ Easy to re-run failed imports

---

## 🐛 Troubleshooting

### **"Export failed: Permission denied"**

- Check Firebase rules allow reads
- Ensure user is authenticated
- Verify app has Firebase initialized

### **"Import failed: Connection error"**

- Check .env file has correct credentials
- Verify Supabase project is active (not paused)
- Test Internet connection
- Restart app after changing .env

### **"Import failed: Table does not exist"**

- Run supabase_migration.sql script
- Check all 4 tables created (users, couples, invite_codes, locations)
- Verify SQL script completed without errors

### **"Some data not imported"**

- Check console logs for specific errors
- Common: Missing relationships (couple_id, etc.)
- Solution: Ensure export was complete
- Re-run import after fixing issues

### **"Stats don't match"**

- Some data may be filtered (expired codes, etc.)
- Check for data validation errors in logs
- Verify Firebase data integrity
- Contact support if significant discrepancy

---

## 📈 Migration Phases

### **Phase 1: Testing** (Day 1)

1. Create test Supabase project
2. Export small sample from Firebase
3. Import to test Supabase
4. Verify functionality
5. Test app with Supabase services

### **Phase 2: Staging** (Day 2-7)

1. Create production Supabase project
2. Full Firebase export
3. Import to production Supabase
4. Parallel testing (Firebase + Supabase)
5. Monitor for issues

### **Phase 3: Gradual Switch** (Week 2)

1. New users → Supabase
2. Existing users → Still Firebase
3. Gradually migrate user sessions
4. Monitor performance and errors
5. Adjust as needed

### **Phase 4: Full Migration** (Week 3-4)

1. All users on Supabase
2. Firebase as read-only backup
3. Monitor for 1-2 weeks
4. Decommission Firebase (optional)

---

## ✅ Post-Migration Checklist

### **Immediately After Import**

- [ ] Verify all data imported
- [ ] Check relationships intact
- [ ] Test authentication
- [ ] Test couple linking
- [ ] Test location sharing

### **Before Going Live**

- [ ] Update app to use Supabase services
- [ ] Test all features thoroughly
- [ ] Verify real-time updates work
- [ ] Check profile photos display
- [ ] Test offline sync

### **Production Deployment**

- [ ] Deploy app update with Supabase
- [ ] Monitor error logs
- [ ] Watch Supabase dashboard
- [ ] Have rollback plan ready
- [ ] Keep Firebase active as backup

---

## 🎯 Success Criteria

Your migration is successful when:

- ✅ All data visible in Supabase dashboard
- ✅ Statistics match (or very close)
- ✅ App functions normally with Supabase
- ✅ Real-time updates working
- ✅ No authentication issues
- ✅ Location sharing works
- ✅ All tests passing

---

## 🆘 Need Help?

### **During Migration**

1. Check console logs for detailed errors
2. Review SUPABASE_COMPLETE_MIGRATION_GUIDE.md
3. Use built-in debug tools
4. Verify .env configuration

### **After Migration**

1. Use Supabase dashboard for data inspection
2. Check Settings → Storage Information
3. Test all features manually
4. Review migration statistics

---

## 🎉 You're All Set!

Your migration utilities are **production-ready** and include:

- ✅ Automated export from Firebase
- ✅ Intelligent import to Supabase
- ✅ Beautiful UI with progress tracking
- ✅ Comprehensive error handling
- ✅ Verification and statistics

**Ready to migrate? Open Settings → Debug Tools → Firebase → Supabase Migration!** 🚀
