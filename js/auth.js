// ============================================================
// HeartSync — Auth Module
// Handles Google OAuth, session management, route guards
// ============================================================
import supabase from './supabase.js';

// ── Get current session & user ──────────────────────────────
export async function getSession() {
    const { data } = await supabase.auth.getSession();
    return data.session;
}

export async function getUser() {
    const { data } = await supabase.auth.getUser();
    return data.user;
}

// ── Get user profile from public.users ──────────────────────
export async function getProfile(userId) {
    const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single();
    if (error) return null;
    return data;
}

export async function upsertProfile(user, overrideName = null) {
    const meta = user.user_metadata || {};

    // 1. Determine the best name to use
    let nameToUse = overrideName || meta.full_name || meta.name;

    // Check database if current sources are fallbacks
    if (!nameToUse || nameToUse === 'مستخدم') {
        const existing = await getProfile(user.id);
        if (existing && existing.name && existing.name !== 'مستخدم') {
            nameToUse = existing.name;
        }
    }

    // Final fallback if still empty
    if (!nameToUse) {
        nameToUse = 'مستخدم';
    }

    console.log(`[Auth] Upserting profile for ${user.id} with name: "${nameToUse}"`);

    // 2. Ensure we have an avatar URL
    let avatarUrl = meta.avatar_url || meta.picture || null;
    if (!avatarUrl) {
        const bgColors = ['7c3aed', 'be185d', '3b82f6', '10b981', 'f59e0b', 'ec4899'];
        const randomBg = bgColors[Math.floor(Math.random() * bgColors.length)];
        avatarUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(nameToUse)}&background=${randomBg}&color=fff&rounded=true`;
    }

    const { error } = await supabase.from('users').upsert({
        id: user.id,
        name: nameToUse,
        email: user.email || null,
        avatar_url: avatarUrl,
        role: 'user'
    }, { onConflict: 'id' });

    if (error) {
        console.error('[Auth] Upsert profile error:', error.message);
        throw error;
    }
}

// ── Google OAuth Login ───────────────────────────────────────
export async function signInWithGoogle() {
    const redirectTo = new URL('dashboard.html', window.location.href).href;
    const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo }
    });
    if (error) throw error;
}


// ── Sign Out ─────────────────────────────────────────────────
export async function signOut() {
    await supabase.auth.signOut();
    location.href = './index.html';
}

// ── Route Guard: require login ───────────────────────────────
export async function requireAuth() {
    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user) {
        console.log('[Auth] No user found, redirecting to index');
        location.href = './index.html';
        return null;
    }

    // Check if we need to sync profile
    const profile = await getProfile(user.id);
    const meta = user.user_metadata || {};

    // If profile is missing OR has a fallback name while metadata has a better one
    const hasBetterMeta = (meta.name && meta.name !== 'مستخدم');
    const hasFallbackProfile = (!profile || profile.name === 'مستخدم');

    if (hasBetterMeta && hasFallbackProfile) {
        console.log('[Auth] Profile stale but metadata has name, syncing...');
        await upsertProfile(user);
        return await getProfile(user.id);
    }

    if (!profile) {
        console.log('[Auth] Profile completely missing, creating...');
        await upsertProfile(user);
        return await getProfile(user.id);
    }

    return profile;
}

// ── Route Guard: require admin role ─────────────────────────
export async function requireAdmin() {
    const profile = await requireAuth();
    if (!profile) return null;
    if (profile.role !== 'admin') {
        location.href = './dashboard.html';
        return null;
    }
    return profile;
}

// ── Redirect logged-in users away from index ────────────────
export async function redirectIfLoggedIn(target = './dashboard.html') {
    const session = await getSession();
    if (session) location.href = target;
}

// ── Render navbar user info ──────────────────────────────────
export function renderNavUser(profile) {
    const nameEls = document.querySelectorAll('.nav-name');
    const avatarEls = document.querySelectorAll('.nav-avatar');
    nameEls.forEach(el => { el.textContent = profile?.name || ''; });
    avatarEls.forEach(el => {
        if (profile?.avatar_url) {
            el.src = profile.avatar_url;
            el.style.display = 'block'; // Ensure it's visible if it has a URL
        }
        else el.style.display = 'none';
    });
}

// ── Toast notifications ──────────────────────────────────────
export function showToast(message, type = 'info', duration = 3500) {
    let toast = document.getElementById('global-toast');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'global-toast';
        toast.className = 'toast';
        document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.className = `toast ${type}`;
    requestAnimationFrame(() => {
        toast.classList.add('show');
        setTimeout(() => toast.classList.remove('show'), duration);
    });
}
