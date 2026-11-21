import { companyInformation } from '@/const';

const clubTicketTemplate = `
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>BookDia Night — Club Pass</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@600;700&family=Manrope:wght@400;500;600;700;800&display=swap');

  * { box-sizing: border-box; margin: 0; padding: 0; }

  html, body {
    width: 100%;
    margin: 0;
    padding: 0;
    background: #141414;
    font-family: 'Manrope', 'Helvetica Neue', Arial, sans-serif;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
    color: #F5F1E8;
  }

  .ticket {
    width: 100%;
    min-height: 100%;
    background:
      radial-gradient(120% 60% at 0% 0%, rgba(220,167,58,0.16) 0%, rgba(220,167,58,0) 55%),
      radial-gradient(90% 50% at 100% 100%, rgba(220,167,58,0.10) 0%, rgba(220,167,58,0) 50%),
      #141414;
    position: relative;
    overflow: hidden;
  }

  .accent-bar {
    height: 4px;
    background: linear-gradient(90deg, #B8892A 0%, #DCA73A 40%, #F2D281 70%, #DCA73A 100%);
  }

  .main {
    padding: 22px 20px 18px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .brand-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
  }

  .brand {
    display: flex;
    align-items: center;
    gap: 12px;
    min-width: 0;
  }

  .brand-logo-box {
    height: 58px;
    width: auto;
    border-radius: 8px;
    background: #000;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 4px 6px;
    flex: none;
  }
  .brand-logo-box img {
    height: 50px;
    width: auto;
    max-width: 150px;
    object-fit: contain;
    display: block;
  }

  .brand-sub {
    font-size: 9px;
    letter-spacing: 1.8px;
    text-transform: uppercase;
    color: #DCA73A;
    font-weight: 700;
  }

  .pass-badge {
    flex: none;
    font-size: 9px;
    font-weight: 800;
    letter-spacing: 1.2px;
    text-transform: uppercase;
    color: #141414;
    background: linear-gradient(135deg, #F2D281, #DCA73A 55%, #B8892A);
    padding: 8px 12px;
    border-radius: 999px;
    white-space: nowrap;
  }

  .event-name {
    font-family: 'Cormorant Garamond', Georgia, serif;
    font-size: 28px;
    font-weight: 700;
    line-height: 1.15;
    color: #FAF7F0;
  }
  .tier-name {
    margin-top: 6px;
    font-size: 13px;
    font-weight: 700;
    color: #DCA73A;
  }
  .venue-line {
    margin-top: 8px;
    font-size: 11px;
    line-height: 1.45;
    color: #B8B3A8;
  }

  .meta-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
  .meta-card {
    background: rgba(255,255,255,0.04);
    border: 1px solid rgba(220,167,58,0.18);
    border-radius: 12px;
    padding: 12px 12px 11px;
  }
  .meta-card.full { grid-column: 1 / -1; }
  .meta-label {
    font-size: 9px;
    letter-spacing: 1.4px;
    text-transform: uppercase;
    color: #8F8A80;
    font-weight: 700;
  }
  .meta-value {
    margin-top: 5px;
    font-size: 13px;
    font-weight: 700;
    color: #fff;
    line-height: 1.3;
  }

  .guest-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px;
    border-radius: 14px;
    background: rgba(220,167,58,0.07);
    border: 1px solid rgba(220,167,58,0.22);
  }
  .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    flex: none;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(145deg, #F2D281, #DCA73A);
    color: #141414;
    font-weight: 800;
    font-size: 13px;
  }
  .guest-label {
    font-size: 9px;
    letter-spacing: 1.3px;
    text-transform: uppercase;
    color: #8F8A80;
    font-weight: 700;
  }
  .guest-name {
    margin-top: 3px;
    font-size: 14px;
    font-weight: 700;
    color: #fff;
  }

  .perks {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .perk-pill {
    font-size: 10px;
    font-weight: 700;
    color: #F2D281;
    border: 1px solid rgba(220,167,58,0.35);
    background: rgba(220,167,58,0.08);
    border-radius: 999px;
    padding: 6px 10px;
  }

  .tear {
    position: relative;
    height: 18px;
    background:
      linear-gradient(90deg, transparent 0, transparent 10px, rgba(220,167,58,0.45) 10px, rgba(220,167,58,0.45) calc(100% - 10px), transparent calc(100% - 10px));
    background-size: 100% 1.5px;
    background-position: center;
    background-repeat: no-repeat;
  }
  .tear::before,
  .tear::after {
    content: "";
    position: absolute;
    top: 50%;
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: #0b0b0b;
    transform: translateY(-50%);
  }
  .tear::before { left: -9px; }
  .tear::after { right: -9px; }

  .stub {
    padding: 8px 20px 22px;
    background: #101010;
  }

  .stub-top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 14px;
  }
  .stub-copy { min-width: 0; flex: 1; padding-top: 4px; }
  .stub-eyebrow {
    font-size: 9px;
    letter-spacing: 1.8px;
    text-transform: uppercase;
    color: #DCA73A;
    font-weight: 800;
  }
  .stub-title {
    margin-top: 6px;
    font-family: 'Cormorant Garamond', Georgia, serif;
    font-size: 18px;
    font-weight: 700;
    color: #fff;
    line-height: 1.2;
  }
  .stub-sub {
    margin-top: 4px;
    font-size: 11px;
    color: #B8B3A8;
    line-height: 1.4;
  }

  .qr-panel {
    flex: none;
    width: 108px;
    text-align: center;
  }
  .qr-frame {
    width: 108px;
    height: 108px;
    background: #fff;
    border-radius: 12px;
    padding: 7px;
  }
  .qr-frame img {
    width: 100%;
    height: 100%;
    display: block;
  }
  .qr-caption {
    margin-top: 6px;
    font-size: 8px;
    color: #8F8A80;
    word-break: break-all;
    line-height: 1.35;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  }

  .receipt {
    margin-top: 16px;
    border-radius: 14px;
    overflow: hidden;
    border: 1px solid rgba(220,167,58,0.22);
    background: rgba(255,255,255,0.03);
  }
  .receipt-row {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    padding: 11px 14px;
    font-size: 12px;
    color: #B8B3A8;
    border-bottom: 1px solid rgba(255,255,255,0.06);
  }
  .receipt-row span:last-child {
    color: #F0EBE1;
    font-weight: 600;
  }
  .receipt-total {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
    padding: 14px;
    background: linear-gradient(135deg, rgba(220,167,58,0.18), rgba(220,167,58,0.06));
  }
  .receipt-total .label {
    font-size: 11px;
    letter-spacing: 1.4px;
    text-transform: uppercase;
    font-weight: 800;
    color: #F2D281;
  }
  .receipt-total .amount {
    font-family: 'Cormorant Garamond', Georgia, serif;
    font-size: 24px;
    font-weight: 700;
    color: #DCA73A;
    line-height: 1;
  }

  .fine-print {
    margin-top: 12px;
    font-size: 9px;
    color: #6E6A62;
    line-height: 1.55;
  }
</style>
</head>
<body>
  <div class="ticket">
    <div class="accent-bar"></div>

    <div class="main">
      <div class="brand-row">
        <div class="brand">
          <div class="brand-logo-box">
            <img src="${companyInformation.logo}" alt="${companyInformation.name}" />
          </div>
          <div class="brand-sub">Official Club Pass</div>
        </div>
        <div class="pass-badge">{{passBadge}}</div>
      </div>

      <div>
        <div class="event-name">{{clubBookingDetails.clubName}}</div>
        {{#if clubBookingDetails.packageName}}
        <div class="tier-name">{{clubBookingDetails.packageName}}</div>
        {{/if}}
        <div class="venue-line">{{clubBookingDetails.location}}</div>
      </div>

      <div class="meta-grid">
        <div class="meta-card">
          <div class="meta-label">Date</div>
          <div class="meta-value">{{clubBookingDetails.dateLabel}}</div>
        </div>
        <div class="meta-card">
          <div class="meta-label">Admitted</div>
          <div class="meta-value">{{clubBookingDetails.totalGuests}} guests</div>
        </div>
        <div class="meta-card full">
          <div class="meta-label">Time</div>
          <div class="meta-value">{{clubBookingDetails.timeLabel}}</div>
        </div>
      </div>

      <div class="guest-row">
        <div class="avatar">{{buyerInformation.initials}}</div>
        <div style="min-width:0;">
          <div class="guest-label">Guest</div>
          <div class="guest-name">{{buyerInformation.name}}</div>
        </div>
      </div>

      {{#if perks.length}}
      <div class="perks">
        {{#each perks}}
        <span class="perk-pill">{{this}}</span>
        {{/each}}
      </div>
      {{/if}}
    </div>

    <div class="tear"></div>

    <div class="stub">
      <div class="stub-top">
        <div class="stub-copy">
          <div class="stub-eyebrow">Table reservation</div>
          <div class="stub-title">{{clubBookingDetails.clubName}}</div>
          <div class="stub-sub">{{clubBookingDetails.packageName}} · {{clubBookingDetails.dateLabel}}</div>
        </div>
        {{#if qrCodeDataUri}}
        <div class="qr-panel">
          <div class="qr-frame">
            <img src="{{qrCodeDataUri}}" alt="Ticket QR" />
          </div>
          <div class="qr-caption">{{buyerInformation.orderId}}</div>
        </div>
        {{/if}}
      </div>

      <div class="receipt">
        <div class="receipt-row"><span>Gross price</span><span>{{paymentInformation.grossAmount}}</span></div>
        <div class="receipt-row"><span>Service fee</span><span>{{paymentInformation.serviceCharge}}</span></div>
        <div class="receipt-total">
          <div class="label">Total paid</div>
          <div class="amount">{{paymentInformation.totalAmount}}</div>
        </div>
      </div>

      <div class="fine-print">
        Non-transferable · Valid for listed guests only · Purchased {{buyerInformation.dateOfPurchase}}
        · ${companyInformation.legalName} · ${companyInformation.website}
      </div>
    </div>
  </div>
</body>
</html>
`;

export default clubTicketTemplate;
