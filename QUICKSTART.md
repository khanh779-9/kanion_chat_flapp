# Hướng dẫn Setup nhanh

## Bước 1: Setup Supabase

1. Truy cập [https://supabase.com](https://supabase.com) và đăng nhập
2. Tạo project mới
3. Vào **SQL Editor** trong dashboard
4. Copy toàn bộ nội dung file `database/kanion_chat_minimal.sql`
5. Paste và chạy SQL script
6. Vào **Settings > API** để lấy:
   - Project URL
   - Anon/Public key

## Bước 2: Cấu hình App

Mở file `lib/core/config/app_config.dart` và thay:

```dart
static const String supabaseUrl = 'https://your-project.supabase.co';
static const String supabaseAnonKey = 'your-anon-key-here';
```

## Bước 3: Install và chạy

```bash
flutter pub get
flutter run
```

## Kiểm tra Database

Sau khi chạy SQL script, kiểm tra trong Supabase:

### Table Editor
- ✅ `profiles` table tồn tại
- ✅ `conversations` table tồn tại  
- ✅ `participants` table tồn tại
- ✅ `messages` table tồn tại

### Policies (RLS)
Vào **Authentication > Policies**, đảm bảo mỗi table có policies:
- profiles: 3 policies (SELECT, UPDATE, INSERT)
- conversations: 2 policies (SELECT, INSERT)
- participants: 2 policies (SELECT, INSERT)
- messages: 4 policies (SELECT, INSERT, UPDATE, DELETE)

### Realtime
Vào **Database > Replication**, enable realtime cho:
- [x] messages
- [x] conversations
- [x] participants

## Test App

1. **Đăng ký tài khoản mới**
   - Mở app → Đăng ký
   - Nhập email, password, tên hiển thị
   - Đăng ký thành công

2. **Kiểm tra Database**
   - Vào Supabase > Authentication > Users
   - User mới sẽ xuất hiện
   - Vào Table Editor > profiles
   - Profile tự động được tạo

3. **Test Chat**
   - Đăng ký thêm 1 user khác (dùng browser khác/incognito)
   - Tìm kiếm user 1 từ user 2
   - Bắt đầu chat
   - Gửi tin nhắn → realtime hoạt động

## Troubleshooting

### Lỗi: "Failed to fetch"
- ✅ Kiểm tra URL và Anon Key đã đúng chưa
- ✅ Kiểm tra internet connection
- ✅ Kiểm tra Supabase project còn active

### Lỗi: "Row Level Security Policy Violation"
- ✅ Chạy lại SQL script
- ✅ Kiểm tra policies đã được tạo đúng

### Tin nhắn không realtime
- ✅ Enable Realtime cho table messages
- ✅ Restart app

### User không tạo profile tự động
- ✅ Kiểm tra trigger `on_auth_user_created` đã được tạo
- ✅ Xóa user và đăng ký lại

## Kết nối PostgreSQL trực tiếp (Optional)

Nếu muốn kết nối trực tiếp với PostgreSQL:

```
Host: db.bumsdakgkbtmedfhcivv.supabase.co
Port: 5432
Database: postgres
User: postgres
Password: (lấy trong Settings > Database > Connection string)
```

**Lưu ý**: Không nên dùng database password trong production app!
