import { VipHost } from '@prisma/client';

export const mapVipHost = (host: VipHost) => ({
  id: host.id,
  name: host.name,
  role: host.role,
  isVerified: host.isVerified,
  photo: host.photo,
  whatsapp: host.whatsapp,
  phone: host.phone,
  email: host.email,
  bio: host.bio,
  officialPricesNote: host.officialPricesNote,
  isActive: host.isActive,
});

export const mapPublicVipHost = (host: VipHost) => ({
  id: host.id,
  name: host.name,
  role: host.role,
  isVerified: host.isVerified,
  photo: host.photo,
  whatsapp: host.whatsapp,
  phone: host.phone,
  email: host.email,
  bio: host.bio,
  officialPricesNote: host.officialPricesNote,
});

/** Slim shape for owner event-host assignment lists. */
export const mapAssignedEventHost = (host: VipHost) => ({
  id: host.id,
  name: host.name,
  role: host.role,
  email: host.email,
  phone: host.phone,
});
