/**
 * Idempotent demo accounts. Refuses to run unless every credential is in the environment.
 * Never writes a default password into the repo.
 *
 * Required:
 * DEMO_PASSWORD
 * DEMO_CUSTOMER_EMAIL
 * DEMO_MANAGER_EMAIL
 * DEMO_ADMIN_EMAIL
 */
import { PrismaClient, AccountRole } from '@prisma/client';
import { hash } from 'bcrypt';

const required = [
  'DEMO_PASSWORD',
  'DEMO_CUSTOMER_EMAIL',
  'DEMO_MANAGER_EMAIL',
  'DEMO_ADMIN_EMAIL',
] as const;

const missing = required.filter((key) => !process.env[key]);
if (missing.length > 0) {
  console.error(`Missing env: ${missing.join(', ')}`);
  process.exit(1);
}

const password = process.env.DEMO_PASSWORD as string;
const prisma = new PrismaClient();

async function upsertUser(email: string, name: string, role: AccountRole) {
  const passwordHash = await hash(password, 10);
  const user = await prisma.user.upsert({
    where: { email },
    create: {
      email,
      name,
      password: passwordHash,
      phoneNumber: `+100000${role.length}${email.length}`.slice(0, 16),
      accountRole: role,
      isVerified: true,
      profile: {
        create: {
          dateOfBirth: new Date('1995-01-01T00:00:00.000Z'),
          location: 'Demo City',
        },
      },
    },
    update: {
      name,
      password: passwordHash,
      accountRole: role,
      isVerified: true,
      accountStatus: 'ACTIVE',
    },
  });
  return user;
}

async function main() {
  const customer = await upsertUser(
    process.env.DEMO_CUSTOMER_EMAIL as string,
    'Demo Customer',
    AccountRole.USER
  );
  const manager = await upsertUser(
    process.env.DEMO_MANAGER_EMAIL as string,
    'Demo Club Manager',
    AccountRole.CLUB_OWNER
  );
  const admin = await upsertUser(
    process.env.DEMO_ADMIN_EMAIL as string,
    'Demo Admin',
    AccountRole.ADMIN
  );

  const club = await prisma.club.upsert({
    where: { id: '00000000-0000-4000-8000-0000000000c1' },
    create: {
      id: '00000000-0000-4000-8000-0000000000c1',
      userId: manager.id,
      name: 'Demo Night Club',
      thumbnail: 'https://example.com/demo-club.jpg',
      images: ['https://example.com/demo-club.jpg'],
      dressCode: 'Smart casual',
      lat: 41.8781,
      lng: -87.6298,
      location: 'Demo City',
    },
    update: { userId: manager.id, name: 'Demo Night Club' },
  });

  await prisma.clubPackage.upsert({
    where: { clubId_name: { clubId: club.id, name: 'Demo Table' } },
    create: {
      clubId: club.id,
      name: 'Demo Table',
      capacity: 6,
      price: 150,
      currency: 'USD',
      features: ['Bottle service'],
    },
    update: { price: 150, isActive: true },
  });

  const startAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  const endAt = new Date(startAt.getTime() + 5 * 60 * 60 * 1000);
  const event = await prisma.event.upsert({
    where: { id: '00000000-0000-4000-8000-0000000000e1' },
    create: {
      id: '00000000-0000-4000-8000-0000000000e1',
      userId: manager.id,
      clubId: club.id,
      eventName: 'Demo Night Event',
      thumbnail: 'https://example.com/demo-event.jpg',
      images: ['https://example.com/demo-event.jpg'],
      lat: 41.8781,
      lng: -87.6298,
      location: 'Demo City',
      startAt,
      endAt,
      dressCode: 'Smart casual',
      eventPrice: 25,
      currency: 'USD',
    },
    update: {
      userId: manager.id,
      eventName: 'Demo Night Event',
      startAt,
      endAt,
    },
  });

  const tiers = [
    { tierName: 'Demo Paid', price: 25, sortOrder: 1 },
    { tierName: 'Demo Free', price: 0, sortOrder: 2 },
  ];
  for (const tier of tiers) {
    const existing = await prisma.eventTicketTier.findFirst({
      where: { eventId: event.id, tierName: tier.tierName },
    });
    if (!existing) {
      await prisma.eventTicketTier.create({
        data: {
          eventId: event.id,
          tierName: tier.tierName,
          price: tier.price,
          capacity: 100,
          sortOrder: tier.sortOrder,
        },
      });
    }
  }

  const moduleName = 'Demo Table Extra';
  const existingModule = await prisma.eventModule.findFirst({
    where: { eventId: event.id, name: moduleName },
  });
  if (!existingModule) {
    await prisma.eventModule.create({
      data: {
        eventId: event.id,
        name: moduleName,
        maxGuests: 8,
        startingPrice: 200,
        currency: 'USD',
        quantity: 4,
        remaining: 4,
        includedExtras: ['Mixer'],
        optionalExtras: ['Extra bottle'],
      },
    });
  }

  console.log(
    JSON.stringify(
      {
        customer: customer.email,
        clubManager: manager.email,
        organizer:
          'No separate ORGANIZER role. Use the club manager account for events.',
        admin: admin.email,
        clubId: club.id,
        eventId: event.id,
      },
      null,
      2
    )
  );
}

main()
  .catch((error) => {
    console.error(error instanceof Error ? error.message : 'Seed failed');
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
