# Secret Media Feature - Implementation Checklist

## 📋 Phase 1: Database Setup

### Supabase Database

- [ ] **Create Table**: Execute SQL from `secret_media_schema.sql` in Supabase SQL Editor
  - Go to Supabase Dashboard → SQL Editor
  - Create new query
  - Paste all SQL from `secret_media_schema.sql`
  - Run query
- [ ] **Verify Table Created**
  - Check Table Editor in Supabase
  - Confirm `secret_media` table exists with all columns
  - Verify indexes are created

- [ ] **Enable Storage Bucket**
  - Go to Storage in Supabase Dashboard
  - Create new bucket: `secret_media`
  - Make it private (NOT public)
  - Configure storage policies (see SECRET_MEDIA_FEATURE_SETUP.md)

### Storage Policies

- [ ] **Upload Policy**: Users can upload to `secret_media/{uid}/*`
- [ ] **Download Policy**: Users can access files from their couple's storage
- [ ] **Delete Policy**: Users can delete their own uploads

---

## 📱 Phase 2: Flutter App Integration

### Update main.dart

- [ ] Add to imports:

  ```dart
  import 'services/supabase_secret_media_service.dart';
  import 'providers/secret_media_provider.dart';
  ```

- [ ] Initialize service in `main()`:

  ```dart
  final secretMediaService = SupabaseSecretMediaService(
    Supabase.instance.client,
  );
  ```

- [ ] Add provider to MultiProvider:
  ```dart
  ChangeNotifierProvider(
    create: (_) => SecretMediaProvider(secretMediaService),
  ),
  ```

### Update App Navigation

- [ ] Open your app.dart or routing file
- [ ] Add route for secret media:
  ```dart
  GoRoute(
    path: '/secret-media',
    name: 'secretMedia',
    builder: (context, state) => const SecretMediaGalleryScreen(),
  ),
  ```

### Add UI Navigation

- [ ] Add button/menu item in home screen or drawer:

  ```dart
  ListTile(
    leading: Icon(Icons.lock),
    title: Text('Secret Gallery'),
    subtitle: Text('Shared photos & videos'),
    onTap: () => context.go('/secret-media'),
  ),
  ```

- [ ] OR add tab in existing tab bar if applicable

### Initialize Provider on App Start

- [ ] In home screen or main app state:

  ```dart
  @override
  void initState() {
    super.initState();
    _initSecretMedia();
  }

  Future<void> _initSecretMedia() async {
    final authProvider = context.read<AuthProvider>();
    final coupleProvider = context.read<CoupleProvider>();

    if (authProvider.userId != null && coupleProvider.coupleId != null) {
      await context.read<SecretMediaProvider>().initialize(
        userId: authProvider.userId!,
        coupleId: coupleProvider.coupleId!,
      );
    }
  }
  ```

---

## 🧪 Phase 3: Testing

### Unit Tests

- [ ] Test SecretMediaModel serialization:

  ```dart
  test('SecretMediaModel fromJson/toJson', () {
    final json = {...};
    final model = SecretMediaModel.fromJson(json);
    expect(model.id, equals('test-id'));
  });
  ```

- [ ] Test Provider methods:
  - [ ] addSecretMedia()
  - [ ] updateCaption()
  - [ ] deleteSecretMedia()
  - [ ] moveToHiddenVault()
  - [ ] moveToShared()

### Manual Testing

- [ ] **Add Image**
  - [ ] Navigate to Secret Gallery
  - [ ] Tap + button
  - [ ] Select image from gallery
  - [ ] Add caption
  - [ ] Tap upload
  - [ ] Verify image appears in gallery

- [ ] **Add Video**
  - [ ] Tap + button
  - [ ] Select video from gallery
  - [ ] Add caption
  - [ ] Tap upload
  - [ ] Verify video thumbnail appears

- [ ] **Hidden Vault**
  - [ ] Add image with "Hidden" toggle ON
  - [ ] Verify it appears in Hidden Vault (lock icon)
  - [ ] Verify count badge appears in app bar
  - [ ] Verify it does NOT appear in main gallery

- [ ] **Move Media**
  - [ ] Add shared image
  - [ ] Tap menu → "Move to Vault"
  - [ ] Verify it moves to hidden vault
  - [ ] Tap menu → "Move to Gallery"
  - [ ] Verify it moves back

- [ ] **Edit Caption**
  - [ ] Open media detail
  - [ ] Tap edit icon
  - [ ] Modify caption
  - [ ] Save changes
  - [ ] Verify caption updates

- [ ] **Delete Media**
  - [ ] Open media detail
  - [ ] Tap menu → Delete
  - [ ] Confirm deletion
  - [ ] Verify media disappears
  - [ ] Verify count updates

