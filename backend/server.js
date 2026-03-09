require('dotenv').config();
const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json({ limit: '20mb' }));  // 20 MB to handle base64-encoded screenshot batches

// ─── Config ───
const MONGO_URI      = process.env.MONGO_URI;
const DB_NAME        = process.env.DB_NAME    || 'persuade_ai';
const COLLECTION     = process.env.COLLECTION || 'userdata';
const JWT_SECRET     = process.env.JWT_SECRET || 'persuade-ai-jwt-secret-change-in-production';
const PORT           = process.env.PORT       || 3000;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;   // Set this in Vercel dashboard — NEVER hardcode
const KB_TOKEN       = process.env.KB_TOKEN || 'saythis2026'; // Shared app token for keyboard extension

// ─── Cached DB Connection (required for Vercel serverless) ───
// Each serverless invocation reuses an existing connection rather than
// opening a new one every request.
let cachedClient = null;
let cachedUsers  = null;

async function getUsers() {
    if (cachedClient && cachedUsers) {
        // Reuse existing connection
        return cachedUsers;
    }
    const client = new MongoClient(MONGO_URI, {
        serverSelectionTimeoutMS: 5000,
        socketTimeoutMS: 45000
    });
    await client.connect();
    const db = client.db(DB_NAME);
    cachedUsers  = db.collection(COLLECTION);
    cachedClient = client;
    // Ensure unique index exists (safe to call multiple times)
    await cachedUsers.createIndex({ email: 1 }, { unique: true }).catch(() => {});
    return cachedUsers;
}

// ─── Auth Middleware ───
function authenticate(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authentication required' });
    }
    try {
        const decoded = jwt.verify(authHeader.substring(7), JWT_SECRET);
        req.userId = decoded.userId;
        req.email  = decoded.email;
        next();
    } catch {
        return res.status(401).json({ error: 'Invalid or expired token' });
    }
}

// ════════════════════════════════════════════════
//  AUTH
// ════════════════════════════════════════════════

// POST /api/auth/register
app.post('/api/auth/register', async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password)       return res.status(400).json({ error: 'Email and password are required' });
        if (password.length < 6)       return res.status(400).json({ error: 'Password must be at least 6 characters' });
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))
                                       return res.status(400).json({ error: 'Invalid email format' });

        const users    = await getUsers();
        const existing = await users.findOne({ email: email.toLowerCase() });
        if (existing) return res.status(409).json({ error: 'An account with this email already exists' });

        const salt         = await bcrypt.genSalt(12);
        const passwordHash = await bcrypt.hash(password, salt);
        const now          = new Date();

        const result = await users.insertOne({
            email: email.toLowerCase(),
            passwordHash,
            createdAt: now,
            updatedAt: now,
            settings: { theme: 'default_dark', customSystemPrompt: '' },
            metrics: {
                repliesGenerated: 0,
                chatsStarted: 0,
                screenshotsAnalyzed: 0,
                keyboardUsages: 0,
                lastActive: now
            }
        });

        const token = jwt.sign(
            { userId: result.insertedId.toString(), email: email.toLowerCase() },
            JWT_SECRET,
            { expiresIn: '30d' }
        );

        res.status(201).json({
            token,
            user: { id: result.insertedId.toString(), email: email.toLowerCase(), createdAt: now.toISOString() }
        });
    } catch (err) {
        console.error('Register error:', err);
        res.status(500).json({ error: 'Server error. Please try again.' });
    }
});

// POST /api/auth/login
app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) return res.status(400).json({ error: 'Email and password are required' });

        const users = await getUsers();
        const user  = await users.findOne({ email: email.toLowerCase() });
        if (!user) return res.status(401).json({ error: 'Invalid email or password' });

        const valid = await bcrypt.compare(password, user.passwordHash);
        if (!valid) return res.status(401).json({ error: 'Invalid email or password' });

        await users.updateOne(
            { _id: user._id },
            { $set: { 'metrics.lastActive': new Date(), updatedAt: new Date() } }
        );

        const token = jwt.sign(
            { userId: user._id.toString(), email: user.email },
            JWT_SECRET,
            { expiresIn: '30d' }
        );

        res.json({
            token,
            user: { id: user._id.toString(), email: user.email, createdAt: user.createdAt.toISOString() }
        });
    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ error: 'Server error. Please try again.' });
    }
});

// ════════════════════════════════════════════════
//  USER
// ════════════════════════════════════════════════

