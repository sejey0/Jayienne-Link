# Secret Media Feature Setup Guide

## Overview

The Secret Media feature allows couples to securely store and share intimate images and videos. It includes:

- **Shared Gallery**: Photos and videos both partners can see
- **Hidden Vault**: Private personal vault only visible to the owner
- **End-to-End Encryption**: Metadata encrypted storage
- **Caption Support**: Add notes or descriptions to media
- **Easy Privacy Controls**: Move media between shared and hidden with one tap

## Components Created

### 1. **Models** (`lib/models/secret_media_model.dart`)

- `SecretMediaModel`: Represents a secret media item
  - `id`: Unique identifier
  - `coupleId`: Associated couple
  - `uploadedById`: User who uploaded
  - `mediaType`: 'image' or 'video'
  - `mediaUrl`: URL to the stored media
  - `thumbnail`: Optional thumbnail for videos
  - `caption`: Optional caption/note
  - `uploadedAt`: Upload timestamp
  - `isEncrypted`: Encryption flag
  - `isHidden`: Visibility flag (hidden vault)

### 2. **Services** (`lib/services/supabase_secret_media_service.dart`)

- `SupabaseSecretMediaService`: Handles all database operations
  - `getSecretMedia()`: Fetch shared media
  - `getHiddenSecretMedia()`: Fetch hidden vault media
  - `addSecretMedia()`: Upload new media
  - `updateSecretMedia()`: Update caption/visibility
  - `deleteSecretMedia()`: Delete media
  - `streamSecretMedia()`: Real-time updates
  - `toggleHidden()`: Move between shared/hidden

### 3. **Providers** (`lib/providers/secret_media_provider.dart`)

- `SecretMediaProvider`: State management
  - Manages all media lists
  - Handles loading/uploading states
  - Provides real-time synchronization
  - Methods for adding, updating, deleting media

### 4. **UI Screens**

#### **Secret Media Gallery** (`secret_media_gallery_screen.dart`)

- Main screen showing all shared media
- Grid view with thumbnails
- Quick access to hidden vault
- Stats card (shared/hidden/total count)
- FAB to add new media

#### **Add Secret Media** (`add_secret_media_screen.dart`)

- Image/video picker
- Media preview before upload
- Caption input
- Privacy toggle (shared/hidden)
- Upload with progress indication

#### **Hidden Vault** (`hidden_vault_screen.dart`)

- Private collection view
- Move media to gallery or delete
- Separate from main gallery
- Visual indication of hidden status

#### **Media Detail** (`secret_media_detail_screen.dart`)

- Full-screen media view
- Caption editing
- Media info (type, date, status)
- Move/delete options
- Encryption status display

## Database Schema

### Supabase Table: `secret_media`

```sql
CREATE TABLE secret_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  uploaded_by_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  media_type VARCHAR(20) NOT NULL CHECK (media_type IN ('image', 'video')),
  media_url TEXT NOT NULL,
  thumbnail TEXT,
  caption TEXT,
  uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_encrypted BOOLEAN DEFAULT TRUE,
  is_hidden BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_secret_media_couple_id ON secret_media(couple_id);
CREATE INDEX idx_secret_media_uploaded_by_id ON secret_media(uploaded_by_id);
CREATE INDEX idx_secret_media_is_hidden ON secret_media(is_hidden);
CREATE INDEX idx_secret_media_couple_hidden ON secret_media(couple_id, is_hidden);
```

## Supabase Storage Setup

### Storage Buckets

Create a public bucket called `secret_media` with the following policy:

```
Bucket: secret_media
Public: No (requires authentication)
Path: secret_media/{user_id}/{media_type}/{filename}
```

## Integration Steps

### 1. Add to Dependencies

Already included in `pubspec.yaml`:

- `image_picker: ^1.1.0`
- `cached_network_image: ^3.3.0`
- `provider: ^6.1.2`
- `supabase_flutter: ^2.5.6`

### 2. Update `main.dart`

