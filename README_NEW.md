# Kanion Chat

> **Ứng dụng chat realtime theo phong cách Telegram với Flutter & Supabase**

## ✨ Tính năng

- 🔐 **Xác thực**: Đăng ký/Đăng nhập với email
- 💬 **Chat Realtime**: Tin nhắn realtime giữa các users
- 👥 **Chat 1-1**: Trò chuyện riêng tư
- 🔍 **Tìm kiếm**: Tìm người dùng theo tên
- 👤 **Profile**: Quản lý thông tin cá nhân
- 📱 **UI giống Telegram**: Giao diện hiện đại, mượt mà

## 🏗️ Kiến trúc

```
lib/
├── core/                      # Core utilities
│   ├── config/               # App configuration
│   ├── di/                   # Dependency injection
│   ├── models/               # Base models
│   ├── theme/                # App theme (Telegram-like)
│   └── utils/                # Helpers (datetime, etc)
├── features/                  # Features (Clean Architecture)
│   ├── auth/
│   │   └── data/
│   │       └── repositories/ # Auth repository
│   ├── chat/
│   │   └── data/
│   │       ├── models/       # Conversation, Message models
│   │       └── repositories/ # Chat repository
│   └── profile/
│       └── data/
│           ├── models/       # UserProfile model
│           └── repositories/ # Profile repository
└── presentation/              # UI Layer
    ├── auth/                 # Login, Register
    ├── home/                 # Chat list
    ├── chat/                 # Chat screen
    ├── search/               # User search
    └── profile/              # Profile screen
```

## 📋 Yêu cầu

- Flutter SDK >= 3.11.0
- Dart SDK >= 3.11.0
- Supabase account

## 🚀 Cài đặt

### 1. Clone & Install

```bash
git clone <your-repo>
cd kanion_chat_flapp
flutter pub get
```

### 2. Setup Database

**Tạo project trên Supabase:**
1. Truy cập [supabase.com](https://supabase.com)
2. Tạo project mới
3. Copy URL và Anon Key

**Import database schema:**
```bash
# Trong Supabase Dashboard > SQL Editor
# Copy và chạy nội dung file: database/kanion_chat_minimal.sql
```

### 3. Cấu hình App

Mở `lib/core/config/app_config.dart` và thay đổi:

```dart
class AppConfig {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';
}
```

### 4. Chạy app

```bash
flutter run
```

## 📊 Database Schema

Database tối giản chỉ với 4 bảng chính:

### profiles
- id (UUID, PK)
- user_id (UUID, FK -> auth.users)
- display_name, avatar_url, bio, phone
- last_seen (để hiển thị online status)

### conversations
- id (UUID, PK)
- name, avatar_url (cho group chat)
- is_group (BOOLEAN)
- created_by (UUID)

### participants
- id (UUID, PK)
- conversation_id, user_id
- role (admin/member)
- last_read_at (để đếm unread)

### messages
- id (UUID, PK)
- conversation_id, sender_id
- content, type (text/image/file)
- reply_to, edited

## 🎨 Theme & Colors

App sử dụng màu sắc Telegram:
- Primary Blue: `#2AABEE`
- Dark Blue: `#229ED9`
- Online Green: `#4DCD5E`
- Chat Bubble Mine: `#EFFFDE`
- Chat Bubble Other: `#FFFFFF`

## 🔒 Security

- ✅ Row Level Security (RLS) enabled
- ✅ Users chỉ xem conversations họ tham gia
- ✅ Users chỉ gửi messages trong conversations của họ
- ✅ Profile public read, private write

## 🛠️ Development

### Run tests
```bash
flutter test
```

### Build APK
```bash
flutter build apk --release
```

## 📝 TODO

- [ ] Group chat nhiều người
- [ ] Gửi hình ảnh/files
- [ ] Voice messages
- [ ] Video call
- [ ] Push notifications
- [ ] Message reactions
- [ ] Edit/Delete messages
- [ ] Dark mode toggle
- [ ] Typing indicators
- [ ] Read receipts

## 📄 License

MIT License

---

**Made with ❤️ using Flutter & Supabase**
