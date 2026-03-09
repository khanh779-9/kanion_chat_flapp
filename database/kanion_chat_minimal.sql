-- ========================================
-- KANION CHAT - MINIMAL DATABASE SCHEMA
-- PostgreSQL for Supabase
-- ========================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ========================================
-- TABLE: profiles
-- Lưu thông tin người dùng (chỉ 3 cột như schema gốc)
-- ========================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    birth_day DATE,
    phone TEXT,
    bio TEXT,
    avatar_url TEXT
);

-- Index cho tìm kiếm
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);

-- ========================================
-- TABLE: conversations
-- Lưu cuộc trò chuyện (đổi tên cột để match schema gốc)
-- ========================================
CREATE TABLE IF NOT EXISTS public.conversations (
    conversation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_name TEXT,
    is_group BOOLEAN,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_conversations_created_at ON public.conversations(created_at DESC);

-- ========================================
-- TABLE: participants
-- Người tham gia cuộc trò chuyện (đổi tên cột)
-- ========================================
CREATE TABLE IF NOT EXISTS public.participants (
    participant_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    conversation_id UUID REFERENCES public.conversations(conversation_id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_participants_user_id ON public.participants(user_id);
CREATE INDEX IF NOT EXISTS idx_participants_conversation_id ON public.participants(conversation_id);

-- ========================================
-- TABLE: messages
-- Tin nhắn (đổi tên cột để match schema gốc)
-- ========================================
CREATE TABLE IF NOT EXISTS public.messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES public.conversations(conversation_id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    content TEXT,
    is_read BOOLEAN,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);

-- ========================================
-- TABLE: conversation_preferences
-- Tùy chọn theo từng user cho từng conversation (pin/archive)
-- ========================================
CREATE TABLE IF NOT EXISTS public.conversation_preferences (
    preference_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES public.conversations(conversation_id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    is_pinned BOOLEAN DEFAULT false NOT NULL,
    is_archived BOOLEAN DEFAULT false NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE(conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_pref_user_id ON public.conversation_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_conv_pref_conversation_id ON public.conversation_preferences(conversation_id);

-- ========================================
-- ROW LEVEL SECURITY POLICIES
-- ========================================

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_preferences ENABLE ROW LEVEL SECURITY;

-- Profiles: Ai cũng đọc được, chỉ owner mới update được
CREATE POLICY "Profiles are viewable by everyone" 
    ON public.profiles FOR SELECT 
    USING (true);

CREATE POLICY "Users can update own profile" 
    ON public.profiles FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile" 
    ON public.profiles FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Participants: User chỉ thấy conversations mình tham gia
CREATE POLICY "Users can view own participants" 
    ON public.participants FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert participants for conversations they're in" 
    ON public.participants FOR INSERT 
    WITH CHECK (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM public.participants 
            WHERE conversation_id = participants.conversation_id 
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can remove themselves from conversations"
    ON public.participants FOR DELETE
    USING (auth.uid() = user_id);

CREATE POLICY "Participants can manage participants in their conversations"
    ON public.participants FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.participants p
            WHERE p.conversation_id = participants.conversation_id
            AND p.user_id = auth.uid()
        )
    );

-- Conversations: User chỉ thấy conversations mình tham gia
CREATE POLICY "Users can view conversations they participate in" 
    ON public.conversations FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM public.participants 
            WHERE conversation_id = conversations.conversation_id 
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create conversations" 
    ON public.conversations FOR INSERT 
    WITH CHECK (true);

CREATE POLICY "Participants can update their conversations"
    ON public.conversations FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = conversations.conversation_id
            AND user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = conversations.conversation_id
            AND user_id = auth.uid()
        )
    );

-- Messages: User chỉ thấy messages trong conversations mình tham gia
CREATE POLICY "Users can view messages in their conversations" 
    ON public.messages FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM public.participants 
            WHERE conversation_id = messages.conversation_id 
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can send messages in their conversations" 
    ON public.messages FOR INSERT 
    WITH CHECK (
        auth.uid() = sender_id 
        AND EXISTS (
            SELECT 1 FROM public.participants 
            WHERE conversation_id = messages.conversation_id 
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own messages" 
    ON public.messages FOR UPDATE 
    USING (auth.uid() = sender_id);

CREATE POLICY "Participants can mark messages as read"
    ON public.messages FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = messages.conversation_id
            AND user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = messages.conversation_id
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own messages" 
    ON public.messages FOR DELETE 
    USING (auth.uid() = sender_id);

-- Conversation preferences: user chỉ thao tác preference của chính mình
CREATE POLICY "Users can view own conversation preferences"
    ON public.conversation_preferences FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own conversation preferences"
    ON public.conversation_preferences FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own conversation preferences"
    ON public.conversation_preferences FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own conversation preferences"
    ON public.conversation_preferences FOR DELETE
    USING (auth.uid() = user_id);

-- ========================================
-- FUNCTIONS
-- ========================================

-- Function: Tự động tạo profile khi user đăng ký
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (user_id, display_name, avatar_url)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'display_name', NULL)
    ON CONFLICT (user_id) DO UPDATE
    SET display_name = EXCLUDED.display_name;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Tạo profile tự động khi insert vào auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ========================================
-- REALTIME
-- Enable realtime cho các bảng
-- ========================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_preferences;

-- ========================================
-- VIEWS (Optional - for better queries)
-- ========================================

-- View: Conversation với thông tin last message
CREATE OR REPLACE VIEW public.conversations_with_last_message AS
SELECT 
    c.*,
    m.content as last_message,
    m.created_at as last_message_at,
    m.sender_id as last_sender_id
FROM public.conversations c
LEFT JOIN LATERAL (
    SELECT * FROM public.messages 
    WHERE conversation_id = c.conversation_id 
    ORDER BY created_at DESC 
    LIMIT 1
) m ON true;

-- ========================================
-- SAMPLE DATA (Optional - for testing)
-- ========================================
-- Uncomment để test
-- INSERT INTO auth.users (id, email) VALUES 
--     ('00000000-0000-0000-0000-000000000001', 'user1@test.com'),
--     ('00000000-0000-0000-0000-000000000002', 'user2@test.com');
