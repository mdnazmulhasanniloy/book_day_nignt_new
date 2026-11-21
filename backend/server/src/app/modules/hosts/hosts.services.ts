import prisma from '@/app/configs/db.configs';
import {
  mapAssignedEventHost,
  mapPublicVipHost,
  mapVipHost,
} from '@/app/modules/hosts/hosts.helpers';
import { sendPushNotification } from '@/app/modules/notification/notification.helpers';
import {
  IAttachHostToClubService,
  IAttachHostToEventService,
  IContactHostService,
  ICreateHostService,
  IDeleteHostService,
  IListEventHostInquiriesService,
  IListEventHostsService,
  IListHostsService,
  IUnassignHostFromEventService,
  IUpdateHostService,
} from '@/app/modules/hosts/hosts.types';
import { getEmailQueue } from '@/app/queues/email/email.queue';
import { QUEUE_JOBS } from '@/const';

const assertOwnedHost = async ({
  hostId,
  ownerUserId,
}: {
  hostId: string;
  ownerUserId: string;
}) => {
  const host = await prisma.vipHost.findUnique({ where: { id: hostId } });
  if (!host) {
    throw { statusCode: 404, message: 'Host not found' };
  }
  if (host.ownerUserId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this host' };
  }
  return host;
};

export const createHostService = async ({
  ownerUserId,
  payload,
}: ICreateHostService) => {
  const host = await prisma.vipHost.create({
    data: {
      ownerUserId,
      name: payload.name,
      role: payload.role,
      isVerified: payload.isVerified,
      photo: payload.photo ?? null,
      whatsapp: payload.whatsapp ?? null,
      phone: payload.phone ?? null,
      email: payload.email ?? null,
      bio: payload.bio ?? null,
      officialPricesNote: payload.officialPricesNote ?? null,
      isActive: payload.isActive,
    },
  });

  return mapVipHost(host);
};

export const listHostsService = async ({ ownerUserId }: IListHostsService) => {
  const hosts = await prisma.vipHost.findMany({
    where: { ownerUserId },
    orderBy: { createdAt: 'desc' },
  });

  return hosts.map(mapVipHost);
};

export const updateHostService = async ({
  ownerUserId,
  hostId,
  payload,
}: IUpdateHostService) => {
  await assertOwnedHost({ hostId, ownerUserId });

  const host = await prisma.vipHost.update({
    where: { id: hostId },
    data: {
      ...(payload.name !== undefined ? { name: payload.name } : {}),
      ...(payload.role !== undefined ? { role: payload.role } : {}),
      ...(payload.isVerified !== undefined
        ? { isVerified: payload.isVerified }
        : {}),
      ...(payload.photo !== undefined ? { photo: payload.photo } : {}),
      ...(payload.whatsapp !== undefined ? { whatsapp: payload.whatsapp } : {}),
      ...(payload.phone !== undefined ? { phone: payload.phone } : {}),
      ...(payload.email !== undefined ? { email: payload.email } : {}),
      ...(payload.bio !== undefined ? { bio: payload.bio } : {}),
      ...(payload.officialPricesNote !== undefined
        ? { officialPricesNote: payload.officialPricesNote }
        : {}),
      ...(payload.isActive !== undefined ? { isActive: payload.isActive } : {}),
    },
  });

  return mapVipHost(host);
};

export const deleteHostService = async ({
  ownerUserId,
  hostId,
}: IDeleteHostService) => {
  await assertOwnedHost({ hostId, ownerUserId });
  await prisma.vipHost.delete({ where: { id: hostId } });
  return { message: 'Host deleted successfully' };
};

export const attachHostToEventService = async ({
  ownerUserId,
  eventId,
  payload,
}: IAttachHostToEventService) => {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: { id: true, userId: true, deactivatedAt: true },
  });

  if (!event || event.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Event not found' };
  }
  if (event.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this event' };
  }

  const host = await assertOwnedHost({
    hostId: payload.hostId,
    ownerUserId,
  });

  if (!host.isActive) {
    throw { statusCode: 409, message: 'Host is inactive' };
  }

  const existing = await prisma.eventVipHost.findUnique({
    where: {
      eventId_hostId: { eventId, hostId: payload.hostId },
    },
  });

  if (existing) {
    return mapPublicVipHost(host);
  }

  await prisma.eventVipHost.create({
    data: { eventId, hostId: payload.hostId },
  });

  return mapPublicVipHost(host);
};

export const listEventHostsService = async ({
  ownerUserId,
  eventId,
}: IListEventHostsService) => {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: { id: true, userId: true, deactivatedAt: true },
  });

  if (!event || event.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Event not found' };
  }
  if (event.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this event' };
  }

  const links = await prisma.eventVipHost.findMany({
    where: { eventId },
    include: { host: true },
    orderBy: { createdAt: 'asc' },
  });

  return links.map((link) => mapAssignedEventHost(link.host));
};

