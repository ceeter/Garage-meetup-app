declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (req: Request) => Response | Promise<Response>): void;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type GeocodeSuccess = {
  latitude: number;
  longitude: number;
  formattedAddress: string;
  placeId: string | null;
  provider: 'geoapify';
};

function jsonResponse(body: Record<string, unknown> | GeocodeSuccess, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function validCoordinate(latitude: unknown, longitude: unknown) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!Number.isFinite(lat) || lat < -90 || lat > 90) return null;
  if (!Number.isFinite(lng) || lng < -180 || lng > 180) return null;
  if (lat === 0 && lng === 0) return null;
  return { latitude: lat, longitude: lng };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  let body: { query?: unknown } = {};
  try {
    body = await req.json();
  } catch (_err) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const query = typeof body.query === 'string' ? body.query.trim() : '';
  if (!query) return jsonResponse({ error: 'Missing query' }, 400);

  const apiKey = Deno.env.get('GEOAPIFY_API_KEY');
  if (!apiKey) return jsonResponse({ error: 'Geocoding is not configured' }, 500);

  const url = new URL('https://api.geoapify.com/v1/geocode/search');
  url.searchParams.set('text', query);
  url.searchParams.set('limit', '1');
  url.searchParams.set('format', 'json');
  url.searchParams.set('apiKey', apiKey);

  let geoapifyResponse: Response;
  try {
    geoapifyResponse = await fetch(url);
  } catch (err) {
    console.error('Geoapify request failed', err);
    return jsonResponse({ error: 'Geoapify error' }, 502);
  }

  if (!geoapifyResponse.ok) {
    const detail = await geoapifyResponse.text().catch(() => '');
    console.error('Geoapify returned an error', geoapifyResponse.status, detail.slice(0, 500));
    return jsonResponse({ error: 'Geoapify error' }, 502);
  }

  const data = await geoapifyResponse.json().catch(() => null);
  const result = data && Array.isArray(data.results) ? data.results[0] : null;
  if (!result) return jsonResponse({ error: 'No results' });

  const coords = validCoordinate(result.lat, result.lon);
  if (!coords) return jsonResponse({ error: 'Invalid lat/lng response' });

  return jsonResponse({
    latitude: coords.latitude,
    longitude: coords.longitude,
    formattedAddress: String(result.formatted || result.address_line1 || query),
    placeId: typeof result.place_id === 'string' ? result.place_id : null,
    provider: 'geoapify',
  });
});