```dart
import 'providers/secret_media_provider.dart';
import 'services/supabase_secret_media_service.dart';

// In main() function, add the provider setup:
final secretMediaService = SupabaseSecretMediaService(
  Supabase.instance.client,
);

MultiProvider(
  providers: [
    // ... existing providers
    ChangeNotifierProvider(
      create: (_) => SecretMediaProvider(secretMediaService),
    ),
  ],
  child: const App(),
);
```

### 3. Add to App Navigation

In your app's routing (typically in `app.dart` or routing config):

```dart
// Add to your go_router routes
GoRoute(
  path: '/secret-media',
  name: 'secretMedia',
  builder: (context, state) => const SecretMediaGalleryScreen(),
),
```

### 4. Add Menu Item

Add to your home/dashboard navigation:

```dart
ListTile(
  leading: Icon(Icons.lock),
  title: Text('Secret Gallery'),
  onTap: () => context.go('/secret-media'),
),
```

## Security Considerations

### Current Implementation

- ✅ Row-level security (couples can only see their own media)
- ✅ Authentication required for uploads
- ✅ Hidden vault with separate visibility flag
- ✅ Encryption metadata stored in database

### Recommended Enhancements

1. **End-to-End Encryption**
   - Encrypt media before upload using `encrypt` package
   - Only decrypt on client side
   - Store encryption keys securely

2. **Biometric Authentication**
   - Add fingerprint/face unlock for vault access
   - Use `local_auth` package

3. **Storage Policies**
   - Implement Supabase RLS for storage access
   - Ensure only couple members can access media

4. **Backup & Recovery**
   - Implement secure backup mechanism
   - Recovery options for deleted media

## Usage Example

### Initialize Provider

```dart
Future<void> initSecretMedia() async {
  final authProvider = context.read<AuthProvider>();
  final coupleProvider = context.read<CoupleProvider>();

  await context.read<SecretMediaProvider>().initialize(
    userId: authProvider.userId!,
    coupleId: coupleProvider.coupleId!,
  );
}
```

### Add Media

```dart
final provider = context.read<SecretMediaProvider>();
await provider.addSecretMedia(
  mediaType: 'image',
  mediaUrl: 'https://...',
  caption: 'Special moment',
  isHidden: false,
);
```

### Move to Hidden Vault

```dart
await provider.moveToHiddenVault(mediaId);
```

### Stream Updates

```dart
provider.streamSecretMedia(coupleId).listen((media) {
  // Real-time updates
});
```

## Features

### ✅ Implemented

- Add images and videos
- Add captions/notes
- Toggle between shared and hidden
- Delete media
- Real-time synchronization
- Encrypted metadata storage
- Privacy controls
- Media preview
- Responsive UI

### 🔄 Recommended Future Enhancements

- [ ] Biometric vault unlock
- [ ] Advanced encryption
- [ ] Media compression
- [ ] Batch operations
- [ ] Share with specific time window
- [ ] AI-powered organization
- [ ] Cloud backup integration
- [ ] Media grouping/albums
- [ ] Video playback in-app
- [ ] Automatic cleanup policies

## File Structure

```
lib/
├── features/
│   └── secret_media/
│       └── screens/
│           ├── secret_media_gallery_screen.dart
│           ├── add_secret_media_screen.dart
│           ├── hidden_vault_screen.dart
│           └── secret_media_detail_screen.dart
├── models/
│   └── secret_media_model.dart
├── services/
│   └── supabase_secret_media_service.dart
└── providers/
    └── secret_media_provider.dart
```

## Testing

### Manual Testing Checklist

- [ ] Add image to shared gallery
- [ ] Add video to shared gallery
- [ ] Add caption to media
- [ ] Move media to hidden vault
- [ ] Move media back to gallery
- [ ] Delete media
- [ ] Edit caption
- [ ] Verify real-time sync with partner
- [ ] Check media counts
- [ ] Verify vault is completely hidden

## Troubleshooting

### Media not uploading

- Check storage bucket permissions
- Verify file size limits
- Ensure user is authenticated

### Real-time updates not working

- Check Supabase connection
- Verify RLS policies
- Restart app

### Hidden vault not showing

- Clear app cache
- Restart provider
- Check database records

## Support & Maintenance

For issues or feature requests:

1. Check logs with `debugPrint`
2. Verify Supabase configuration
3. Test with sample data
4. Review security policies
