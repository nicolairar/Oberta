// The sign-in email ("Entra con email", no passwords): the same 1940s
// telegram as the waitlist welcome (templates/welcome.ts there), a dark brick
// wall, a card with a brass double rule and art-deco corners, the neon sign,
// and in the middle the six digits on a telegram slip, big and selectable in
// one tap. Under it, only where the app can catch it (oberta://, the phones),
// a Targa button with the magic link. Four role medallions and the doorman's
// signature close it. Tables and inline styles only, 560 px wide and fluid
// below, a VML button for Outlook, bgcolor fallbacks under every image.
//
// The images are the waitlist's (waitlist/templates/images.ts), served by
// this function at /functions/v1/auth-email/img/<name>: never from the site.
// Previews with a sample code: site/oberta/email/accesso*.html (preview.ts).

export type Lang = 'it' | 'en';

/** One language when the account has one (user_metadata.lang), else both. */
export type MailLang = Lang | 'both';

/** What the mail is for: a sign-in, the first sign-in, a new address, a check. */
export type Kind = 'signin' | 'signup' | 'email_change' | 'reauthentication';

export interface CodeMailInput {
  kind: Kind;
  lang: MailLang;
  /** The six digits. */
  code: string;
  /** The magic link, or null where the app cannot open it (the computer). */
  link: string | null;
  /** How long code and link work (mailer_otp_exp). */
  minutes: number;
  /** Where the images live, absolute. */
  assetBase: string;
  privacyUrl: { it: string; en: string };
}

export interface Email {
  subject: string;
  html: string;
  text: string;
}

interface Copy {
  subject: (code: string) => string;
  preheader: (minutes: number) => string;
  wire: string;
  kicker: string;
  title: string;
  lead: string;
  /** Added to the lead when there is a button. */
  leadLink: string;
  codeLabel: string;
  button: string;
  valid: (minutes: number, link: boolean) => string;
  ignore: string;
  sign: string;
  motto: string;
  why: string;
  privacy: string;
  alt: string;
  roles: readonly string[];
}

const base = {
  it: {
    subject: (code: string) => `Il tuo codice per Obertà: ${code}`,
    preheader: (minutes: number) => `Scrivilo nell'app entro ${minutes} minuti. Se non sei stato tu, ignora questa mail.`,
    wire: 'Telegramma · Riservato · Alla porta',
    kicker: 'Qualcuno bussa alla porta.',
    title: 'Di’ la parola d’ordine.',
    lead: 'Per entrare in Obertà con questo indirizzo, scrivi nell’app il codice qui sotto.',
    leadLink: ' Dal telefono puoi anche toccare il pulsante: l’app si apre già dentro.',
    codeLabel: 'Il tuo codice',
    button: 'Apri Obertà',
    valid: (minutes: number, link: boolean) =>
      link ? `Codice e pulsante valgono ${minutes} minuti, una volta sola.` : `Il codice vale ${minutes} minuti, una volta sola.`,
    ignore: 'Non sei stato tu? Allora qualcuno ha sbagliato indirizzo: ignora questa mail. Senza il codice non entra nessuno.',
    sign: '— Il Portiere',
    motto: 'Chi sa, tace.',
    why: 'Ricevi questa mail perché è stato chiesto un accesso a Obertà con questo indirizzo.',
    privacy: 'Informativa privacy',
    alt: 'OBERTÀ, insegna al neon',
    roles: ['Il Padrino', 'Il Commissario', 'Il Dottore', 'Il Picciotto'],
  },
  en: {
    subject: (code: string) => `Your Obertà code: ${code}`,
    preheader: (minutes: number) => `Type it in the app within ${minutes} minutes. Not you? Ignore this email.`,
    wire: 'Telegram · Confidential · At the door',
    kicker: 'Somebody is knocking at the door.',
    title: 'Say the word.',
    lead: 'To sign in to Obertà with this address, type the code below in the app.',
    leadLink: ' On your phone you can also tap the button: the app opens signed in.',
    codeLabel: 'Your code',
    button: 'Open Obertà',
    valid: (minutes: number, link: boolean) =>
      link ? `The code and the button work for ${minutes} minutes, once.` : `The code works for ${minutes} minutes, once.`,
    ignore: 'Not you? Then someone typed the wrong address: ignore this email. Without the code nobody gets in.',
    sign: '— The Doorman',
    motto: 'Who knows, keeps quiet.',
    why: 'You get this email because a sign-in to Obertà was requested with this address.',
    privacy: 'Privacy policy',
    alt: 'OBERTÀ, neon sign',
    roles: ['The Godfather', 'The Inspector', 'The Doctor', 'The Henchman'],
  },
} satisfies Record<Lang, Copy>;

