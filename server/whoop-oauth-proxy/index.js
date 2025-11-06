// DoseTrack WHOOP OAuth Proxy
// Purpose: Securely handle WHOOP OAuth2 flow + token management
// Security: Tokens encrypted at rest (AES-256-GCM), never exposed to client

// Load environment variables from .env file
require('dotenv').config();

const express = require('express');
const crypto = require('crypto');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// Environment variables (set via Railway/Cloud Functions/.env)
const WHOOP_CLIENT_ID = process.env.WHOOP_CLIENT_ID;
const WHOOP_CLIENT_SECRET = process.env.WHOOP_CLIENT_SECRET;
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY; // 32-byte hex string
const API_KEY = process.env.API_KEY; // Optional: authenticate iOS client
const PORT = process.env.PORT || 3000;

// WHOOP API endpoints
const WHOOP_TOKEN_URL = 'https://api.prod.whoop.com/oauth/oauth2/token';
const WHOOP_PROFILE_URL = 'https://api.prod.whoop.com/developer/v2/user/profile/basic';
const WHOOP_RECOVERY_URL = 'https://api.prod.whoop.com/developer/v2/recovery';
const WHOOP_SLEEP_URL = 'https://api.prod.whoop.com/developer/v2/sleep';
const WHOOP_REVOKE_URL = 'https://api.prod.whoop.com/developer/v2/user/access';

// In-memory session store (replace with Redis/Firestore/Postgres in production)
const sessions = new Map();

// Validate environment variables
if (!WHOOP_CLIENT_ID || !WHOOP_CLIENT_SECRET || !ENCRYPTION_KEY) {
    console.error('❌ Missing required environment variables');
    console.error('   Required: WHOOP_CLIENT_ID, WHOOP_CLIENT_SECRET, ENCRYPTION_KEY');
    process.exit(1);
}

// Middleware: API key authentication (optional)
function requireAPIKey(req, res, next) {
    if (!API_KEY) return next(); // Skip if not configured
    
    const providedKey = req.headers['x-api-key'];
    if (providedKey !== API_KEY) {
        return res.status(401).json({ error: 'Invalid API key' });
    }
    next();
}

// ============================================================================
// POST /whoop/oauth/exchange
// Exchange OAuth authorization code for session ID
// ============================================================================
app.post('/whoop/oauth/exchange', requireAPIKey, async (req, res) => {
    const { code, redirect_uri } = req.body;
    
    if (!code || !redirect_uri) {
        return res.status(400).json({ error: 'Missing code or redirect_uri' });
    }
    
    try {
        console.log('🔄 Exchanging authorization code for tokens...');
        
        // Step 1: Exchange code for access + refresh tokens
        const tokenResponse = await fetch(WHOOP_TOKEN_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
                grant_type: 'authorization_code',
                code,
                client_id: WHOOP_CLIENT_ID,
                client_secret: WHOOP_CLIENT_SECRET,
                redirect_uri
            })
        });
        
        if (!tokenResponse.ok) {
            const error = await tokenResponse.text();
            console.error('❌ Token exchange failed:', error);
            return res.status(400).json({ error: 'Token exchange failed', details: error });
        }
        
        const tokens = await tokenResponse.json();
        
        if (!tokens.access_token) {
            return res.status(400).json({ error: 'No access token received' });
        }
        
        console.log('✅ Tokens received, fetching user profile...');
        
        // Step 2: Fetch user profile to get user_id
        const profileResponse = await fetch(WHOOP_PROFILE_URL, {
            headers: { 'Authorization': `Bearer ${tokens.access_token}` }
        });
        
        if (!profileResponse.ok) {
            const error = await profileResponse.text();
            console.error('❌ Profile fetch failed:', error);
            return res.status(400).json({ error: 'Failed to fetch user profile' });
        }
        
        const profile = await profileResponse.json();
        
        console.log(`✅ Profile fetched for user_id: ${profile.user_id}`);
        
        // Step 3: Generate session ID
        const sessionId = crypto.randomUUID();
        
        // Step 4: Encrypt tokens (AES-256-GCM)
        const encryptedAccess = encrypt(tokens.access_token);
        const encryptedRefresh = encrypt(tokens.refresh_token);
        
        // Step 5: Store session (in-memory for now)
        const expiresAt = Date.now() + (tokens.expires_in * 1000);
        sessions.set(sessionId, {
            whoop_user_id: profile.user_id,
            access_token: encryptedAccess,
            refresh_token: encryptedRefresh,
            expires_at: expiresAt,
            scopes: tokens.scope ? tokens.scope.split(' ') : ['read:recovery', 'read:sleep'],
            created_at: Date.now()
        });
        
        console.log(`✅ Session created: ${sessionId}`);
        
        // Step 6: Return session metadata to client
        res.json({
            session_id: sessionId,
            whoop_user_id: profile.user_id,
            expires_at: new Date(expiresAt).toISOString(),
            scopes: tokens.scope ? tokens.scope.split(' ') : ['read:recovery', 'read:sleep']
        });
        
    } catch (error) {
        console.error('❌ Exchange error:', error);
        res.status(500).json({ error: 'Internal server error', message: error.message });
    }
});

