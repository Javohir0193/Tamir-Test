// Supabase'нинг сохта «эшиги» (фақат e2e): сайт https://<test>.supabase.co га юборган сўровларни браузер ичида
// ушлаб, маҳаллий Postgres'даги ҳақиқий функциялар (create_order, pay_test ...) ва view'ларга узатади.
// Ҳар сўров Supabase'даги каби: роль anon/authenticated, request.jwt.claim.sub = харидор uid, ҳуқуқлар ва RLS ишлайди.
// Тармоқда test ёки prod Supabase'га ҳеч нарса кетмайди: бошқа ташқи манзиллар блокланади, prod'га уриниш — тест хатоси.
import pg from "pg";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

export const TEST_HOST = "mlhhmohaxpetptmrtqrz.supabase.co";
export const PROD_HOST = "agajmytkjpkihvaurqij.supabase.co";
export const E2E_UID = "00000000-0000-4000-8000-00000000e2e0";   // seed.sql билан бир хил
export const E2E_SELLER_ID = 9001, E2E_SELLER_SES = "e2e-seller-session";   // seed.sql даги дўкон 1 ва унинг браузер сессияси (сохта)
const CDN_SUPABASE = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js";
const require = createRequire(import.meta.url);
const SUPABASE_UMD = readFileSync(require.resolve("@supabase/supabase-js/dist/umd/supabase.js"));

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
const fakeJwt = (sub, role) => `${b64({ alg: "none", typ: "JWT" })}.${b64({ sub, role, aud: role, exp: Math.floor(Date.now() / 1000) + 86400 })}.e2e`;
const IDENT = /^[a-z_][a-z0-9_]*$/;
const ident = (s) => { if (!IDENT.test(s)) throw new Error("bad identifier: " + s); return `"${s}"`; };