- [ ] **Stats Display**
  - [ ] Add 3 shared images
  - [ ] Add 2 hidden images
  - [ ] Verify stats show: Shared: 3, Hidden: 2, Total: 5

- [ ] **Real-time Sync**
  - [ ] Open app on two devices
  - [ ] Add media on device 1
  - [ ] Verify it appears on device 2 automatically

---

## 🔐 Phase 4: Security Review

### Privacy Controls

- [ ] Verify hidden media is only visible to uploader
- [ ] Verify partner cannot see hidden vault
- [ ] Test with different user accounts
- [ ] Verify RLS policies enforce couple-level access

### Storage Security

- [ ] Verify bucket is not public
- [ ] Test that users can't access other couples' media
- [ ] Verify storage policies prevent unauthorized downloads

### Data Validation

- [ ] Test max file size limits
- [ ] Test invalid file formats
- [ ] Test concurrent uploads
- [ ] Test network interruption handling

---

## 📊 Phase 5: Performance & Optimization

- [ ] **Test with Large Media Collection**
  - [ ] Add 50+ images
  - [ ] Verify gallery loads smoothly
  - [ ] Check memory usage
  - [ ] Monitor database queries

- [ ] **Test Slow Network**
  - [ ] Throttle network connection
  - [ ] Verify upload progress indicator works
  - [ ] Verify error handling works

- [ ] **Test Device Storage**
  - [ ] Run on low-storage device
  - [ ] Verify cached images don't consume excessive space

- [ ] **Load Testing**
  - [ ] Add media rapidly
  - [ ] Verify no crashes
  - [ ] Check database performance

---

## 🚀 Phase 6: Deployment

### Pre-Release

- [ ] Run `flutter analyze` - no errors
- [ ] Run `flutter test` - all tests pass
- [ ] Build release APK
- [ ] Test on actual devices
- [ ] Test on Android 8+ devices
- [ ] Test on iOS if applicable

### Release Notes

- [ ] Document new feature
- [ ] Include usage instructions
- [ ] Note security features
- [ ] List known limitations

### Post-Release

- [ ] Monitor crash logs
- [ ] Monitor user feedback
- [ ] Track feature usage metrics
- [ ] Plan future enhancements

---

## 🔄 Future Enhancements

### Priority 1 (High)

- [ ] Biometric authentication for vault access
- [ ] Advanced encryption before upload
- [ ] Batch operations (select multiple)
- [ ] Video playback within app

### Priority 2 (Medium)

- [ ] Media compression
- [ ] Album/folder organization
- [ ] Sharing with expiration time
- [ ] Auto-cleanup policies

### Priority 3 (Low)

- [ ] AI-powered organization
- [ ] Advanced search
- [ ] Metadata editing
- [ ] Export functionality

---

## 📚 File Reference

| File                                 | Purpose            |
| ------------------------------------ | ------------------ |
| `secret_media_model.dart`            | Data model         |
| `supabase_secret_media_service.dart` | Database service   |
| `secret_media_provider.dart`         | State management   |
| `secret_media_gallery_screen.dart`   | Main gallery view  |
| `add_secret_media_screen.dart`       | Upload screen      |
| `hidden_vault_screen.dart`           | Private vault      |
| `secret_media_detail_screen.dart`    | Detail/edit view   |
| `secret_media_schema.sql`            | Database setup     |
| `SECRET_MEDIA_FEATURE_SETUP.md`      | Full documentation |

---

## ❓ Troubleshooting

### Issue: "Media not uploading"

- [ ] Check internet connection
- [ ] Verify Supabase credentials
- [ ] Check storage bucket permissions
- [ ] Review file size limits
- [ ] Check device storage space

### Issue: "Real-time updates not working"

- [ ] Restart app
- [ ] Check Supabase status
- [ ] Verify network connection
- [ ] Check RLS policies

### Issue: "Hidden media visible to partner"

- [ ] Clear app cache
- [ ] Restart app
- [ ] Verify RLS policies in Supabase
- [ ] Check database directly

### Issue: "Provider not initialized"

- [ ] Ensure initialize() is called
- [ ] Check userId and coupleId are not null
- [ ] Verify MultiProvider includes SecretMediaProvider

---

## ✅ Completion Checklist

General Completion:

- [ ] All files created
- [ ] Database setup complete
- [ ] App navigation added
- [ ] Provider initialized
- [ ] Manual testing passed
- [ ] Security verified
- [ ] Performance tested
- [ ] Ready for release

---

**Created**: April 25, 2026  
**Last Updated**: April 25, 2026  
**Version**: 1.0