// ============================================================================
// POST /whoop/data/recovery
// Fetch recovery data for a date range
// ============================================================================
app.post('/whoop/data/recovery', requireAPIKey, async (req, res) => {
    const sessionId = req.headers.authorization?.replace('Bearer ', '');
    const { start, end } = req.body;
    
    if (!sessionId) {
        return res.status(401).json({ error: 'Missing session ID' });
    }
    
    if (!start || !end) {
        return res.status(400).json({ error: 'Missing start or end date' });
    }
    
    const session = sessions.get(sessionId);
    if (!session) {
        return res.status(401).json({ error: 'Invalid session' });
    }
    
    try {
        // Check if token expired → refresh if needed
        if (Date.now() > session.expires_at) {
            console.log('🔄 Access token expired, refreshing...');
            await refreshToken(sessionId, session);
        }
        
        const accessToken = decrypt(session.access_token);
        
        console.log(`📊 Fetching recovery data: ${start} to ${end}`);
        
        const response = await fetch(
            `${WHOOP_RECOVERY_URL}?start=${encodeURIComponent(start)}&end=${encodeURIComponent(end)}`,
            {
                headers: { 'Authorization': `Bearer ${accessToken}` }
            }
        );
        
        if (!response.ok) {
            const error = await response.text();
            console.error('❌ Recovery fetch failed:', error);
            
            if (response.status === 401) {
                // Token invalid even after refresh → user must reconnect
                sessions.delete(sessionId);
                return res.status(401).json({ error: 'Session expired, please reconnect' });
            }
            
            return res.status(response.status).json({ error: 'Failed to fetch recovery data' });
        }
        
        const data = await response.json();
        console.log(`✅ Retrieved ${data.records?.length || 0} recovery records`);
        
        res.json(data);
        
    } catch (error) {
        console.error('❌ Recovery fetch error:', error);
        res.status(500).json({ error: 'Internal server error', message: error.message });
    }
});

// ============================================================================
// POST /whoop/data/sleep
// Fetch sleep data for a date range (for service day mapping)
// ============================================================================
app.post('/whoop/data/sleep', requireAPIKey, async (req, res) => {
    const sessionId = req.headers.authorization?.replace('Bearer ', '');
    const { start, end } = req.body;
    
    if (!sessionId) {
        return res.status(401).json({ error: 'Missing session ID' });
    }
    
    if (!start || !end) {
        return res.status(400).json({ error: 'Missing start or end date' });
    }
    
    const session = sessions.get(sessionId);
    if (!session) {
        return res.status(401).json({ error: 'Invalid session' });
    }
    
    try {
        // Check if token expired → refresh if needed
        if (Date.now() > session.expires_at) {
            console.log('🔄 Access token expired, refreshing...');
            await refreshToken(sessionId, session);
        }
        
        const accessToken = decrypt(session.access_token);
        
        console.log(`😴 Fetching sleep data: ${start} to ${end}`);
        
        const response = await fetch(
            `${WHOOP_SLEEP_URL}?start=${encodeURIComponent(start)}&end=${encodeURIComponent(end)}`,
            {
                headers: { 'Authorization': `Bearer ${accessToken}` }
            }
        );
        
        if (!response.ok) {
            const error = await response.text();
            console.error('❌ Sleep fetch failed:', error);
            
            if (response.status === 401) {
                sessions.delete(sessionId);
                return res.status(401).json({ error: 'Session expired, please reconnect' });
            }
            
            return res.status(response.status).json({ error: 'Failed to fetch sleep data' });
        }
        
        const data = await response.json();
        console.log(`✅ Retrieved ${data.records?.length || 0} sleep records`);
        
        res.json(data);
        
    } catch (error) {
        console.error('❌ Sleep fetch error:', error);
        res.status(500).json({ error: 'Internal server error', message: error.message });
    }
});

