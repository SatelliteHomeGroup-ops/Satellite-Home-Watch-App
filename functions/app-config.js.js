export function onRequestGet({ env }) {
  const config = {
    supabaseUrl: env.SHW_SUPABASE_URL || '',
    supabaseAnonKey: env.SHW_SUPABASE_ANON_KEY || '',
  };

  const payload = `window.__APP_CONFIG__ = Object.assign({}, window.__APP_CONFIG__, ${JSON.stringify(config)});
window.dispatchEvent(new CustomEvent('app-config-ready'));`;

  return new Response(payload, {
    headers: {
      'content-type': 'application/javascript; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}
