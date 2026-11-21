import { Job } from 'bullmq';
import { compile } from 'handlebars';
import { find as geoTzFind } from 'geo-tz';
import { IJobHandler } from '@/app/@types/queue.types';
import { ISendTicketPdfEmail } from '@/app/queues/email/email.types';
import ticketPdfConfirmationTemplate from '@/app/templates/ticketPdfConfirmation.template';
import mailTransporter from '@/app/configs/nodemailer.config';
import prisma from '@/app/configs/db.configs';
import {
  getObjectBufferFromS3,
  getPresignedUrlFromS3,
} from '@/app/utils/s3.utils';
import { mailOption } from '@/app/utils/system.utils';
import { companyInformation, QUEUE_JOBS } from '@/const';
import logger from '@/app/configs/logger.configs';

const formatDateLabel = (date: Date, timeZone: string) =>
  new Intl.DateTimeFormat('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    timeZone,
  }).format(date);

const formatTimeLabel = (date: Date, timeZone: string) =>
  new Intl.DateTimeFormat('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone,
  }).format(date);

const formatDayKey = (date: Date, timeZone: string) =>
  new Intl.DateTimeFormat('en-CA', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    timeZone,
  }).format(date);

const formatTimeRange = (start: Date, end: Date, timeZone: string) => {
  const startTime = formatTimeLabel(start, timeZone);
  const endTime = formatTimeLabel(end, timeZone);
  if (formatDayKey(start, timeZone) === formatDayKey(end, timeZone)) {
    return `${startTime} – ${endTime}`;
  }
  const endDay = new Intl.DateTimeFormat('en-US', {
    weekday: 'short',
    timeZone,
  }).format(end);
  return `${startTime} → ${endDay} ${endTime}`;
};

const formatToVenueTime = (date: Date, timeZone: string) =>
  new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone,
  }).format(date);

const formatMoney = (currency: string, amount: string | number) => {
  const code = currency.trim().toUpperCase();
  const value = typeof amount === 'number' ? String(amount) : amount;
  if (code === 'EUR') return `€${value}`;
  if (code === 'USD') return `$${value}`;
  return `${code} ${value}`;
};

const bookingRefFromOrderId = (orderId: string) =>
  `#BDN-${orderId.replace(/-/g, '').slice(0, 8).toUpperCase()}`;

const resolveVenueTimeZone = ({
  lat,
  lng,
}: {
  lat?: number | null;
  lng?: number | null;
}) => {
  if (lat == null || lng == null) return 'America/Chicago';
  const tzs = geoTzFind(lat, lng);
  return tzs?.[0] || 'America/Chicago';
};

