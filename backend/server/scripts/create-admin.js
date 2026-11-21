const path = require('path');
const readline = require('readline');

require('dotenv').config({
  path: path.join(__dirname, '..', '..', '.env'),
});

// Prefer the repo-root Prisma Client (host OS binaries) over server/node_modules
// which is often generated for the Linux Docker image.
const rootPrismaClient = path.join(
  __dirname,
  '..',
  '..',
  'node_modules',
  '@prisma',
  'client'
);
const { PrismaClient } = require(
  require('fs').existsSync(rootPrismaClient)
    ? rootPrismaClient
    : '@prisma/client'
);
const bcrypt = require(
  require('fs').existsSync(path.join(__dirname, '..', 'node_modules', 'bcrypt'))
    ? path.join(__dirname, '..', 'node_modules', 'bcrypt')
    : 'bcrypt'
);

const prisma = new PrismaClient();

const parseArgs = (argv) => {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;

    if (token.includes('=')) {
      const eq = token.indexOf('=');
      args[token.slice(2, eq)] = token.slice(eq + 1);
      continue;
    }

    const key = token.slice(2);
    const parts = [];
    while (argv[i + 1] && !argv[i + 1].startsWith('--')) {
      parts.push(argv[i + 1]);
      i += 1;
    }
    args[key] = parts.length > 0 ? parts.join(' ') : true;
  }
  return args;
};

const isValidEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const createAdminRecord = async ({ name, email, password }) => {
  const hashedPassword = await bcrypt.hash(password, 10);

  return prisma.$transaction(async (tx) => {
    const user = await tx.user.create({
      data: {
        name,
        email,
        password: hashedPassword,
        phoneNumber: '',
        isVerified: true,
        accountStatus: 'ACTIVE',
        accountRole: 'ADMIN',
      },
    });

    const profile = await tx.profile.create({
      data: {
        userId: user.id,
      },
    });

    return { user, profile };
  });
};

const createAdminNonInteractive = async ({ name, email, password }) => {
  try {
    await prisma.$connect();
    console.log('✓ Connected to PostgreSQL\n');
    console.log('Creating Admin User (non-interactive)');
    console.log('-------------------\n');

    if (!name || name.length < 4) {
      throw new Error('Name must be at least 4 characters long');
    }
    if (!email || !isValidEmail(email)) {
      throw new Error('Please provide a valid email address');
    }
    if (!password || password.length < 8) {
      throw new Error('Password must be at least 8 characters long');
    }

    const existingUser = await prisma.user.findUnique({ where: { email } });
    let userId;

    if (existingUser) {
      if (existingUser.accountRole !== 'ADMIN') {
        throw new Error('A non-admin user with this email already exists');
      }

      const hashedPassword = await bcrypt.hash(password, 10);
      const updated = await prisma.user.update({
        where: { email },
        data: {
          name,
          password: hashedPassword,
          isVerified: true,
          accountStatus: 'ACTIVE',
        },
      });
      userId = updated.id;
      console.log('\n✓ Existing admin updated successfully!');
    } else {
      const result = await createAdminRecord({ name, email, password });
      userId = result.user.id;
      console.log('\n✓ Admin user created successfully!');
    }

    console.log(`Email:    ${email}`);
    console.log(`Name:     ${name}`);
    console.log(`Role:     ADMIN`);
    console.log(`Verified: Yes`);
    console.log(`ID:       ${userId}`);

    await prisma.$disconnect();
    process.exit(0);
  } catch (error) {
    console.error('\n✗ Error creating admin:', error.message);
    await prisma.$disconnect();
    process.exit(1);
  }
};

const createAdminInteractive = async () => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const question = (query) => {
    return new Promise((resolve) => {
      rl.question(query, resolve);
    });
  };

  const questionPassword = (query) => {
    return new Promise((resolve) => {
      const stdin = process.stdin;
      const stdout = process.stdout;

      stdout.write(query);

      stdin.setRawMode(true);
      stdin.resume();
      stdin.setEncoding('utf8');

      let password = '';

      const onData = (char) => {
        char = char.toString('utf8');

        switch (char) {
          case '\n':
          case '\r':
          case '\u0004':
            stdin.setRawMode(false);
            stdin.pause();
            stdin.removeListener('data', onData);
            stdout.write('\n');
            resolve(password);
            break;
          case '\u0003':
            process.exit();
            break;
          case '\u007f':
          case '\b':
            if (password.length > 0) {
              password = password.slice(0, -1);
              stdout.clearLine(0);
              stdout.cursorTo(0);
              stdout.write(query + '*'.repeat(password.length));
            }
            break;
          default:
            password += char;
            stdout.write('*');
            break;
        }
      };

      stdin.on('data', onData);
    });
  };

  try {
    await prisma.$connect();
    console.log('✓ Connected to PostgreSQL\n');
    console.log('Creating Admin User');
    console.log('-------------------\n');

    let name = '';
    while (!name || name.length < 4) {
      name = await question('Name: ');
      if (!name) {
        console.log('⚠ Name cannot be empty!');
      } else if (name.length < 4) {
        console.log('⚠ Name must be at least 4 characters long!');
        name = '';
      }
    }

    let email = '';
    while (!email || !isValidEmail(email)) {
      email = await question('Email: ');
      if (!email) {
        console.log('⚠ Email cannot be empty!');
      } else if (!isValidEmail(email)) {
        console.log('⚠ Please enter a valid email address!');
        email = '';
      } else {
        const existingUser = await prisma.user.findUnique({ where: { email } });
        if (existingUser) {
          console.log('⚠ A user with this email already exists!');
          email = '';
        }
      }
    }

    let password = '';
    let confirmPassword = '';
    while (!password || password !== confirmPassword || password.length < 8) {
      password = await questionPassword('Password: ');
      if (!password) {
        console.log('⚠ Password cannot be empty!');
        continue;
      }
      if (password.length < 8) {
        console.log('⚠ Password must be at least 8 characters long!');
        password = '';
        continue;
      }
      confirmPassword = await questionPassword('Confirm Password: ');
      if (password !== confirmPassword) {
        console.log('⚠ Passwords do not match!');
        password = '';
        confirmPassword = '';
      }
    }

    const result = await createAdminRecord({ name, email, password });

    console.log('\n✓ Admin user created successfully!');
    console.log(`Email:    ${email}`);
    console.log(`Name:     ${name}`);
    console.log(`Role:     ADMIN`);
    console.log(`Verified: Yes`);
    console.log(`ID:       ${result.user.id}`);

    rl.close();
    await prisma.$disconnect();
    process.exit(0);
  } catch (error) {
    console.error('\n✗ Error creating admin:', error.message);
    rl.close();
    await prisma.$disconnect();
    process.exit(1);
  }
};

const args = parseArgs(process.argv.slice(2));
if (args.name || args.email || args.password) {
  createAdminNonInteractive({
    name: args.name,
    email: args.email,
    password: args.password,
  });
} else {
  createAdminInteractive();
}