export function createGateway(pool = new pg.Pool()) {
  const blocked = [];   // test'дан ташқари манзилга уринишлар (prod бўлса тест йиқилади)

  function who(headers) {
    const a = headers["authorization"] || "";
    const m = a.match(/^Bearer [^.]+\.([^.]+)\./);
    if (!m) return { role: "anon", uid: "" };
    try { const p = JSON.parse(Buffer.from(m[1], "base64url").toString()); return p.sub ? { role: "authenticated", uid: p.sub } : { role: "anon", uid: "" }; }
    catch { return { role: "anon", uid: "" }; }
  }

  async function asRole({ role, uid }, sql, params = []) {
    const c = await pool.connect();
    try {
      await c.query("begin");
      await c.query(`set local role ${role === "authenticated" ? "authenticated" : "anon"}`);
      await c.query("select set_config('request.jwt.claim.sub', $1, true)", [uid]);
      const r = await c.query(sql, params);
      await c.query("commit");
      return r;
    } catch (e) { await c.query("rollback").catch(() => {}); throw e; }
    finally { c.release(); }
  }

  async function rpc(user, fn, args) {
    const meta = await pool.query(
      `select p.proretset, p.prorettype = 'void'::regtype as is_void from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = $1 limit 1`, [fn]);
    if (!meta.rowCount) return { status: 404, body: { code: "PGRST202", message: `Could not find the function public.${fn}` } };
    const keys = Object.keys(args || {});
    const call = `public.${ident(fn)}(${keys.map((k, i) => `${ident(k)} => $${i + 1}`).join(", ")})`;
    const vals = keys.map((k) => { const v = args[k]; return v === null || v === undefined ? null : typeof v === "object" ? JSON.stringify(v) : String(v); });
    const { proretset, is_void } = meta.rows[0];
    const sql = is_void ? `select ${call}, null::jsonb as v`
      : proretset ? `select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) as v from ${call} r`
      : `select to_jsonb(r) as v from ${call} r`;
    const r = await asRole(user, sql, vals);
    return { status: 200, body: r.rows[0]?.v ?? null };
  }

  async function select(user, rel, q) {
    const cols = (q.get("select") || "*").split(",").map((s) => s.trim()).filter(Boolean).map((c) => (c === "*" ? "*" : ident(c))).join(", ");
    const where = [], vals = [];
    for (const [k, v] of q) {
      if (["select", "order", "limit", "offset"].includes(k)) continue;
      const m = v.match(/^eq\.(.*)$/); if (!m) throw new Error("unsupported filter: " + k + "=" + v);
      vals.push(m[1]); where.push(`${ident(k)}::text = $${vals.length}`);
    }
    const order = (q.get("order") || "").split(",").filter(Boolean).map((o) => { const [c, d] = o.split("."); return `${ident(c)} ${d === "desc" ? "desc" : "asc"}`; });
    const sql = `select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) as v from (select ${cols} from public.${ident(rel)}`
      + (where.length ? ` where ${where.join(" and ")}` : "") + (order.length ? ` order by ${order.join(", ")}` : "") + `) x`;
    const r = await asRole(user, sql, vals);
    return { status: 200, body: r.rows[0].v };
  }

  // Дўкон кабинети (seller.html) боти — tg-bot Edge Function (у private репода) ўрнини босувчи ОДДИЙ нусха, фақат e2e учун.
  // Сессия: x-sel-session = E2E_SELLER_SES → seed.sql даги дўкон 9001. Нарх ёзиш ва текшириш — ботдаги каби
  // ҳақиқий SQL функциялар (seller_offers_save / seller_offers_check, 29-миграция) service_role билан.
  async function asService(sql, params = []) {
    const c = await pool.connect();
    try { await c.query("begin"); await c.query("set local role service_role"); const r = await c.query(sql, params); await c.query("commit"); return r; }
    catch (e) { await c.query("rollback").catch(() => {}); throw e; }
    finally { c.release(); }
  }
  async function sellerBot(headers, body) {
    if (headers["x-sel-session"] !== E2E_SELLER_SES) return { status: 401, body: { error: "auth" } };
    const sid = E2E_SELLER_ID, a = body.action;
    if (a === "save") {
      const r = await asService("select public.seller_offers_save($1, $2::jsonb, 'seller') as v", [sid, JSON.stringify(body.offers || [])]);
      return { status: 200, body: { ok: true, saved: (body.offers || []).length, ...r.rows[0].v } };
    }
    if (a === "imp_check") {
      const r = await asService("select public.seller_offers_check($1, $2::jsonb) as v", [sid, JSON.stringify(body.rows || [])]);
      return { status: 200, body: { rows: r.rows[0].v } };
    }
    if (a === "s_orders") return { status: 200, body: { orders: [], sc: false } };
    if (a === "load") {
      const r = await pool.query(`select jsonb_build_object(
          'seller', (select jsonb_build_object('name', name, 'shop', shop, 'categories', categories, 'market', null, 'row', row_no) from public.sellers where id = $1),
          'cats', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name_uz) order by sort, id), '[]') from public.categories),
          'products', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'cat', p.cat, 'name', p.name, 'spec', p.spec, 'unit', p.unit, 'emoji', p.emoji,
                 'best', (select min(o.price) from public.offers o where o.product_id = p.id and o.in_stock and o.seller_id <> $1)) order by p.id), '[]')
               from public.products p where p.active),
          'offers', (select coalesce(jsonb_object_agg(product_id, jsonb_build_object('price', price, 'in_stock', in_stock)), '{}') from public.offers where seller_id = $1)) as v`, [sid]);
      return { status: 200, body: r.rows[0].v };
    }
    return { status: 400, body: { error: "e2e: action йўқ: " + a } };
  }

  async function handle(route) {
    const req = route.request(), url = new URL(req.url());
    const json = (status, body) => route.fulfill({ status, contentType: "application/json", headers: { "access-control-allow-origin": "*" }, body: JSON.stringify(body) });
    if (req.method() === "OPTIONS") return route.fulfill({ status: 204, headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "*", "access-control-allow-methods": "*" } });
    const path = url.pathname;
    try {
      // Auth: signInAnonymously → харидорнинг доимий uid'и (seed.sql да у Telegram профилига боғланган)
      if (path === "/auth/v1/signup" || path === "/auth/v1/token") {
        const user = { id: E2E_UID, aud: "authenticated", role: "authenticated", is_anonymous: true, app_metadata: {}, user_metadata: {}, created_at: new Date().toISOString() };
        return json(200, { access_token: fakeJwt(E2E_UID, "authenticated"), token_type: "bearer", expires_in: 86400,
          expires_at: Math.floor(Date.now() / 1000) + 86400, refresh_token: "e2e-refresh", user });
      }
      if (path === "/auth/v1/user") return json(200, { id: E2E_UID, aud: "authenticated", role: "authenticated", is_anonymous: true });
      if (path === "/auth/v1/logout") return route.fulfill({ status: 204 });
      if (path === "/functions/v1/tg-bot" && req.method() === "POST") {
        const r = await sellerBot(req.headers(), req.postData() ? JSON.parse(req.postData()) : {}); return json(r.status, r.body);
      }
      const user = who(req.headers());
      let m = path.match(/^\/rest\/v1\/rpc\/([a-z0-9_]+)$/);
      if (m) { const r = await rpc(user, m[1], req.postData() ? JSON.parse(req.postData()) : {}); return json(r.status, r.body); }
      m = path.match(/^\/rest\/v1\/([a-z0-9_]+)$/);
      if (m && req.method() === "GET") { const r = await select(user, m[1], url.searchParams); return json(r.status, r.body); }
      return json(404, { message: "e2e gateway: not implemented " + req.method() + " " + path });
    } catch (e) {
      // PostgREST каби: { code, message } (сайт message ичидаги калит сўзни қидиради)
      return json(e.code === "42501" ? 403 : 400, { code: e.code || "e2e", message: e.message, details: e.detail || null, hint: e.hint || null });
    }
  }

  async function install(context) {
    await context.route(CDN_SUPABASE, (r) => r.fulfill({ contentType: "text/javascript", body: SUPABASE_UMD }));
    await context.route(`https://${TEST_HOST}/**`, handle);
    await context.routeWebSocket(/\/realtime\/v1\//, () => {});   // realtime: уланади, лекин жим (сайт 15 сонияда ўзи янгилайди)
    await context.route((u) => !["127.0.0.1", "localhost"].includes(u.hostname) && u.hostname !== TEST_HOST && u.href !== CDN_SUPABASE,
      (r) => { blocked.push(r.request().url()); return r.abort(); });
  }

  return { install, blocked, pool, query: (s, p) => pool.query(s, p) };
}
