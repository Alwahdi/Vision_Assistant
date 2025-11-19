-- Vision Assistant Database Initialization
-- This script creates all necessary tables, indexes, and initial data

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create database schema
CREATE SCHEMA IF NOT EXISTS vision_assistant;
SET search_path TO vision_assistant, public;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE,
    full_name VARCHAR(100),
    password_hash VARCHAR(255),
    phone VARCHAR(20),
    avatar_url VARCHAR(500),
    bio TEXT,
    preferences JSONB DEFAULT '{}',
    accessibility_settings JSONB DEFAULT '{}',
    language VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(50) DEFAULT 'UTC',
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    email_verified_at TIMESTAMP WITH TIME ZONE,
    phone_verified_at TIMESTAMP WITH TIME ZONE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- User sessions
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(500) UNIQUE NOT NULL,
    refresh_token VARCHAR(500) UNIQUE,
    device_info JSONB,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User roles and permissions
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_roles (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID REFERENCES users(id),
    PRIMARY KEY (user_id, role_id)
);

-- AI processing requests
CREATE TABLE IF NOT EXISTS ai_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    request_type VARCHAR(50) NOT NULL, -- 'vision', 'audio', 'text'
    input_data JSONB,
    processing_status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    result_data JSONB,
    processing_time_ms INTEGER,
    error_message TEXT,
    model_version VARCHAR(50),
    confidence_score DECIMAL(3,2),
    tokens_used INTEGER,
    cost_cents INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Detected objects and scenes
