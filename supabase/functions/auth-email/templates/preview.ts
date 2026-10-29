// Writes the sign-in email previews to site/oberta/email/ with a sample code:
//
//   deno run -A supabase/functions/auth-email/templates/preview.ts
//
// auth_email_test.ts fails when the previews and the template drift apart.
import { privacyUrl } from '../handler.ts';
import { codeEmail, type MailLang } from './code.ts';

export const sampleCode = '428913';
export const sampleLink =
  'https://ref.supabase.co/auth/v1/verify?token=pkce_0000&type=magiclink&redirect_to=oberta%3A%2F%2Flogin-callback';
export const previewDir = new URL('../../../../site/oberta/email/', import.meta.url);

/** The previews: one per language, both together, and the computer's (code only). */
export const previews: { name: string; lang: MailLang; link: boolean }[] = [
  { name: 'accesso-it', lang: 'it', link: true },
  { name: 'accesso-en', lang: 'en', link: true },
  { name: 'accesso', lang: 'both', link: true },
  { name: 'accesso-pc', lang: 'it', link: false },
];

export function preview(lang: MailLang, link: boolean) {
  return codeEmail({
    kind: 'signin',
    lang,
    code: sampleCode,
    link: link ? sampleLink : null,
    minutes: 15,
    assetBase: '.', // the previews sit next to the images in site/oberta/email/
    privacyUrl,
  });
}

if (import.meta.main) {
  for (const { name, lang, link } of previews) {
    const mail = preview(lang, link);
    await Deno.writeTextFile(new URL(`${name}.html`, previewDir), mail.html);
    await Deno.writeTextFile(new URL(`${name}.txt`, previewDir), mail.text);
  }
}
