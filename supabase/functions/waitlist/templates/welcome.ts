// The welcome email (single opt-in: the sign-up is already done), as a 1940s telegram from the Famiglia: a dark
// brick wall, a card with a brass double rule and art-deco corners, the neon
// sign, a telegram slip, a Targa button to the roles page, four role medallions
// and the Padrino's signature. Tables and inline styles only, 560 px wide and
// fluid below, a VML button for Outlook, bgcolor fallbacks under every image.
// The images live on the site (site/oberta/email/, tool/site/email_assets.py).
// Previews with sample links: site/oberta/email/benvenuto-*.html (preview.ts).

export type Lang = 'it' | 'en';

export interface Links {
  /** The button: the site's roles page. */
  ctaUrl: string;
  unsubscribeUrl: string;
  privacyUrl: string;
  /** Where the images live: the site's email/ folder, absolute. */
  assetBase: string;
}

export interface Email {
  subject: string;
  html: string;
  text: string;
}

const copy = {
  it: {
    subject: 'Sei dei nostri',
    preheader: 'Iscrizione confermata. Ti scriviamo a dicembre, quando esce Obertà.',
    wire: 'Telegramma · Riservato · Sei dentro',
    thanks: 'Grazie per l’interesse.',
    title: 'Sei dei nostri.',
    lead: 'La Famiglia ha preso nota del tuo nome. Da adesso sei sulla lista: ti scriviamo a dicembre, quando esce Obertà, e sarai tra i primi a sederti al tavolo.',
    slip: 'ISCRIZIONE CONFERMATA STOP TI SCRIVIAMO A DICEMBRE STOP ACQUA IN BOCCA STOP',
    button: 'Scopri i ruoli',
    release: 'A dicembre, gratis, su iPhone, Android e Steam.',
    sign: '— Il Padrino',
    ignore: 'Non sei stato tu? Allora non ci conosciamo: cancellati qui sotto con un clic e non ti scriviamo più.',
    motto: 'Chi sa, tace.',
    why: 'Ricevi questa mail perché hai lasciato il tuo indirizzo su charliemobile.dev/oberta.',
    unsubscribe: 'Cancellami dalla lista',
    privacy: 'Informativa privacy',
    alt: 'OBERTÀ, insegna al neon',
    roles: ['Il Padrino', 'Il Commissario', 'Il Dottore', 'Il Picciotto'],
  },
  en: {
    subject: 'You are one of us',
    preheader: 'You are on the list. We write in December, when Obertà comes out.',
    wire: 'Telegram · Confidential · You are in',
    thanks: 'Thanks for your interest.',
    title: 'You are one of us.',
    lead: 'The Family has taken note of your name. You are on the list now: we write in December, when Obertà comes out, and you will be among the first at the table.',
    slip: 'SIGN-UP CONFIRMED STOP WE WRITE IN DECEMBER STOP NOT A WORD STOP',
    button: 'Meet the roles',
    release: 'December, free, on iPhone, Android and Steam.',
    sign: '— The Godfather',
    ignore: 'Not you? Then we have never met: unsubscribe below with one click and we never write again.',
    motto: 'Who knows, keeps quiet.',
    why: 'You get this email because you left your address on charliemobile.dev/oberta.',
    unsubscribe: 'Remove me from the list',
    privacy: 'Privacy policy',
    alt: 'OBERTÀ, neon sign',
    roles: ['The Godfather', 'The Inspector', 'The Doctor', 'The Henchman'],
  },
} as const;

const esc = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const serif = "Georgia, 'Times New Roman', Times, serif";
const sans = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif";
const mono = "'Courier New', Courier, monospace";
const roleFiles = ['padrino', 'detective', 'medico', 'mafioso'];

