import { companyInformation } from '@/const';

const clubWaitingListSeatAvailableTemplate = `
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>A Spot Just Opened Up! - ${companyInformation.name}</title>
</head>
<body style="margin:0; padding:0; background-color:#0d0d12; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol';">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0d0d12; padding:40px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="background-color:#16161f; border-radius:12px; overflow:hidden; border:1px solid #26262f;">
 
          <!-- Header -->
          <tr>
            <td align="center" style="padding:32px 24px 16px 24px;">
              <img src="${companyInformation.logo}" alt="${companyInformation.name}" width="168" style="display:block;max-width:168px;height:auto;" />
            </td>
          </tr>
 
          <!-- Divider -->
          <tr>
            <td style="padding:0 24px;">
              <hr style="border:none; border-top:1px solid #26262f; margin:0;" />
            </td>
          </tr>
 
          <!-- Hero -->
          <tr>
            <td align="center" style="padding:36px 32px 8px 32px;">
              <div style="font-size:40px; line-height:1; margin-bottom:12px;">🎉</div>
              <h1 style="margin:0 0 12px 0; color:#ffffff; font-size:24px; font-weight:700; letter-spacing:-0.5px;">
                A Spot Just Opened Up!
              </h1>
              <p style="margin:0; color:#ffffff; font-size:16px; line-height:1.7;">
                Hi {{userName}},<br><br>
                Great news! You were on the waiting list for <strong>{{clubName}}</strong>, and a table or seat has just become available!
              </p>
            </td>
          </tr>

          <!-- Club Card Preview -->
          <tr>
            <td style="padding:16px 32px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#1f1f2b; border-radius:8px; border:1px solid #2f2f3e; padding:16px;">
                <tr>
                  {{#if clubThumbnail}}
                  <td width="80" style="vertical-align:top; padding-right:16px;">
                    <img src="{{clubThumbnail}}" alt="{{clubName}}" width="80" height="80" style="border-radius:8px; object-fit:cover; display:block;" />
                  </td>
                  {{/if}}
                  <td style="vertical-align:top;">
                    <h3 style="margin:0 0 4px 0; color:#ffffff; font-size:16px; font-weight:600;">{{clubName}}</h3>
                    <p style="margin:0; color:#94a3b8; font-size:13px; line-height:1.4;">📍 {{clubLocation}}</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
 
          <!-- Action Button -->
          <tr>
            <td align="center" style="padding:24px 32px 32px 32px;">
              <p style="margin:0 0 20px 0; color:#cbd5e1; font-size:14px; line-height:1.5;">
                Spots fill quickly on a first-come, first-served basis. Open the BookDiaNight app now to reserve your spot!
              </p>
              <a href="{{serverUrl}}/explore/club/{{clubId}}" style="display:inline-block; background-color:#8b5cf6; color:#ffffff; text-decoration:none; padding:14px 32px; border-radius:8px; font-size:16px; font-weight:600;">
                Book Now
              </a>
            </td>
          </tr>
 
          <!-- Divider -->
          <tr>
            <td style="padding:0 24px;">
              <hr style="border:none; border-top:1px solid #26262f; margin:0;" />
            </td>
          </tr>
 
          <!-- Footer -->
          <tr>
            <td align="center" style="padding:24px 32px 32px 32px;">
              <p style="margin:0; color:#475569; font-size:12px; line-height:1.6;">
                ${companyInformation.name} &bull; ${companyInformation.address}<br />
                Need help? <a href="mailto:${companyInformation.email}" style="color:#8b5cf6; text-decoration:none;">Contact Support</a>
              </p>
            </td>
          </tr>
 
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`.trim();

export default clubWaitingListSeatAvailableTemplate;