/** What changes from a plain sign-in, per kind. */
const kinds: Record<Kind, Record<Lang, Partial<Copy>>> = {
  signin: { it: {}, en: {} },
  signup: {
    it: {
      kicker: 'Benvenuto in famiglia.',
      lead: 'È la prima volta che entri con questo indirizzo: scrivi nell’app il codice qui sotto e il tuo posto al tavolo è pronto.',
    },
    en: {
      kicker: 'Welcome to the Family.',
      lead: 'It is your first time with this address: type the code below in the app and your seat at the table is ready.',
    },
  },
  email_change: {
    it: {
      subject: (code: string) => `Conferma il nuovo indirizzo: ${code}`,
      kicker: 'Un cambio di indirizzo.',
      title: 'Conferma che sei tu.',
      lead: 'Per usare questo indirizzo con il tuo account di Obertà, scrivi nell’app il codice qui sotto.',
      leadLink: ' Dal telefono puoi anche toccare il pulsante.',
      button: 'Conferma',
      ignore: 'Non sei stato tu? Ignora questa mail: l’indirizzo non cambia.',
      why: 'Ricevi questa mail perché è stato chiesto di usare questo indirizzo per un account di Obertà.',
    },
    en: {
      subject: (code: string) => `Confirm your new address: ${code}`,
      kicker: 'A change of address.',
      title: 'Confirm it is you.',
      lead: 'To use this address with your Obertà account, type the code below in the app.',
      leadLink: ' On your phone you can also tap the button.',
      button: 'Confirm',
      ignore: 'Not you? Ignore this email: the address does not change.',
      why: 'You get this email because someone asked to use this address for an Obertà account.',
    },
  },
  reauthentication: {
    it: {
      subject: (code: string) => `Il tuo codice di conferma: ${code}`,
      kicker: 'Una conferma, prima di procedere.',
      title: 'Conferma che sei tu.',
      lead: 'Scrivi nell’app il codice qui sotto per confermare l’operazione.',
      ignore: 'Non sei stato tu? Ignora questa mail, e se succede ancora scrivici.',
    },
    en: {
      subject: (code: string) => `Your confirmation code: ${code}`,
      kicker: 'One check before going on.',
      title: 'Confirm it is you.',
      lead: 'Type the code below in the app to confirm.',
      ignore: 'Not you? Ignore this email, and write to us if it happens again.',
    },
  },
};

const copyFor = (kind: Kind, lang: Lang): Copy => ({ ...base[lang], ...kinds[kind][lang] });

const esc = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const serif = "Georgia, 'Times New Roman', Times, serif";
const sans = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif";
const mono = "'Courier New', Courier, monospace";
const roleFiles = ['padrino', 'detective', 'medico', 'mafioso'];