const handler: IJobHandler<ISendTicketPdfEmail> = {
  name: QUEUE_JOBS.SEND_TICKET_PDF_EMAIL,
  handler: async (data: ISendTicketPdfEmail, job: Job) => {
    const { orderId, traceId } = data;

    try {
      const order = await prisma.order.findUnique({
        where: { id: orderId },
        include: {
          buyer: { select: { email: true, name: true } },
          ticketPdf: true,
          paymentTransaction: { select: { currency: true } },
          clubBooking: {
            include: {
              clubPackage: {
                include: { club: { select: { lat: true, lng: true } } },
              },
            },
          },
          eventPurchase: {
            include: {
              event: {
                select: {
                  lat: true,
                  lng: true,
                  dressCode: true,
                },
              },
            },
          },
          eventModulePurchase: {
            include: {
              event: {
                select: {
                  eventName: true,
                  location: true,
                  startAt: true,
                  endAt: true,
                  lat: true,
                  lng: true,
                  dressCode: true,
                },
              },
              module: { select: { includedExtras: true } },
            },
          },
        },
      });

      if (!order) {
        throw new Error(`[sendTicketPdfEmail] Order ${orderId} not found`);
      }
      if (order.status !== 'PAID') {
        throw new Error(`[sendTicketPdfEmail] Order ${orderId} is not PAID`);
      }
      if (!order.ticketPdf || order.ticketPdf.status !== 'GENERATED') {
        throw new Error(
          `[sendTicketPdfEmail] Ticket PDF not GENERATED for order ${orderId}`
        );
      }
      if (!order.ticketPdf.storageKey) {
        throw new Error(
          `[sendTicketPdfEmail] Ticket PDF storageKey missing for order ${orderId}`
        );
      }

      const buyerEmail = order.buyer.email;
      if (!buyerEmail) {
        throw new Error(
          `[sendTicketPdfEmail] Buyer email missing for order ${orderId}`
        );
      }

      let venueTimeZone = 'America/Chicago';
      let venueLabel = 'Venue';
      let venueName = 'Booking';
      let venueLocation = '';
      let whenLabel = '';
      let passLabel = 'Admission';
      let guestLabel = '1 Guest';
      let perks: string[] = [];
      let entryNotes = '';

      if (order.serviceType === 'CLUB' && order.clubBooking) {
        const cb = order.clubBooking;
        venueTimeZone = resolveVenueTimeZone({
          lat: cb.clubPackage?.club?.lat,
          lng: cb.clubPackage?.club?.lng,
        });
        venueLabel = 'Club';
        venueName = cb.clubName;
        venueLocation = cb.clubLocation;
        whenLabel = `${formatDateLabel(cb.startAt, venueTimeZone)} · ${formatTimeRange(cb.startAt, cb.endAt, venueTimeZone)}`;
        passLabel = cb.packageName;
        guestLabel = `${cb.guestCount} Guests max`;
        perks = cb.clubPackage?.features ?? [];
      } else if (order.serviceType === 'EVENT' && order.eventPurchase) {
        const ep = order.eventPurchase;
        venueTimeZone = resolveVenueTimeZone({
          lat: ep.event?.lat,
          lng: ep.event?.lng,
        });
        venueLabel = 'Event';
        venueName = ep.eventName;
        venueLocation = ep.eventLocation;
        whenLabel = `${formatDateLabel(ep.eventStartAt, venueTimeZone)} · ${formatTimeRange(ep.eventStartAt, ep.eventEndAt, venueTimeZone)}`;
        passLabel = 'General Admission';
        guestLabel = `${ep.personCount} Ticket${ep.personCount === 1 ? '' : 's'}`;
        entryNotes = ep.event?.dressCode
          ? `Dress code: ${ep.event.dressCode}`
          : '';
      } else if (order.serviceType === 'EVENT' && order.eventModulePurchase) {
        const emp = order.eventModulePurchase;
        const event = emp.event;
        venueTimeZone = resolveVenueTimeZone({
          lat: event?.lat,
          lng: event?.lng,
        });
        venueLabel = 'Event';
        venueName = event.eventName;
        venueLocation = event.location;
        whenLabel = `${formatDateLabel(event.startAt, venueTimeZone)} · ${formatTimeRange(event.startAt, event.endAt, venueTimeZone)}`;
        passLabel = emp.moduleName;
        guestLabel = `${emp.guestCount} Guests max`;
        perks = emp.module?.includedExtras ?? [];
        entryNotes = event?.dressCode ? `Dress code: ${event.dressCode}` : '';
      } else {
        throw new Error(
          `[sendTicketPdfEmail] Unknown booking type for order ${orderId}`
        );
      }

      const displayCurrency =
        order.paymentTransaction?.currency?.trim() || order.currency.trim();
      const amountPaid = formatMoney(
        displayCurrency,
        order.buyerTotal.toString()
      );
      const paidAt = formatToVenueTime(order.createdAt, venueTimeZone);
      const bookingRef = bookingRefFromOrderId(order.id);
      const downloadUrl = await getPresignedUrlFromS3({
        key: order.ticketPdf.storageKey,
        expiresIn: 604800,
      });
      const pdfBuffer = await getObjectBufferFromS3({
        key: order.ticketPdf.storageKey,
      });

      const html = compile(ticketPdfConfirmationTemplate)({
        buyerName: order.buyerName || order.buyer.name,
        buyerEmail,
        buyerPhone: order.buyerPhoneNumber,
        bookingRef,
        venueLabel,
        venueName,
        venueLocation,
        whenLabel,
        passLabel,
        guestLabel,
        amountPaid,
        paidAt,
        hasPerks: perks.length > 0,
        perks,
        entryNotes,
        downloadUrl,
      });

      await mailTransporter.sendMail(
        mailOption({
          to: buyerEmail,
          subject: `Booking Confirmed · ${venueName} · ${bookingRef}`,
          html,
          replyTo: companyInformation.email,
          attachments: [
            {
              filename: `ticket_${order.id}.pdf`,
              content: pdfBuffer,
              contentType: 'application/pdf',
            },
          ],
        })
      );

      logger.info(
        `[sendTicketPdfEmail] Sent ticket confirmation email to ${buyerEmail} for order ${orderId}`
      );
    } catch (error) {
      logger.error('[sendTicketPdfEmail] Failed to send ticket PDF email:', {
        data,
        jobId: job.id,
        error,
        traceId,
      });
      throw error;
    }
  },
};

export default handler;