export const unassignHostFromEventService = async ({
  ownerUserId,
  eventId,
  hostId,
}: IUnassignHostFromEventService) => {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: { id: true, userId: true, deactivatedAt: true },
  });

  if (!event || event.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Event not found' };
  }
  if (event.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this event' };
  }

  const link = await prisma.eventVipHost.findUnique({
    where: {
      eventId_hostId: { eventId, hostId },
    },
  });

  if (!link) {
    throw { statusCode: 404, message: 'Host is not assigned to this event' };
  }

  await prisma.eventVipHost.delete({
    where: { id: link.id },
  });

  return { message: 'Host unassigned from event successfully' };
};

export const attachHostToClubService = async ({
  ownerUserId,
  clubId,
  payload,
}: IAttachHostToClubService) => {
  const club = await prisma.club.findUnique({
    where: { id: clubId },
    select: { id: true, userId: true, deactivatedAt: true },
  });

  if (!club || club.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Club not found' };
  }
  if (club.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this club' };
  }

  const host = await assertOwnedHost({
    hostId: payload.hostId,
    ownerUserId,
  });

  if (!host.isActive) {
    throw { statusCode: 409, message: 'Host is inactive' };
  }

  const existing = await prisma.clubVipHost.findUnique({
    where: {
      clubId_hostId: { clubId, hostId: payload.hostId },
    },
  });

  if (existing) {
    return mapPublicVipHost(host);
  }

  await prisma.clubVipHost.create({
    data: { clubId, hostId: payload.hostId },
  });

  return mapPublicVipHost(host);
};

export const contactHostService = async ({
  hostId,
  payload,
  traceId,
}: IContactHostService) => {
  const host = await prisma.vipHost.findUnique({ where: { id: hostId } });

  if (!host || !host.isActive) {
    throw { statusCode: 404, message: 'Host not found' };
  }

  let eventId: string | null = null;
  let ownerUserId = host.ownerUserId;

  if (payload.eventId) {
    const event = await prisma.event.findUnique({
      where: { id: payload.eventId },
      select: { id: true, userId: true, deactivatedAt: true },
    });

    if (!event || event.deactivatedAt !== null) {
      throw { statusCode: 404, message: 'Event not found' };
    }

    const linked = await prisma.eventVipHost.findUnique({
      where: {
        eventId_hostId: { eventId: payload.eventId, hostId },
      },
      select: { id: true },
    });

    if (!linked) {
      throw {
        statusCode: 422,
        message: 'Host is not assigned to this event',
      };
    }

    eventId = event.id;
    ownerUserId = event.userId;
  }

  const contact = await prisma.hostContact.create({
    data: {
      hostId,
      eventId,
      name: payload.name,
      email: payload.email,
      phone: payload.phone,
      message: payload.message,
    },
  });

  const truncatedMessage =
    payload.message.length > 120
      ? `${payload.message.slice(0, 117)}...`
      : payload.message;

  // Owner only: customers get email confirmation, not in-app/push.
  await sendPushNotification({
    userIds: [ownerUserId],
    notificationType: 'HOST_INQUIRY',
    title: 'New VIP Host Inquiry 💬',
    description: `${payload.name} sent a VIP inquiry to host ${host.name}: '${truncatedMessage}'. Phone: ${payload.phone}`,
    metaData: {
      hostId: host.id,
      eventId,
      inquiryId: contact.id,
      customerPhone: payload.phone,
      customerEmail: payload.email,
    },
  });

  // Always enqueue: customer confirmation email; host email when registered.
  const emailQueue = getEmailQueue();
  await emailQueue.add(
    QUEUE_JOBS.SEND_HOST_CONTACT_EMAIL,
    {
      contactId: contact.id,
      hostName: host.name,
      hostEmail: host.email,
      clientName: payload.name,
      clientEmail: payload.email,
      clientPhone: payload.phone,
      message: payload.message,
      traceId: traceId ?? `host-contact-${contact.id}`,
    },
    {
      jobId: `send-host-contact-email-${contact.id}`,
      removeOnComplete: true,
      removeOnFail: false,
    }
  );

  return {
    id: contact.id,
    hostId: host.id,
    eventId,
    whatsapp: host.whatsapp,
  };
};

export const listEventHostInquiriesService = async ({
  ownerUserId,
  eventId,
}: IListEventHostInquiriesService) => {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: { id: true, userId: true, deactivatedAt: true },
  });

  if (!event || event.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Event not found' };
  }
  if (event.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this event' };
  }

  const rows = await prisma.hostContact.findMany({
    where: { eventId },
    include: {
      host: { select: { id: true, name: true } },
    },
    orderBy: { createdAt: 'desc' },
  });

  return rows.map((row) => ({
    id: row.id,
    hostId: row.hostId,
    hostName: row.host.name,
    customerName: row.name,
    customerEmail: row.email,
    customerPhone: row.phone,
    message: row.message,
    createdAt: row.createdAt,
  }));
};
