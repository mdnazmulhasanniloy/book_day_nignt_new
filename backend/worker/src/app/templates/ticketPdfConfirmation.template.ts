import { companyInformation } from '@/const';

const ticketPdfConfirmationTemplate = `
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Booking Confirmed - ${companyInformation.name}</title>
</head>
<body style="margin:0; padding:0; background-color:#0d0d12; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol';">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0d0d12; padding:40px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="520" cellpadding="0" cellspacing="0" style="background-color:#16161f; border-radius:12px; overflow:hidden; border:1px solid #2a2418;">

          <tr>
            <td align="center" style="padding:32px 24px 16px 24px;">
              <img src="${companyInformation.logo}" alt="${companyInformation.name}" width="168" style="display:block;max-width:168px;height:auto;" />
            </td>
          </tr>

          <tr>
            <td style="padding:0 24px;">
              <hr style="border:none; border-top:1px solid #3a3224; margin:0;" />
            </td>
          </tr>

          <tr>
            <td align="center" style="padding:36px 32px 8px 32px;">
              <p style="margin:0 0 10px 0; color:#d4af37; font-size:12px; letter-spacing:2px; text-transform:uppercase; font-weight:700;">
                Booking Confirmed
              </p>
              <h1 style="margin:0 0 12px 0; color:#ffffff; font-size:24px; font-weight:700; letter-spacing:-0.5px;">
                Your ticket is ready
              </h1>
              <p style="margin:0; color:#e2e8f0; font-size:15px; line-height:1.7;">
                Hi {{buyerName}},<br><br>
                Thanks for booking with BookDia Night. Your ticket PDF is attached — show the QR at the door even without internet.
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding:28px 32px 8px 32px;">
              <p style="margin:0 0 14px 0; color:#d4af37; font-size:12px; letter-spacing:1.5px; text-transform:uppercase; font-weight:700;">
                Booking Summary
              </p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#1f1f2b; border-radius:8px; border:1px solid #3a3224;">
                <tr>
                  <td style="padding:16px;">
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Ref:</strong> {{bookingRef}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">{{venueLabel}}:</strong> {{venueName}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Location:</strong> {{venueLocation}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">When:</strong> {{whenLabel}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Pass:</strong> {{passLabel}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Guests:</strong> {{guestLabel}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Guest:</strong> {{buyerName}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Email:</strong> {{buyerEmail}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Phone:</strong> {{buyerPhone}}</p>
                    <p style="margin:0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Paid:</strong> {{amountPaid}} · {{paidAt}}</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          {{#if hasPerks}}
          <tr>
            <td style="padding:20px 32px 8px 32px;">
              <p style="margin:0 0 14px 0; color:#d4af37; font-size:12px; letter-spacing:1.5px; text-transform:uppercase; font-weight:700;">
                Included Perks
              </p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#1f1f2b; border-radius:8px; border:1px solid #3a3224;">
                <tr>
                  <td style="padding:16px;">
                    {{#each perks}}
                    <p style="margin:0 0 6px 0; color:#cbd5e1; font-size:13px;">• {{this}}</p>
                    {{/each}}
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          {{/if}}

          {{#if entryNotes}}
          <tr>
            <td style="padding:20px 32px 8px 32px;">
              <p style="margin:0 0 14px 0; color:#d4af37; font-size:12px; letter-spacing:1.5px; text-transform:uppercase; font-weight:700;">
                Entry Notes
              </p>
              <p style="margin:0; color:#cbd5e1; font-size:13px; line-height:1.6;">{{entryNotes}}</p>
            </td>
          </tr>
          {{/if}}

          <tr>
            <td align="center" style="padding:28px 32px 12px 32px;">
              <a href="{{downloadUrl}}" style="display:inline-block; background-color:#d4af37; color:#141414; text-decoration:none; font-weight:700; font-size:14px; letter-spacing:0.3px; padding:14px 28px; border-radius:8px;">
                Download Ticket PDF
              </a>
              <p style="margin:12px 0 0 0; color:#94a3b8; font-size:11px; line-height:1.5;">
                Link expires in 7 days. The PDF is also attached to this email.
              </p>
            </td>
          </tr>

          <tr>
            <td align="center" style="padding:20px 32px 36px 32px;">
              <p style="margin:0; color:#94a3b8; font-size:12px; line-height:1.6;">
                ${companyInformation.copyright}<br>
                Need help? Contact us at
                <a href="mailto:${companyInformation.email}" style="color:#d4af37; text-decoration:none;">${companyInformation.email}</a>
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`;

export default ticketPdfConfirmationTemplate;
