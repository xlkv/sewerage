import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const PHONE_REGEX = /^998\d{9}$/;
const PIN_REGEX = /^\d{5}$/;

export function normalizePhone(input: string): string | null {
  const digits = input.replace(/\D/g, '');
  return PHONE_REGEX.test(digits) ? digits : null;
}

export function pseudoEmail(phone: string): string {
  return `${phone}@users.turon.app`;
}

export function derivePassword(pin: string): string {
  return `${pin}#Turon`;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function isValidRole(role: unknown): role is 'admin' | 'user' {
  return role === 'admin' || role === 'user';
}

function isValidFullName(name: unknown): name is string {
  return typeof name === 'string' && name.trim().length >= 2 && name.trim().length <= 100;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'invalid_input' }, 400);
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: 'internal' }, 500);
    }

    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) {
      return jsonResponse({ error: 'forbidden' }, 403);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: userData, error: userError } = await adminClient.auth.getUser(token);
    if (userError || !userData?.user) {
      return jsonResponse({ error: 'forbidden' }, 403);
    }

    const callerId = userData.user.id;
    const { data: callerProfile, error: profileError } = await adminClient
      .from('profiles')
      .select('role, is_active')
      .eq('id', callerId)
      .maybeSingle();

    if (profileError || !callerProfile || callerProfile.role !== 'admin' || !callerProfile.is_active) {
      return jsonResponse({ error: 'forbidden' }, 403);
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== 'object') {
      return jsonResponse({ error: 'invalid_input' }, 400);
    }

    const { action } = body as Record<string, unknown>;

    if (action === 'create') {
      const { phone, full_name, pin, role } = body as Record<string, unknown>;
      if (
        typeof phone !== 'string' ||
        !PHONE_REGEX.test(phone) ||
        !isValidFullName(full_name) ||
        typeof pin !== 'string' ||
        !PIN_REGEX.test(pin) ||
        !isValidRole(role)
      ) {
        return jsonResponse({ error: 'invalid_input' }, 400);
      }

      const { data: existingProfile } = await adminClient
        .from('profiles')
        .select('id')
        .eq('phone', phone)
        .maybeSingle();

      if (existingProfile) {
        return jsonResponse({ error: 'phone_exists' }, 409);
      }

      const { data: createdAuth, error: createAuthErr } = await adminClient.auth.admin.createUser({
        email: pseudoEmail(phone),
        password: derivePassword(pin),
        email_confirm: true,
      });

      if (createAuthErr || !createdAuth?.user) {
        const msg = createAuthErr?.message?.toLowerCase() ?? '';
        if (msg.includes('already') || msg.includes('exists') || msg.includes('registered')) {
          return jsonResponse({ error: 'phone_exists' }, 409);
        }
        return jsonResponse({ error: 'internal' }, 500);
      }

      const newUserId = createdAuth.user.id;
      const { error: insertErr } = await adminClient.from('profiles').insert({
        id: newUserId,
        full_name: full_name.trim(),
        phone,
        role,
        is_active: true,
      });

      if (insertErr) {
        await adminClient.auth.admin.deleteUser(newUserId);
        if (insertErr.code === '23505') {
          return jsonResponse({ error: 'phone_exists' }, 409);
        }
        return jsonResponse({ error: 'internal' }, 500);
      }

      return jsonResponse({ user_id: newUserId }, 200);
    }

    if (action === 'reset_pin') {
      const { user_id, pin } = body as Record<string, unknown>;
      if (
        typeof user_id !== 'string' ||
        user_id.trim() === '' ||
        typeof pin !== 'string' ||
        !PIN_REGEX.test(pin)
      ) {
        return jsonResponse({ error: 'invalid_input' }, 400);
      }

      const { error: updateErr } = await adminClient.auth.admin.updateUserById(user_id, {
        password: derivePassword(pin),
      });

      if (updateErr) {
        return jsonResponse({ error: 'internal' }, 500);
      }

      return jsonResponse({ ok: true }, 200);
    }

    if (action === 'set_active') {
      const { user_id, is_active } = body as Record<string, unknown>;
      if (
        typeof user_id !== 'string' ||
        user_id.trim() === '' ||
        typeof is_active !== 'boolean'
      ) {
        return jsonResponse({ error: 'invalid_input' }, 400);
      }

      if (user_id === callerId && !is_active) {
        return jsonResponse({ error: 'self_change' }, 409);
      }

      const { error: profileUpdErr } = await adminClient
        .from('profiles')
        .update({ is_active })
        .eq('id', user_id);

      if (profileUpdErr) {
        return jsonResponse({ error: 'internal' }, 500);
      }

      const { error: banErr } = await adminClient.auth.admin.updateUserById(user_id, {
        ban_duration: is_active ? 'none' : '876000h',
      });

      if (banErr) {
        return jsonResponse({ error: 'internal' }, 500);
      }

      return jsonResponse({ ok: true }, 200);
    }

    if (action === 'update') {
      const { user_id, full_name, role } = body as Record<string, unknown>;
      if (typeof user_id !== 'string' || user_id.trim() === '') {
        return jsonResponse({ error: 'invalid_input' }, 400);
      }
      if (full_name === undefined && role === undefined) {
        return jsonResponse({ error: 'invalid_input' }, 400);
      }
      if (full_name !== undefined && !isValidFullName(full_name)) {
        return jsonResponse({ error: 'invalid_input' }, 400);
      }
      if (role !== undefined && !isValidRole(role)) {
        return jsonResponse({ error: 'invalid_input' }, 400);
      }

      if (user_id === callerId && role !== undefined && role !== 'admin') {
        return jsonResponse({ error: 'self_change' }, 409);
      }

      const updates: Record<string, unknown> = {};
      if (full_name !== undefined) updates.full_name = full_name.trim();
      if (role !== undefined) updates.role = role;

      const { error: updErr } = await adminClient
        .from('profiles')
        .update(updates)
        .eq('id', user_id);

      if (updErr) {
        return jsonResponse({ error: 'internal' }, 500);
      }

      return jsonResponse({ ok: true }, 200);
    }

    return jsonResponse({ error: 'invalid_input' }, 400);
  } catch (_err) {
    return jsonResponse({ error: 'internal' }, 500);
  }
});
