import { companyInformation } from '@/const';

const hostContactTemplate = `
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>New VIP Inquiry - ${companyInformation.name}</title>
</head>
<body style="margin:0; padding:0; background-color:#0d0d12; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol';">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0d0d12; padding:40px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="background-color:#16161f; border-radius:12px; overflow:hidden; border:1px solid #26262f;">

          <tr>
            <td align="center" style="padding:32px 24px 16px 24px;">
              <img src="${companyInformation.logo}" alt="${companyInformation.name}" width="168" style="display:block;max-width:168px;height:auto;" />
            </td>
          </tr>

          <tr>
            <td style="padding:0 24px;">
              <hr style="border:none; border-top:1px solid #26262f; margin:0;" />
            </td>
          </tr>

          <tr>
            <td align="center" style="padding:36px 32px 8px 32px;">
              <div style="font-size:40px; line-height:1; margin-bottom:12px;">📩</div>
              <h1 style="margin:0 0 12px 0; color:#ffffff; font-size:24px; font-weight:700; letter-spacing:-0.5px;">
                New VIP Inquiry
              </h1>
              <p style="margin:0; color:#ffffff; font-size:16px; line-height:1.7;">
                Hi {{hostName}},<br><br>
                Someone contacted you through BookDiaNight. Reply to them directly using the details below.
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding:28px 32px 8px 32px;">
              <p style="margin:0 0 18px 0; color:#8b5cf6; font-size:12px; letter-spacing:1.5px; text-transform:uppercase; font-weight:700;">
                Client Details
              </p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#1f1f2b; border-radius:8px; border:1px solid #2f2f3e;">
                <tr>
                  <td style="padding:16px;">
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Name:</strong> {{clientName}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Email:</strong> {{clientEmail}}</p>
                    <p style="margin:0 0 8px 0; color:#cbd5e1; font-size:13px;"><strong style="color:#f8fafc;">Phone:</strong> {{clientPhone}}</p>
                    <p style="margin:0; color:#cbd5e1; font-size:13px; line-height:1.6;"><strong style="color:#f8fafc;">Message:</strong><br>{{message}}</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <tr>
            <td align="center" style="padding:28px 32px 36px 32px;">
              <p style="margin:0; color:#94a3b8; font-size:12px; line-height:1.6;">
                ${companyInformation.copyright}<br>
                Need help? Contact us at
                <a href="mailto:${companyInformation.email}" style="color:#8b5cf6; text-decoration:none;">${companyInformation.email}</a>
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

export default hostContactTemplate;
