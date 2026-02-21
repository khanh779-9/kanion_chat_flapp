# Kanion Chat App

Ứng dụng chat Flutter với Supabase backend.

## Cấu hình

### 1. Cập nhật Supabase Credentials

Mở file `lib/config/supabase_config.dart` và cập nhật:

```dart
static const String supabaseAnonKey = 'YOUR_ACTUAL_ANON_KEY';
```

Để lấy Supabase Anon Key:
1. Đăng nhập vào https://supabase.com
2. Chọn project của bạn
3. Vào Settings > API
4. Copy giá trị "anon public" key

### 2. Cài đặt dependencies

```bash
flutter pub get
```

### 3. Chạy ứng dụng

```bash
flutter run
```

## Cấu trúc database

Database đã được thiết kế với các bảng:
- **profiles**: Thông tin người dùng
- **Conversations**: Các cuộc trò chuyện (1-1 hoặc nhóm)
- **Messages**: Tin nhắn
- **Participants**: Thành viên trong cuộc trò chuyện
- **Attachments**: File đính kèm
- **MessageStatus**: Trạng thái tin nhắn
- **UserContacts**: Danh bạ
- **Notifications**: Thông báo
- **BlockedUsers**: Người dùng bị chặn
- **GroupSettings**: Cài đặt nhóm

## Tính năng

### Đã implement:
- ✅ Đăng ký/Đăng nhập
- ✅ Danh sách cuộc trò chuyện
- ✅ Chat 1-1 realtime
- ✅ Tìm kiếm người dùng
- ✅ Tạo cuộc trò chuyện mới
- ✅ Hồ sơ người dùng
- ✅ Đăng xuất

### Có thể mở rộng:
- 📝 Chat nhóm
- 📝 Gửi hình ảnh/file
- 📝 Thông báo push
- 📝 Xem trạng thái tin nhắn (đã gửi/đã xem)
- 📝 Emoji reactions
- 📝 Chỉnh sửa/xóa tin nhắn
- 📝 Tìm kiếm tin nhắn
- 📝 Voice/Video call

## Cấu trúc thư mục

```
lib/
├── config/              # Cấu hình
│   └── supabase_config.dart
├── models/              # Data models
│   ├── conversation.dart
│   ├── message.dart
│   ├── user_profile.dart
│   └── contact.dart
├── screens/             # UI screens
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── conversations_screen.dart
│   ├── chat_screen.dart
│   ├── new_conversation_screen.dart
│   └── profile_screen.dart
├── services/            # Business logic
│   ├── auth_service.dart
│   ├── chat_service.dart
│   └── database_service.dart
├── utils/               # Utilities
│   └── constants.dart
└── main.dart
```

## Lưu ý quan trọng

1. **Supabase Foreign Keys**: Bạn cần tạo foreign key constraints trong Supabase để join tables hoạt động đúng:
   - `Messages_sender_id_fkey` từ Messages.sender_id -> profiles.user_id
   - `Participants_user_id_fkey` từ Participants.user_id -> profiles.user_id
   - `UserContacts_friend_id_fkey` từ UserContacts.friend_id -> profiles.user_id

2. **Row Level Security (RLS)**: Cần cấu hình RLS policies trong Supabase để bảo mật dữ liệu.

3. **Storage Buckets**: Tạo bucket `avatars` trong Supabase Storage để upload avatar.

4. **Realtime**: Đảm bảo Realtime được enable cho các tables cần thiết (Messages, Conversations).

## Kết nối Database

Thông tin kết nối PostgreSQL:
```
Host: db.bumsdakgkbtmedfhcivv.supabase.co
Port: 5432
Database: postgres
User: postgres
Password: G0Lp3NJdGCjy6P2e
```

## Hỗ trợ

Nếu gặp vấn đề, kiểm tra:
1. Supabase credentials đã đúng chưa
2. Database schema đã được import đầy đủ
3. Foreign keys và RLS policies đã được thiết lập
4. Internet connection
