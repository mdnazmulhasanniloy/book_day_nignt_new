import fs from 'fs';
import path from 'path';
import os from 'os';
import QRCode from 'qrcode';
import Handlebars from 'handlebars';
import clubTicketTemplate from '@/app/templates/clubTicket.template';
import eventTicketTemplate from '@/app/templates/eventTicket.template';
import { renderHtmlToPdf } from '@/app/utils/pdf.utils';

import prisma from '@/app/configs/db.configs';
import logger from '@/app/configs/logger.configs';
import { QUEUE_JOBS } from '@/const';
import { IJobHandler } from '@/app/@types/queue.types';
import { singleUploadToS3 } from '@/app/utils/s3.utils';
import { getNotificationQueue } from '@/app/queues/notification/notification.queue';
import { getEmailQueue } from '@/app/queues/email/email.queue';
import { find as geoTzFind } from 'geo-tz';

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

/** Overnight-safe range, e.g. "7:00 PM → Tue 5:00 AM" */
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

const initialsFromName = (name: string) => {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'BD';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
};

/** Display money with a clear currency mark (EUR → €). */
const formatMoney = (currency: string, amount: string | number) => {
  const code = currency.trim().toUpperCase();
  const value = typeof amount === 'number' ? String(amount) : amount;
  if (code === 'EUR') return `€${value}`;
  if (code === 'USD') return `$${value}`;
  return `${code} ${value}`;
};

