// The welcome email (single opt-in: the sign-up is already done), as a 1940s
// telegram from the Famiglia, with NO images at all (Outlook and many clients
// block remote images): the OBERTÀ wordmark is letter-spaced serif text with a
// glow where supported, the brass double frame is nested table cells with
// bgcolor, the art-deco touches are unicode ornaments (◆ ✦ ❖ ─), the roles are
// small bordered cells. Every colour is a bgcolor attribute as well as CSS,
// the button is a padded table cell with a VML twin for Outlook.
// Previews with sample links: site/oberta/email/benvenuto-*.html (preview.ts).

export type Lang = 'it' | 'en';

export interface Links {
  /** The button: the site's roles page. */
  ctaUrl: string;
  unsubscribeUrl: string;
  privacyUrl: string;
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
    roles: [['♛', 'Il Padrino'], ['✦', 'Il Commissario'], ['✚', 'Il Dottore'], ['♠', 'Il Picciotto']],
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
    roles: [['♛', 'The Godfather'], ['✦', 'The Inspector'], ['✚', 'The Doctor'], ['♠', 'The Henchman']],
  },
} as const;

const esc = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const serif = "Georgia, 'Times New Roman', Times, serif";
const sans = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif";
const mono = "'Courier New', Courier, monospace";
const GOLD = '#C9A227';
const BRASS = '#9C7424';
const INK = '#0C0907';
const CARD = '#140F0B';
const PAPER = '#E9D7AC';
const CREAM = '#EFDFB9';
const MUTED = '#C9BBA3';
const DIM = '#9C8F7B';
const ENAMEL = '#8A1520';

