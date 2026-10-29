// Writes the email previews to site/oberta/email/ with sample links:
//
//   deno run -A supabase/functions/waitlist/templates/preview.ts
//
// waitlist_test.ts fails when the previews and the templates drift apart.
import { type Lang, welcomeEmail } from './welcome.ts';

export const sampleSite = 'https://charliemobile.dev/oberta';
export const sampleToken = '00000000-0000-4000-8000-000000000000';
export const previewDir = new URL('../../../../site/oberta/email/', import.meta.url);

export function preview(lang: Lang) {
  return welcomeEmail(lang, {
    ctaUrl: `${sampleSite}/ruoli.html`,
    unsubscribeUrl: `${sampleSite}/disiscriviti.html?t=${sampleToken}`,
    privacyUrl: `${sampleSite}/privacy.html#lista`,
  });
}

if (import.meta.main) {
  for (const lang of ['it', 'en'] as const) {
    const mail = preview(lang);
    await Deno.writeTextFile(new URL(`benvenuto-${lang}.html`, previewDir), mail.html);
    await Deno.writeTextFile(new URL(`benvenuto-${lang}.txt`, previewDir), mail.text);
  }
}
