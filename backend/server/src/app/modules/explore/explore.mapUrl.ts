// T-045 (CR-13): Google Maps link for the public event page.
// Built ONLY from the event name and its lat/lng, always URL-encoded as one query value;
// no user supplied URL or markup is ever copied into it. encodeURIComponent leaves
// ! ' ( ) * unescaped; they are encoded too so the value is safe in any HTML attribute.
const strictEncode = (value: string): string =>
  encodeURIComponent(value).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);

export const buildEventMapUrl = ({ name, lat, lng }: { name: string; lat: number; lng: number }): string =>
  `https://www.google.com/maps/search/?api=1&query=${strictEncode(`${name} ${lat},${lng}`)}`;