export function welcomeEmail(lang: Lang, links: Links): Email {
  const t = copy[lang] ?? copy.it;
  const cta = esc(links.ctaUrl);
  const unsubscribe = esc(links.unsubscribeUrl);
  const privacy = esc(links.privacyUrl);
  const ornament = (size: number, colour = GOLD) =>
    `<p style="margin:0;font-family:${serif};font-size:${size}px;line-height:1;letter-spacing:6px;color:${colour};">&#9472;&#9472;&#9472;&#9472;&nbsp;&#9670;&nbsp;&#10022;&nbsp;&#9670;&nbsp;&#9472;&#9472;&#9472;&#9472;</p>`;
  const medallions = t.roles
    .map(([symbol, name]) =>
      `<td align="center" valign="top" width="25%" style="padding:0 4px;">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center"><tr>
                    <td align="center" valign="middle" width="46" height="46" bgcolor="${ENAMEL}" style="width:46px;height:46px;border:2px solid ${GOLD};border-radius:25px;background-color:${ENAMEL};font-family:${serif};font-size:22px;line-height:46px;color:${CREAM};">${symbol}</td>
                  </tr></table>
                  <p style="margin:8px 0 0;font-family:${sans};font-size:11px;line-height:1.3;font-weight:bold;letter-spacing:.5px;color:${MUTED};">${esc(name)}</p>
                </td>`
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
  body { margin: 0 !important; padding: 0 !important; background: ${INK}; }
  a { color: ${GOLD}; }
  :root { color-scheme: dark only; }
  @media (max-width: 600px) {
    .card { width: 100% !important; }
    .pad { padding-left: 20px !important; padding-right: 20px !important; }
    .title { font-size: 31px !important; }
    .mark { font-size: 44px !important; letter-spacing: 8px !important; }
    .slip { font-size: 12px !important; letter-spacing: 1px !important; }
  }
</style>
</head>
<body bgcolor="${INK}" style="margin:0;padding:0;background-color:${INK};">
<div style="display:none;max-height:0;max-width:0;overflow:hidden;opacity:0;mso-hide:all;color:${INK};">${esc(t.preheader)}&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${INK}" style="background-color:${INK};">
  <tr>
    <td align="center" style="padding:28px 10px 34px;">
      <!--[if mso]><table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" align="center"><tr><td><![endif]-->
      <!-- Brass double frame: gold, a dark gap, gold again, then the card. -->
      <table role="presentation" class="card" width="560" cellpadding="0" cellspacing="0" border="0" bgcolor="${GOLD}" style="width:560px;max-width:560px;background-color:${GOLD};">
        <tr><td style="padding:2px;" bgcolor="${GOLD}">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${INK}" style="background-color:${INK};">
            <tr><td style="padding:4px;" bgcolor="${INK}">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${BRASS}" style="background-color:${BRASS};">
                <tr><td style="padding:1px;" bgcolor="${BRASS}">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${CARD}" style="background-color:${CARD};">
                    <tr>
                      <td class="pad" align="center" bgcolor="${CARD}" style="padding:22px 40px 0;background-color:${CARD};">
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                          <tr>
                            <td align="left" style="font-family:${serif};font-size:16px;line-height:1;color:${GOLD};">&#10070;</td>
                            <td align="center" style="font-family:${mono};font-size:11px;font-weight:bold;letter-spacing:3px;text-transform:uppercase;color:${GOLD};">${esc(t.wire)}</td>
                            <td align="right" style="font-family:${serif};font-size:16px;line-height:1;color:${GOLD};">&#10070;</td>
                          </tr>
                        </table>
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:12px;">
                          <tr><td height="1" bgcolor="${BRASS}" style="height:1px;font-size:0;line-height:0;background-color:${BRASS};">&nbsp;</td></tr>
                          <tr><td height="3" style="height:3px;font-size:0;line-height:0;">&nbsp;</td></tr>
                          <tr><td height="1" bgcolor="${BRASS}" style="height:1px;font-size:0;line-height:0;background-color:${BRASS};">&nbsp;</td></tr>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <td align="center" bgcolor="${CARD}" style="padding:34px 16px 6px;background-color:${CARD};">
                        <p class="mark" style="margin:0;font-family:${serif};font-size:58px;line-height:1;font-weight:bold;letter-spacing:12px;color:${GOLD};text-shadow:0 0 6px rgba(255,190,80,.55),0 0 22px rgba(201,162,39,.45),0 0 40px rgba(165,29,37,.5);">OBERT&Agrave;</p>
                        <div style="height:18px;line-height:18px;font-size:18px;">&nbsp;</div>
                        ${ornament(12)}
                      </td>
                    </tr>
                    <tr>
                      <td class="pad" align="center" bgcolor="${CARD}" style="padding:22px 40px 0;background-color:${CARD};">
                        <p style="margin:0;font-family:${serif};font-size:16px;font-style:italic;color:${GOLD};">${esc(t.thanks)}</p>
                        <h1 class="title" style="margin:10px 0 0;font-family:${serif};font-size:36px;line-height:1.08;font-weight:900;color:${CREAM};">${esc(t.title)}</h1>
                        <p style="margin:16px 0 0;font-family:${sans};font-size:16px;line-height:1.55;color:${MUTED};">${esc(t.lead)}</p>
                      </td>
                    </tr>
                    <tr>
                      <td class="pad" align="center" bgcolor="${CARD}" style="padding:22px 40px 0;background-color:${CARD};">
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${PAPER}" style="background-color:${PAPER};">
                          <tr><td class="slip" align="center" bgcolor="${PAPER}" style="padding:12px 14px;background-color:${PAPER};border-top:2px dashed ${BRASS};border-bottom:2px dashed ${BRASS};font-family:${mono};font-size:13px;line-height:1.5;font-weight:bold;letter-spacing:1.5px;color:#1A1210;">${esc(t.slip)}</td></tr>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <td align="center" bgcolor="${CARD}" style="padding:28px 24px 0;background-color:${CARD};">
                        <!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="${cta}" style="height:58px;v-text-anchor:middle;width:300px;" arcsize="20%" strokecolor="${GOLD}" strokeweight="2.5pt" fillcolor="${ENAMEL}"><center style="color:#FFF1D6;font-family:Georgia,serif;font-size:18px;font-weight:bold;letter-spacing:4px;">${esc(t.button.toUpperCase())}</center></v:roundrect><![endif]-->
                        <!--[if !mso]><!-- -->
                        <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                          <tr>
                            <td align="center" bgcolor="${GOLD}" style="padding:3px;border-radius:16px;background-color:${GOLD};">
                              <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                                <tr>
                                  <td align="center" bgcolor="${ENAMEL}" style="border-radius:13px;background-color:${ENAMEL};">
                                    <a href="${cta}" target="_blank" style="display:inline-block;min-width:230px;padding:18px 32px;font-family:${serif};font-size:18px;line-height:20px;font-weight:bold;letter-spacing:4px;text-transform:uppercase;text-align:center;color:#FFF1D6;text-decoration:none;border-radius:13px;">${esc(t.button)}</a>
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
                      <td class="pad" align="center" bgcolor="${CARD}" style="padding:20px 40px 0;background-color:${CARD};">
                        <p style="margin:0;font-family:${sans};font-size:14px;font-weight:bold;letter-spacing:.3px;color:${GOLD};">${esc(t.release)}</p>
                      </td>
                    </tr>
                    <tr>
                      <td class="pad" align="center" bgcolor="${CARD}" style="padding:24px 28px 0;background-color:${CARD};">
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>${medallions}</tr></table>
                      </td>
                    </tr>
                    <tr>
                      <td class="pad" align="right" bgcolor="${CARD}" style="padding:22px 48px 0;background-color:${CARD};">
                        <p style="margin:0;font-family:${serif};font-size:22px;font-style:italic;color:${CREAM};">${esc(t.sign)}</p>
                      </td>
                    </tr>
                    <tr>
                      <td class="pad" bgcolor="${CARD}" style="padding:22px 40px 0;background-color:${CARD};">
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                          <tr><td height="1" bgcolor="${BRASS}" style="height:1px;font-size:0;line-height:0;background-color:${BRASS};">&nbsp;</td></tr>
                          <tr><td height="3" style="height:3px;font-size:0;line-height:0;">&nbsp;</td></tr>
                          <tr><td height="1" bgcolor="${BRASS}" style="height:1px;font-size:0;line-height:0;background-color:${BRASS};">&nbsp;</td></tr>
                        </table>
                        <p style="margin:14px 0 0;font-family:${sans};font-size:13px;line-height:1.5;color:${DIM};">${esc(t.ignore)}</p>
                      </td>
                    </tr>
                    <tr>
                      <td align="center" bgcolor="${CARD}" style="padding:18px 24px 24px;background-color:${CARD};">
                        <p style="margin:0 0 12px;font-family:${serif};font-size:15px;font-style:italic;color:${GOLD};">${esc(t.motto)}</p>
                        ${ornament(10, BRASS)}
                      </td>
                    </tr>
                  </table>
                </td></tr>
              </table>
            </td></tr>
          </table>
        </td></tr>
      </table>
      <table role="presentation" class="card" width="560" cellpadding="0" cellspacing="0" border="0" style="width:560px;max-width:560px;">
        <tr>
          <td class="pad" align="center" bgcolor="${INK}" style="padding:20px 40px 0;background-color:${INK};font-family:${sans};font-size:12px;line-height:1.7;color:#A89A84;">
            ${esc(t.why)}<br>
            <a href="${unsubscribe}" style="color:${GOLD};">${esc(t.unsubscribe)}</a> &nbsp;&middot;&nbsp; <a href="${privacy}" style="color:${GOLD};">${esc(t.privacy)}</a><br>
            Obert&agrave; &middot; Charlie Mobile &middot; Nicolai Tana &middot; <a href="mailto:oberta@charliemobile.dev" style="color:#A89A84;">oberta@charliemobile.dev</a>
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