// GET /api/user/profile
app.get('/api/user/profile', authenticate, async (req, res) => {
    try {
        const users = await getUsers();
        const user  = await users.findOne(
            { _id: new ObjectId(req.userId) },
            { projection: { passwordHash: 0 } }
        );
        if (!user) return res.status(404).json({ error: 'User not found' });
        res.json({
            id:       user._id.toString(),
            email:    user.email,
            createdAt: user.createdAt.toISOString(),
            settings: user.settings,
            metrics:  user.metrics
        });
    } catch (err) {
        console.error('Profile error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// GET /api/user/settings
app.get('/api/user/settings', authenticate, async (req, res) => {
    try {
        const users = await getUsers();
        const user  = await users.findOne(
            { _id: new ObjectId(req.userId) },
            { projection: { settings: 1 } }
        );
        if (!user) return res.status(404).json({ error: 'User not found' });
        res.json(user.settings || { theme: 'default_dark', customSystemPrompt: '' });
    } catch (err) {
        console.error('Get settings error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// PUT /api/user/settings
app.put('/api/user/settings', authenticate, async (req, res) => {
    try {
        const { theme, customSystemPrompt } = req.body;
        const update = { updatedAt: new Date() };
        if (theme              !== undefined) update['settings.theme']              = theme;
        if (customSystemPrompt !== undefined) update['settings.customSystemPrompt'] = customSystemPrompt;

        const users = await getUsers();
        await users.updateOne({ _id: new ObjectId(req.userId) }, { $set: update });
        res.json({ success: true });
    } catch (err) {
        console.error('Update settings error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// ════════════════════════════════════════════════
//  METRICS
// ════════════════════════════════════════════════

// POST /api/metrics/track
app.post('/api/metrics/track', authenticate, async (req, res) => {
    try {
        const { event } = req.body;
        const fieldMap = {
            reply_generated:     'metrics.repliesGenerated',
            chat_started:        'metrics.chatsStarted',
            screenshot_analyzed: 'metrics.screenshotsAnalyzed',
            keyboard_used:       'metrics.keyboardUsages'
        };
        if (!event || !fieldMap[event]) {
            return res.status(400).json({ error: 'Invalid event. Valid: ' + Object.keys(fieldMap).join(', ') });
        }
        const users = await getUsers();
        await users.updateOne(
            { _id: new ObjectId(req.userId) },
            {
                $inc: { [fieldMap[event]]: 1 },
                $set: { 'metrics.lastActive': new Date(), updatedAt: new Date() }
            }
        );
        res.json({ success: true });
    } catch (err) {
        console.error('Track error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// GET /api/metrics
app.get('/api/metrics', authenticate, async (req, res) => {
    try {
        const users = await getUsers();
        const user  = await users.findOne(
            { _id: new ObjectId(req.userId) },
            { projection: { metrics: 1 } }
        );
        if (!user) return res.status(404).json({ error: 'User not found' });
        res.json(user.metrics || {});
    } catch (err) {
        console.error('Metrics error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// ════════════════════════════════════════════════
//  AI PROXY  — OpenAI key lives ONLY on the server
//  iOS app sends its JWT (or KB token) → backend
//  calls OpenAI with the secret key and returns
//  the raw response unchanged.
// ════════════════════════════════════════════════

// Helper: forward a request body to an OpenAI endpoint
async function proxyToOpenAI(openaiPath, body, res) {
    if (!OPENAI_API_KEY) {
        return res.status(503).json({ error: 'AI service not configured on server.' });
    }
    try {
        const upstream = await fetch(`https://api.openai.com/${openaiPath}`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${OPENAI_API_KEY}`,
                'Content-Type': 'application/json',
                'OpenAI-Beta': 'responses=v1'   // needed for /v1/responses
            },
            body: JSON.stringify(body)
        });
        const data = await upstream.json();
        res.status(upstream.status).json(data);
    } catch (err) {
        console.error('OpenAI proxy error:', err);
        res.status(502).json({ error: 'Failed to reach OpenAI.', details: err.message });
    }
}

// Middleware: verify the keyboard shared-app token
function authenticateKB(req, res, next) {
    const auth = req.headers.authorization;
    if (!auth || auth !== `Bearer ${KB_TOKEN}`) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
}

// POST /api/ai/chat  — Think / Chat mode (OpenAI Responses API)
// Auth: user JWT (same as all other user endpoints)
app.post('/api/ai/chat', authenticate, async (req, res) => {
    const { model, instructions, input, temperature, top_p, max_output_tokens } = req.body;
    await proxyToOpenAI('v1/responses', { model, instructions, input, temperature, top_p, max_output_tokens }, res);
});

// POST /api/ai/analyze  — Screenshot reply (OpenAI Chat Completions + Vision)
// Auth: user JWT
app.post('/api/ai/analyze', authenticate, async (req, res) => {
    const { model, messages, max_tokens, temperature, top_p } = req.body;
    await proxyToOpenAI('v1/chat/completions', { model, messages, max_tokens, temperature, top_p }, res);
});

// POST /api/ai/keyboard  — Keyboard extension reply generation
// Auth: shared KB_TOKEN (no user JWT — keyboard has no App Group access)
app.post('/api/ai/keyboard', authenticateKB, async (req, res) => {
    const { model, messages, temperature, max_tokens, top_p } = req.body;
    await proxyToOpenAI('v1/chat/completions', { model, messages, temperature, max_tokens, top_p }, res);
});

// ════════════════════════════════════════════════
//  HEALTH
// ════════════════════════════════════════════════

app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ════════════════════════════════════════════════
//  EXPORT / START
//  - Vercel imports this file as a module (module.exports)
//  - Local dev starts the HTTP server via app.listen()
// ════════════════════════════════════════════════

if (!process.env.VERCEL) {
    // Local development — connect eagerly and start server
    getUsers()
        .then(() => {
            app.listen(PORT, '0.0.0.0', () => {
                console.log(`Persuade AI Backend running on http://0.0.0.0:${PORT}`);
            });
        })
        .catch(err => {
            console.error('MongoDB connection error:', err.message);
            process.exit(1);
        });
}

// Vercel needs the Express app exported as a module
module.exports = app;