// ============================================================================
// DELETE /whoop/oauth/revoke
// Revoke access and delete session
// ============================================================================
app.delete('/whoop/oauth/revoke', requireAPIKey, async (req, res) => {
    const sessionId = req.headers.authorization?.replace('Bearer ', '');
    
    if (!sessionId) {
        return res.status(401).json({ error: 'Missing session ID' });
    }
    
    const session = sessions.get(sessionId);
    if (!session) {
        return res.status(401).json({ error: 'Invalid session' });
    }
    
    try {
        const accessToken = decrypt(session.access_token);
        
        console.log('🔒 Revoking WHOOP access...');
        
        // Revoke access on WHOOP side
        const response = await fetch(WHOOP_REVOKE_URL, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${accessToken}` }
        });
        
        // Delete session regardless of WHOOP response
        sessions.delete(sessionId);
        
        if (!response.ok) {
            console.warn('⚠️ WHOOP revoke returned non-OK status, but session deleted locally');
        } else {
            console.log('✅ Access revoked successfully');
        }
        
        res.json({ status: 'revoked' });
        
    } catch (error) {
        console.error('❌ Revoke error:', error);
        // Still delete session even if revoke fails
        sessions.delete(sessionId);
        res.status(500).json({ error: 'Revocation failed, but session deleted' });
    }
});

// ============================================================================
// GET /health
// Health check endpoint
// ============================================================================
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        service: 'whoop-oauth-proxy',
        version: '1.0.0',
        active_sessions: sessions.size,
        uptime: process.uptime()
    });
});

// ============================================================================
// Helper: Refresh access token using refresh_token
// ============================================================================
async function refreshToken(sessionId, session) {
    const refreshToken = decrypt(session.refresh_token);
    
    const response = await fetch(WHOOP_TOKEN_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
            grant_type: 'refresh_token',
            refresh_token: refreshToken,
            client_id: WHOOP_CLIENT_ID,
            client_secret: WHOOP_CLIENT_SECRET
        })
    });
    
    if (!response.ok) {
        throw new Error('Token refresh failed');
    }
    
    const tokens = await response.json();
    
    // Update session with new tokens
    session.access_token = encrypt(tokens.access_token);
    session.expires_at = Date.now() + (tokens.expires_in * 1000);
    sessions.set(sessionId, session);
    
    console.log('✅ Token refreshed successfully');
}

// ============================================================================
// Helper: AES-256-GCM encryption
// ============================================================================
function encrypt(plaintext) {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-gcm', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();
    
    // Return: IV (16) + Auth Tag (16) + Ciphertext (variable)
    return Buffer.concat([iv, authTag, encrypted]).toString('base64');
}

function decrypt(ciphertext) {
    const buffer = Buffer.from(ciphertext, 'base64');
    const iv = buffer.slice(0, 16);
    const authTag = buffer.slice(16, 32);
    const encrypted = buffer.slice(32);
    
    const decipher = crypto.createDecipheriv('aes-256-gcm', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
    decipher.setAuthTag(authTag);
    
    return decipher.update(encrypted) + decipher.final('utf8');
}

// ============================================================================
// Start server
// ============================================================================
app.listen(PORT, () => {
    console.log(`🚀 WHOOP OAuth Proxy running on port ${PORT}`);
    console.log(`   Health check: http://localhost:${PORT}/health`);
    console.log(`   Active sessions: ${sessions.size}`);
});