CREATE TABLE IF NOT EXISTS detected_objects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID REFERENCES ai_requests(id) ON DELETE CASCADE,
    object_name VARCHAR(100) NOT NULL,
    confidence DECIMAL(3,2) NOT NULL,
    bounding_box JSONB,
    category VARCHAR(50),
    attributes JSONB DEFAULT '{}',
    position_x DECIMAL(5,2),
    position_y DECIMAL(5,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Recognized text
CREATE TABLE IF NOT EXISTS recognized_text (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID REFERENCES ai_requests(id) ON DELETE CASCADE,
    text_content TEXT NOT NULL,
    language VARCHAR(10) DEFAULT 'en',
    confidence DECIMAL(3,2),
    bounding_box JSONB,
    text_orientation VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audio transcriptions
CREATE TABLE IF NOT EXISTS audio_transcriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID REFERENCES ai_requests(id) ON DELETE CASCADE,
    transcription TEXT,
    translation TEXT,
    language VARCHAR(10) DEFAULT 'en',
    target_language VARCHAR(10),
    duration_seconds DECIMAL(8,2),
    word_count INTEGER,
    confidence DECIMAL(3,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Navigation paths
CREATE TABLE IF NOT EXISTS navigation_paths (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(200),
    description TEXT,
    start_location GEOGRAPHY(POINT, 4326),
    end_location GEOGRAPHY(POINT, 4326),
    waypoints JSONB DEFAULT '[]',
    distance_meters INTEGER,
    estimated_duration_minutes INTEGER,
    path_data JSONB,
    accessibility_features JSONB DEFAULT '{}',
    is_favorite BOOLEAN DEFAULT false,
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User interactions and feedback
CREATE TABLE IF NOT EXISTS user_interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    interaction_type VARCHAR(50) NOT NULL, -- 'voice_command', 'gesture', 'button_press'
    interaction_data JSONB,
    context VARCHAR(100), -- 'home', 'navigation', 'object_detection'
    success BOOLEAN DEFAULT true,
    response_time_ms INTEGER,
    user_feedback_rating INTEGER CHECK (user_feedback_rating >= 1 AND user_feedback_rating <= 5),
    user_feedback_comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- System events and analytics
CREATE TABLE IF NOT EXISTS system_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB,
    severity VARCHAR(20) DEFAULT 'info', -- 'debug', 'info', 'warning', 'error', 'critical'
    source_service VARCHAR(50),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    session_id UUID,
    request_id UUID,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- API usage and rate limiting
CREATE TABLE IF NOT EXISTS api_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    api_endpoint VARCHAR(200) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INTEGER,
    response_time_ms INTEGER,
    request_size_bytes INTEGER,
    response_size_bytes INTEGER,
    user_agent TEXT,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- File storage metadata
CREATE TABLE IF NOT EXISTS file_metadata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255),
    file_path VARCHAR(500) NOT NULL,
    file_url VARCHAR(500),
    file_size_bytes INTEGER,
    mime_type VARCHAR(100),
    file_hash VARCHAR(128),
    storage_provider VARCHAR(50) DEFAULT 'local',
    metadata JSONB DEFAULT '{}',
    is_public BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accessed_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Notification preferences and history
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    notification_type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    priority VARCHAR(20) DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires ON user_sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_ai_requests_user_id ON ai_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_requests_status ON ai_requests(processing_status);
CREATE INDEX IF NOT EXISTS idx_ai_requests_created_at ON ai_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_ai_requests_type ON ai_requests(request_type);

CREATE INDEX IF NOT EXISTS idx_detected_objects_request_id ON detected_objects(request_id);
CREATE INDEX IF NOT EXISTS idx_detected_objects_confidence ON detected_objects(confidence);

CREATE INDEX IF NOT EXISTS idx_recognized_text_request_id ON recognized_text(request_id);
CREATE INDEX IF NOT EXISTS idx_recognized_text_language ON recognized_text(language);

CREATE INDEX IF NOT EXISTS idx_navigation_paths_user_id ON navigation_paths(user_id);
CREATE INDEX IF NOT EXISTS idx_navigation_paths_favorite ON navigation_paths(is_favorite) WHERE is_favorite = true;

CREATE INDEX IF NOT EXISTS idx_user_interactions_user_id ON user_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_type ON user_interactions(interaction_type);

CREATE INDEX IF NOT EXISTS idx_system_events_type ON system_events(event_type);
CREATE INDEX IF NOT EXISTS idx_system_events_created_at ON system_events(created_at);
CREATE INDEX IF NOT EXISTS idx_system_events_user_id ON system_events(user_id);

CREATE INDEX IF NOT EXISTS idx_api_usage_user_id ON api_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_api_usage_endpoint ON api_usage(api_endpoint);
CREATE INDEX IF NOT EXISTS idx_api_usage_created_at ON api_usage(created_at);

CREATE INDEX IF NOT EXISTS idx_file_metadata_user_id ON file_metadata(user_id);
CREATE INDEX IF NOT EXISTS idx_file_metadata_mime_type ON file_metadata(mime_type);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(is_read) WHERE is_read = false;

-- Create default roles
INSERT INTO roles (name, description, permissions) VALUES
('user', 'Regular user with basic access', '["read:own_data", "write:own_data", "ai:process"]'),
('premium', 'Premium user with advanced features', '["read:own_data", "write:own_data", "ai:process", "ai:advanced", "navigation:unlimited"]'),
('admin', 'Administrator with full access', '["*"]')
ON CONFLICT (name) DO NOTHING;

-- Create updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_navigation_paths_updated_at BEFORE UPDATE ON navigation_paths FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create user activity summary view
CREATE OR REPLACE VIEW user_activity_summary AS
SELECT
    u.id,
    u.email,
    u.full_name,
    u.created_at as user_since,
    COUNT(DISTINCT ar.id) as total_ai_requests,
    COUNT(DISTINCT CASE WHEN ar.processing_status = 'completed' THEN ar.id END) as successful_requests,
    AVG(ar.processing_time_ms) as avg_processing_time,
    MAX(ar.created_at) as last_activity,
    COUNT(DISTINCT ui.id) as total_interactions,
    AVG(CASE WHEN ui.user_feedback_rating IS NOT NULL THEN ui.user_feedback_rating END) as avg_rating
FROM users u
LEFT JOIN ai_requests ar ON u.id = ar.user_id
LEFT JOIN user_interactions ui ON u.id = ui.user_id
WHERE u.deleted_at IS NULL
GROUP BY u.id, u.email, u.full_name, u.created_at;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA vision_assistant TO vision_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA vision_assistant TO vision_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA vision_assistant TO vision_user;

-- Create test user (for development only)
-- This should be removed in production
INSERT INTO users (email, username, full_name, password_hash, is_active, is_verified, language)
VALUES (
    'test@vision-assistant.com',
    'testuser',
    'Test User',
    '$2b$10$8K3lLwxzBJVzqZwH8JzOeO8tJ8qQYqQvKjZqYzqQyQvKjZqYzqQy', -- password: test123
    true,
    true,
    'en'
) ON CONFLICT (email) DO NOTHING;