const handler: IJobHandler = {
  name: QUEUE_JOBS.GENERATE_TICKET_PDF,
  handler: async (data: any) => {
    const { orderId, force = false } = data;

    // 1. Idempotency Check
    // WHY: Check TicketPdf to prevent duplicate generation. If webhooks are delivered twice or BullMQ retries,
    // this ensures we don't accidentally create multiple successful PDF records for the same Order.
    // force=true is reserved for intentional redesign regenerations.
    let ticketPdf = await prisma.ticketPdf.findUnique({
      where: { orderId },
    });

    if (ticketPdf && ticketPdf.status === 'GENERATED' && !force) {
      logger.info(
        `[generateTicketPdf] Ticket PDF already generated for order ${orderId}`
      );
      return;
    }

    if (!ticketPdf) {
      throw new Error(
        `[generateTicketPdf] TicketPdf record unexpectedly missing for order ${orderId}. Ensure payment transaction correctly persisted the PENDING state.`
      );
    }

    if (force && ticketPdf.status === 'GENERATED') {
      ticketPdf = await prisma.ticketPdf.update({
        where: { id: ticketPdf.id },
        data: { status: 'PENDING' },
      });
    }

    let tempFilePath = '';

    try {
      // 2. Load CURRENT database state
      // WHY: Webhook payloads can be stale. We must load the committed database state
      // (Order, ClubBooking, EventPurchase) to guarantee accurate PDF fulfillment data.
      const order = await prisma.order.findUnique({
        where: { id: orderId },
        include: {
          buyer: true,
          paymentTransaction: {
            select: { currency: true },
          },
          clubBooking: {
            include: {
              clubPackage: {
                include: { club: true },
              },
            },
          },
          eventPurchase: {
            include: {
              event: true,
              attendees: true,
            },
          },
          eventModulePurchase: {
            include: {
              event: true,
              module: true,
            },
          },
        },
      });

      if (!order) {
        throw new Error(`Order ${orderId} not found`);
      }

      // WHY: We strictly only generate PDFs for orders that have successfully reached PAID status.
      if (order.status !== 'PAID') {
        throw new Error(`Order ${orderId} is not PAID`);
      }

      let venueTimeZone = 'America/Chicago'; // fallback

      if (order.serviceType === 'CLUB' && order.clubBooking) {
        const club = order.clubBooking.clubPackage?.club;
        if (club && club.lat !== undefined && club.lng !== undefined) {
          const tzs = geoTzFind(club.lat, club.lng);
          if (tzs && tzs.length > 0) venueTimeZone = tzs[0];
        }
      } else if (order.serviceType === 'EVENT' && order.eventPurchase) {
        const event = order.eventPurchase.event;
        if (event && event.lat !== undefined && event.lng !== undefined) {
          const tzs = geoTzFind(event.lat, event.lng);
          if (tzs && tzs.length > 0) venueTimeZone = tzs[0];
        }
      } else if (order.serviceType === 'EVENT' && order.eventModulePurchase) {
        const event = order.eventModulePurchase.event;
        if (event && event.lat !== undefined && event.lng !== undefined) {
          const tzs = geoTzFind(event.lat, event.lng);
          if (tzs && tzs.length > 0) venueTimeZone = tzs[0];
        }
      }

      // 3. Generate PDF
      const buyerInformation = {
        name: order.buyer.name,
        email: order.buyer.email,
        orderId: order.id,
        initials: initialsFromName(order.buyer.name),
        dateOfPurchase: formatToVenueTime(order.createdAt, venueTimeZone),
      };
      // Prefer PaymentTransaction currency (actual Stripe charge) over Order
      // snapshot — legacy orders could show USD while Stripe charged EUR.
      const displayCurrency =
        order.paymentTransaction?.currency?.trim() ||
        order.currency.trim();
      const paymentInformation = {
        currency: displayCurrency.toUpperCase(),
        grossAmount: formatMoney(displayCurrency, order.grossAmount.toString()),
        serviceCharge: formatMoney(
          displayCurrency,
          order.serviceChargeAmount.toString()
        ),
        totalAmount: formatMoney(displayCurrency, order.buyerTotal.toString()),
      };

      const qrCodeDataUri = await QRCode.toDataURL(order.id, {
        margin: 1,
        width: 512,
        errorCorrectionLevel: 'M',
        color: {
          dark: '#141414',
          light: '#ffffff',
        },
      });

      let renderedHtml = '';

      if (order.serviceType === 'CLUB' && order.clubBooking) {
        const cb = order.clubBooking;
        const template = Handlebars.compile(clubTicketTemplate);
        const perks = cb.clubPackage?.features ?? [];
        renderedHtml = template({
          passBadge: 'TABLE PASS',
          buyerInformation,
          clubBookingDetails: {
            clubName: cb.clubName,
            location: cb.clubLocation,
            packageName: cb.packageName,
            dateLabel: formatDateLabel(cb.startAt, venueTimeZone),
            timeLabel: formatTimeRange(cb.startAt, cb.endAt, venueTimeZone),
            totalGuests: cb.guestCount,
          },
          perks,
          paymentInformation,
          qrCodeDataUri,
        });
      } else if (order.serviceType === 'EVENT' && order.eventPurchase) {
        const ep = order.eventPurchase;
        const template = Handlebars.compile(eventTicketTemplate);

        let attendees: { index: number; name: string }[] = [];
        if (ep.attendees && ep.attendees.length > 0) {
          attendees = ep.attendees.map((att, idx) => ({
            index: idx + 1,
            name: att.name,
          }));
        }

        renderedHtml = template({
          passBadge: 'GENERAL ADMISSION',
          buyerInformation,
          eventTicketDetails: {
            eventName: ep.eventName,
            tierName: 'General Admission',
            location: ep.eventLocation,
            dateLabel: formatDateLabel(ep.eventStartAt, venueTimeZone),
            timeLabel: formatTimeRange(
              ep.eventStartAt,
              ep.eventEndAt,
              venueTimeZone
            ),
            totalPersons: ep.personCount,
          },
          attendees,
          perks: [],
          paymentInformation,
          qrCodeDataUri,
        });
      } else if (order.serviceType === 'EVENT' && order.eventModulePurchase) {
        const emp = order.eventModulePurchase;
        const event = emp.event;
        const template = Handlebars.compile(eventTicketTemplate);
        const perks = emp.module?.includedExtras ?? [];

        renderedHtml = template({
          passBadge: 'VIP PASS',
          buyerInformation,
          eventTicketDetails: {
            eventName: event.eventName,
            tierName: emp.moduleName,
            location: event.location,
            dateLabel: formatDateLabel(event.startAt, venueTimeZone),
            timeLabel: formatTimeRange(event.startAt, event.endAt, venueTimeZone),
            totalPersons: emp.guestCount,
          },
          attendees: [{ index: 1, name: order.buyer.name }],
          perks,
          paymentInformation,
          qrCodeDataUri,
        });
      } else {
        throw new Error(
          `Unknown service type or missing booking details for order ${orderId}`
        );
      }

      tempFilePath = path.join(os.tmpdir(), `ticket_${orderId}.pdf`);

      const pdfBytes = await renderHtmlToPdf(renderedHtml);
      await fs.promises.writeFile(tempFilePath, pdfBytes);

      // 4. Upload to S3
      // WHY: The repository's canonical object-key representation is used to persist the exact storage identifier.
      // S3 will overwrite the same key cleanly if BullMQ retries an upload.
      const key = `tickets/${orderId}.pdf`;
      await singleUploadToS3({
        filePath: tempFilePath,
        key,
        mimeType: 'application/pdf',
        acl: 'private',
      });

      // 5. Update DB strictly AFTER successful upload
      // WHY: Never mark GENERATED or store the storageKey if the file hasn't been durably stored.
      // If DB fails here, BullMQ retries and safely overwrites S3 because we haven't lost state (DB is still PENDING/FAILED).
      await prisma.ticketPdf.update({
        where: { id: ticketPdf.id },
        data: {
          status: 'GENERATED',
          storageKey: key, // Canonical key, not the public URL
          generatedAt: new Date(),
        },
      });

      logger.info(
        `[generateTicketPdf] Ticket PDF generated and uploaded successfully for order ${orderId}`
      );

      // Skip push/email on intentional redesign regenerations to avoid duplicate noise.
      if (!force) {
        try {
          const bookingId =
            order.clubBooking?.id ??
            order.eventPurchase?.id ??
            order.eventModulePurchase?.id ??
            null;
          await getNotificationQueue().add(
            QUEUE_JOBS.SEND_FCM_NOTIFICATION,
            {
              userIds: [order.buyerUserId],
              notificationType: 'TICKET_AVAILABLE',
              title: 'Ticket Available!',
              description: `Your ticket is now available to download and view.`,
              metaData: {
                bookingId,
                orderId: order.id,
                serviceType: order.serviceType,
              },
            },
            {
              removeOnComplete: true,
              removeOnFail: false,
            }
          );
        } catch (pushErr) {
          logger.error(
            `[generateTicketPdf] Failed to enqueue TICKET_AVAILABLE push notification`,
            pushErr
          );
        }

        try {
          await getEmailQueue().add(
            QUEUE_JOBS.SEND_TICKET_PDF_EMAIL,
            {
              orderId: order.id,
              traceId: `ticket-email-${order.id}`,
            },
            {
              jobId: `ticket-email-${order.id}`,
              removeOnComplete: true,
              removeOnFail: false,
            }
          );
        } catch (emailErr) {
          logger.error(
            `[generateTicketPdf] Failed to enqueue SEND_TICKET_PDF_EMAIL`,
            emailErr
          );
        }
      }
    } catch (error) {
      logger.error(
        `[generateTicketPdf] Failed to generate Ticket PDF for order ${orderId}`,
        error
      );

      await prisma.ticketPdf.update({
        where: { id: ticketPdf.id },
        data: { status: 'FAILED' },
      });

      // WHY: Rethrow to propagate to the existing worker failure/retry mechanism.
      throw error;
    } finally {
      // 6. Temporary file cleanup
      // WHY: The temporary local PDF file must always be removed in finally to avoid disk leaks.
      if (tempFilePath && fs.existsSync(tempFilePath)) {
        try {
          fs.unlinkSync(tempFilePath);
        } catch (cleanupError) {
          logger.error(
            `[generateTicketPdf] Failed to delete temporary file ${tempFilePath}`,
            cleanupError
          );
        }
      }
    }
  },
};

export default handler;