export function welcomeEmail(lang: Lang, links: Links): Email {
  const t = copy[lang] ?? copy.it;
  const cta = esc(links.ctaUrl);
  const unsubscribe = esc(links.unsubscribeUrl);
  const privacy = esc(links.privacyUrl);
  const base = esc(links.assetBase.replace(/\/$/, ''));
  const corner = (name: string, align: string) =>
    `<td width="48" valign="top" align="${align}" style="width:48px;padding:0;font-size:0;line-height:0;"><img src="${base}/deco-${name}.png" width="48" height="48" alt="" style="display:block;width:48px;height:48px;border:0;"></td>`;
  const medallions = roleFiles
    .map((file, i) =>
      `<td align="center" style="padding:0 7px;"><img src="${base}/role-${file}.png" width="56" height="56" alt="${esc(t.roles[i])}" title="${esc(t.roles[i])}" style="display:block;width:56px;height:56px;border:0;border-radius:28px;color:#c9bba3;font-family:${sans};font-size:10px;"></td>`
    )
    .join('');

  const html = `<!doctype html>
<html lang="${lang}" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="x-ua-compatible" content="ie=edge">
<meta name="color-scheme" content="dark only">
<meta name="supported-color-schemes" content="dark">
<meta name="format-detection" content="telephone=no, date=no, address=no, email=no">
<title>${esc(t.subject)}</title>
<!--[if mso]><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml><![endif]-->
<style>
  body { margin: 0 !important; padding: 0 !important; background: #0c0907; }
  a { color: #e6c77a; }
  :root { color-scheme: dark only; }
  @media (max-width: 600px) {
    .card { width: 100% !important; }
    .pad { padding-left: 20px !important; padding-right: 20px !important; }
    .title { font-size: 31px !important; }
    .slip { font-size: 12px !important; letter-spacing: 1px !important; }
  }
</style>
</head>
<body style="margin:0;padding:0;background:#0c0907;">
<div style="display:none;max-height:0;max-width:0;overflow:hidden;opacity:0;mso-hide:all;color:#0c0907;">${esc(t.preheader)}&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0c0907" background="${base}/brick.jpg" style="background-color:#0c0907;background-image:url('${base}/brick.jpg');background-repeat:repeat;">
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
              <tr><td align="center" style="border-top:1px solid #9c7424;border-bottom:1px solid #9c7424;padding:7px 0;font-family:${mono};font-size:11px;font-weight:bold;letter-spacing:3px;text-transform:uppercase;color:#d6ad48;">${esc(t.wire)}</td></tr>
            </table>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:18px 24px 0;">
            <img src="${base}/oberta-neon.jpg" width="460" alt="${esc(t.alt)}" style="display:block;width:100%;max-width:460px;height:auto;border:0;color:#ff5a4a;font-family:${serif};font-size:44px;font-weight:bold;letter-spacing:8px;text-align:center;">
          </td>
        </tr>
        <tr>
          <td class="pad" align="center" style="padding:6px 44px 0;">
            <p style="margin:0;font-family:${serif};font-size:16px;font-style:italic;color:#d6ad48;">${esc(t.thanks)}</p>
            <h1 class="title" style="margin:10px 0 0;font-family:${serif};font-size:36px;line-height:1.08;font-weight:900;letter-spacing:-0.5px;color:#efdfb9;">${esc(t.title)}</h1>
            <p style="margin:16px 0 0;font-family:${sans};font-size:16px;line-height:1.55;color:#c9bba3;">${esc(t.lead)}</p>
          </td>
        </tr>
        <tr>
          <td class="pad" align="center" style="padding:22px 44px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#e9d7ac" style="background-color:#e9d7ac;border-radius:2px;">
              <tr><td class="slip" align="center" style="padding:12px 14px;font-family:${mono};font-size:13px;line-height:1.5;font-weight:bold;letter-spacing:1.5px;color:#1a1210;">${esc(t.slip)}</td></tr>
            </table>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:26px 24px 0;">
            <!--[if mso]><v:roundrect href="${cta}" style="height:60px;v-text-anchor:middle;width:300px;" arcsize="24%" strokecolor="#d9b45a" strokeweight="2.5pt" fillcolor="#8a1520"><center style="color:#fff1d6;font-family:Georgia,serif;font-size:20px;font-weight:bold;letter-spacing:5px;">${esc(t.button.toUpperCase())}</center></v:roundrect><![endif]-->
            <!--[if !mso]><!-- -->
            <table role="presentation" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td align="center" bgcolor="#d9b45a" style="border-radius:16px;background-color:#d9b45a;background-image:linear-gradient(180deg,#ffe7a8 0%,#d9b45a 42%,#9c7424 78%,#c9a23e 100%);padding:3px;box-shadow:0 0 22px rgba(255,180,67,.30),0 6px 14px rgba(0,0,0,.6);">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td align="center" bgcolor="#8a1520" style="border-radius:13px;background-color:#8a1520;background-image:linear-gradient(180deg,#b3242e 0%,#7e111a 55%,#4a070d 100%);">
                        <a href="${cta}" target="_blank" style="display:inline-block;min-width:230px;padding:19px 34px;font-family:${serif};font-size:20px;line-height:20px;font-weight:bold;letter-spacing:5px;text-transform:uppercase;text-align:center;color:#fff1d6;text-decoration:none;border-radius:13px;">${esc(t.button)}</a>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
            <!--<![endif]-->
          </td>
        </tr>
        <tr>
          <td class="pad" align="center" style="padding:20px 44px 0;">
            <p style="margin:0;font-family:${sans};font-size:14px;font-weight:bold;letter-spacing:.3px;color:#e6c77a;">${esc(t.release)}</p>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:22px 24px 0;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>${medallions}</tr></table>
          </td>
        </tr>
        <tr>
          <td class="pad" align="right" style="padding:20px 52px 0;">
            <p style="margin:0;font-family:${serif};font-size:22px;font-style:italic;color:#efdfb9;">${esc(t.sign)}</p>
          </td>
        </tr>
        <tr>
          <td class="pad" style="padding:22px 44px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr><td style="border-top:1px solid #9c7424;font-size:0;line-height:0;height:3px;">&nbsp;</td></tr>
              <tr><td style="border-top:1px solid #9c7424;font-size:0;line-height:0;">&nbsp;</td></tr>
            </table>
            <p style="margin:12px 0 0;font-family:${sans};font-size:13px;line-height:1.5;color:#9c8f7b;">${esc(t.ignore)}</p>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:18px 24px 0;">
            <p style="margin:0;font-family:${serif};font-size:15px;font-style:italic;color:#d6ad48;">${esc(t.motto)}</p>
          </td>
        </tr>
        <tr>
          <td style="padding:6px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>${corner('bl', 'left').replace('valign="top"', 'valign="bottom"')}<td style="font-size:0;line-height:0;">&nbsp;</td>${corner('br', 'right').replace('valign="top"', 'valign="bottom"')}</tr>
            </table>
          </td>
        </tr>
      </table>
      <table role="presentation" class="card" width="560" cellpadding="0" cellspacing="0" border="0" style="width:560px;max-width:560px;">
        <tr>
          <td class="pad" align="center" style="padding:20px 40px 0;font-family:${sans};font-size:12px;line-height:1.7;color:#a89a84;">
            ${esc(t.why)}<br>
            <a href="${unsubscribe}" style="color:#e6c77a;">${esc(t.unsubscribe)}</a> &nbsp;·&nbsp; <a href="${privacy}" style="color:#e6c77a;">${esc(t.privacy)}</a><br>
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
    `OBERTÀ — ${t.wire.toUpperCase()}`,
    '',
    t.thanks,
    t.title,
    '',
    t.lead,
    '',
    t.slip,
    '',
    `${t.button}: ${links.ctaUrl}`,
    '',
    t.release,
    '',
    t.sign,
    '',
    t.ignore,
    t.motto,
    '',
    '--',
    t.why,
    `${t.unsubscribe}: ${links.unsubscribeUrl}`,
    `${t.privacy}: ${links.privacyUrl}`,
    'Obertà · Charlie Mobile · Nicolai Tana · oberta@charliemobile.dev',
    '',
  ].join('\n');

  return { subject: t.subject, html, text };
}