export function codeEmail(input: CodeMailInput): Email {
  const langs: Lang[] = input.lang === 'both' ? ['it', 'en'] : [input.lang];
  const t = langs.map((lang) => copyFor(input.kind, lang));
  const first = t[0];
  const both = langs.length > 1;
  const link = input.link;
  const href = link ? esc(link) : '';
  const code = input.code.replace(/[^0-9]/g, '');
  const assets = esc(input.assetBase.replace(/\/$/, ''));
  const join = (pick: (c: Copy) => string, sep = ' · ') => t.map(pick).join(sep);
  const subject = both ? `${first.subject(code)} · ${t[1].subject(code)}` : first.subject(code);

  const corner = (name: string, align: string, valign = 'top') =>
    `<td width="48" valign="${valign}" align="${align}" style="width:48px;padding:0;font-size:0;line-height:0;"><img src="${assets}/deco-${name}.png" width="48" height="48" alt="" style="display:block;width:48px;height:48px;border:0;"></td>`;
  const medallions = roleFiles
    .map((file, i) =>
      `<td align="center" style="padding:0 7px;"><img src="${assets}/role-${file}.png" width="48" height="48" alt="${esc(first.roles[i])}" title="${esc(first.roles[i])}" style="display:block;width:48px;height:48px;border:0;border-radius:24px;color:#c9bba3;font-family:${sans};font-size:10px;"></td>`
    )
    .join('');
  // One block per language: the kicker, the title, the lead. The second
  // language comes smaller, under a thin rule.
  const words = t
    .map((c, i) => {
      const lead = c.lead + (link ? c.leadLink : '');
      if (i === 0) {
        return `<p style="margin:0;font-family:${serif};font-size:16px;font-style:italic;color:#d6ad48;">${esc(c.kicker)}</p>
            <h1 class="title" style="margin:10px 0 0;font-family:${serif};font-size:36px;line-height:1.08;font-weight:900;letter-spacing:-0.5px;color:#efdfb9;">${esc(c.title)}</h1>
            <p style="margin:16px 0 0;font-family:${sans};font-size:16px;line-height:1.55;color:#c9bba3;">${esc(lead)}</p>`;
      }
      return `<p lang="${langs[i]}" style="margin:16px 0 0;padding-top:14px;border-top:1px solid #4a3a22;font-family:${sans};font-size:14px;line-height:1.5;color:#a89a84;"><b style="font-family:${serif};font-style:italic;font-weight:normal;color:#d6ad48;">${esc(c.title)}</b> ${esc(lead)}</p>`;
    })
    .join('\n            ');

  const button = !link
    ? ''
    : `<tr>
          <td align="center" style="padding:22px 24px 0;">
            <!--[if mso]><v:roundrect href="${href}" style="height:60px;v-text-anchor:middle;width:300px;" arcsize="24%" strokecolor="#d9b45a" strokeweight="2.5pt" fillcolor="#8a1520"><center style="color:#fff1d6;font-family:Georgia,serif;font-size:20px;font-weight:bold;letter-spacing:5px;">${esc(join((c) => c.button).toUpperCase())}</center></v:roundrect><![endif]-->
            <!--[if !mso]><!-- -->
            <table role="presentation" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td align="center" bgcolor="#d9b45a" style="border-radius:16px;background-color:#d9b45a;background-image:linear-gradient(180deg,#ffe7a8 0%,#d9b45a 42%,#9c7424 78%,#c9a23e 100%);padding:3px;box-shadow:0 0 22px rgba(255,180,67,.30),0 6px 14px rgba(0,0,0,.6);">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td align="center" bgcolor="#8a1520" style="border-radius:13px;background-color:#8a1520;background-image:linear-gradient(180deg,#b3242e 0%,#7e111a 55%,#4a070d 100%);">
                        <a href="${href}" target="_blank" style="display:inline-block;min-width:230px;padding:19px 30px;font-family:${serif};font-size:${both ? 17 : 20}px;line-height:20px;font-weight:bold;letter-spacing:${both ? 3 : 5}px;text-transform:uppercase;text-align:center;color:#fff1d6;text-decoration:none;border-radius:13px;">${esc(join((c) => c.button))}</a>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
            <!--<![endif]-->
          </td>
        </tr>`;

  const privacy = langs
    .map((lang, i) => `<a href="${esc(input.privacyUrl[lang])}" style="color:#e6c77a;">${esc(t[i].privacy)}</a>`)
    .join(' &nbsp;·&nbsp; ');

  const html = `<!doctype html>
<html lang="${langs[0]}" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="x-ua-compatible" content="ie=edge">
<meta name="color-scheme" content="dark only">
<meta name="supported-color-schemes" content="dark">
<meta name="format-detection" content="telephone=no, date=no, address=no, email=no">
<title>${esc(subject)}</title>
<!--[if mso]><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml><![endif]-->
<style>
  body { margin: 0 !important; padding: 0 !important; background: #0c0907; }
  a { color: #e6c77a; }
  :root { color-scheme: dark only; }
  .code { -webkit-user-select: all; user-select: all; }
  @media (max-width: 600px) {
    .card { width: 100% !important; }
    .pad { padding-left: 20px !important; padding-right: 20px !important; }
    .title { font-size: 31px !important; }
    .code { font-size: 40px !important; letter-spacing: 9px !important; }
    .wire { font-size: 10px !important; letter-spacing: 1.5px !important; }
  }
</style>
</head>
<body style="margin:0;padding:0;background:#0c0907;">
<div style="display:none;max-height:0;max-width:0;overflow:hidden;opacity:0;mso-hide:all;color:#0c0907;">${esc(join((c) => c.preheader(input.minutes), ' '))}&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0c0907" background="${assets}/brick.jpg" style="background-color:#0c0907;background-image:url('${assets}/brick.jpg');background-repeat:repeat;">
  <tr>
    <td align="center" style="padding:30px 10px 34px;">
      <!--[if mso]><table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" align="center"><tr><td><![endif]-->
      <table role="presentation" class="card" width="560" cellpadding="0" cellspacing="0" border="0" bgcolor="#130e0b" style="width:560px;max-width:560px;background-color:#130e0b;border:5px double #c9a23e;border-radius:6px;box-shadow:0 18px 50px rgba(0,0,0,.7);">
        <tr>
          <td style="padding:6px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>${corner('tl', 'left')}<td style="font-size:0;line-height:0;">&nbsp;</td>${corner('tr', 'right')}</tr>
            </table>
          </td>
        </tr>
        <tr>
          <td class="pad" align="center" style="padding:0 44px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr><td class="wire" align="center" style="border-top:1px solid #9c7424;border-bottom:1px solid #9c7424;padding:7px 0;font-family:${mono};font-size:11px;font-weight:bold;letter-spacing:3px;text-transform:uppercase;color:#d6ad48;">${esc(first.wire)}</td></tr>
            </table>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:16px 24px 0;">
            <img src="${assets}/oberta-neon.jpg" width="380" alt="${esc(first.alt)}" style="display:block;width:100%;max-width:380px;height:auto;border:0;color:#ff5a4a;font-family:${serif};font-size:40px;font-weight:bold;letter-spacing:8px;text-align:center;">
          </td>
        </tr>
        <tr>
          <td class="pad" align="center" style="padding:6px 44px 0;">
            ${words}
          </td>
        </tr>
        <tr>
          <td class="pad" align="center" style="padding:22px 44px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#e9d7ac" style="background-color:#e9d7ac;border-radius:2px;">
              <tr><td align="center" style="padding:12px 14px 2px;font-family:${mono};font-size:11px;font-weight:bold;letter-spacing:3px;text-transform:uppercase;color:#6b4f2a;">${esc(join((c) => c.codeLabel))}</td></tr>
              <tr><td align="center" style="padding:2px 10px 14px;"><span class="code" style="font-family:${mono};font-size:46px;line-height:56px;font-weight:bold;letter-spacing:12px;color:#1a1210;-webkit-user-select:all;user-select:all;">${esc(code)}</span></td></tr>
            </table>
          </td>
        </tr>
        ${button}
        <tr>
          <td class="pad" align="center" style="padding:18px 44px 0;">
            <p style="margin:0;font-family:${sans};font-size:14px;line-height:1.5;font-weight:bold;color:#e6c77a;">${t.map((c) => esc(c.valid(input.minutes, link !== null))).join('<br>')}</p>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:22px 24px 0;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>${medallions}</tr></table>
          </td>
        </tr>
        <tr>
          <td class="pad" align="right" style="padding:18px 52px 0;">
            <p style="margin:0;font-family:${serif};font-size:21px;font-style:italic;color:#efdfb9;">${esc(join((c) => c.sign, ' / '))}</p>
          </td>
        </tr>
        <tr>
          <td class="pad" style="padding:20px 44px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr><td style="border-top:1px solid #9c7424;font-size:0;line-height:0;height:3px;">&nbsp;</td></tr>
              <tr><td style="border-top:1px solid #9c7424;font-size:0;line-height:0;">&nbsp;</td></tr>
            </table>
            ${t.map((c) => `<p style="margin:12px 0 0;font-family:${sans};font-size:13px;line-height:1.5;color:#9c8f7b;">${esc(c.ignore)}</p>`).join('\n            ')}
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:18px 24px 0;">
            <p style="margin:0;font-family:${serif};font-size:15px;font-style:italic;color:#d6ad48;">${esc(first.motto)}</p>
          </td>
        </tr>
        <tr>
          <td style="padding:6px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>${corner('bl', 'left', 'bottom')}<td style="font-size:0;line-height:0;">&nbsp;</td>${corner('br', 'right', 'bottom')}</tr>
            </table>
          </td>
        </tr>
      </table>
      <table role="presentation" class="card" width="560" cellpadding="0" cellspacing="0" border="0" style="width:560px;max-width:560px;">
        <tr>
          <td class="pad" align="center" style="padding:20px 40px 0;font-family:${sans};font-size:12px;line-height:1.7;color:#a89a84;">
            ${t.map((c) => esc(c.why)).join('<br>')}<br>
            ${privacy}<br>
            Obertà · Charlie Mobile · Nicolai Tana · <a href="mailto:oberta@charliemobile.dev" style="color:#a89a84;">oberta@charliemobile.dev</a>
          </td>
        </tr>
      </table>
      <!--[if mso]></td></tr></table><![endif]-->
    </td>
  </tr>
</table>
</body>
</html>
`;

  const text = [
    `OBERTÀ — ${first.wire.toUpperCase()}`,
    '',
    ...t.flatMap((c) => [c.kicker, c.title, '', c.lead + (link ? c.leadLink : ''), '']),
    `${join((c) => c.codeLabel)}: ${code}`,
    '',
    ...(link ? [`${join((c) => c.button)}: ${link}`, ''] : []),
    ...t.map((c) => c.valid(input.minutes, link !== null)),
    '',
    join((c) => c.sign, ' / '),
    '',
    ...t.map((c) => c.ignore),
    first.motto,
    '',
    '--',
    ...t.map((c) => c.why),
    ...langs.map((lang, i) => `${t[i].privacy}: ${input.privacyUrl[lang]}`),
    'Obertà · Charlie Mobile · Nicolai Tana · oberta@charliemobile.dev',
    '',
  ].join('\n');

  return { subject, html, text };
}
