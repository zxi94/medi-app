const bcrypt = require("bcrypt");
const { User } = require("../models");
const { ROLES } = require("../constants/roles");

async function bootstrap() {
  try {
    const adminEmail = "admin@dev.com";
    const adminPassword = "admin";

    const adminAccount = await User.findOne({ where: { email: adminEmail } });

    if (!adminAccount) {
      // eslint-disable-next-line no-console
      console.log(JSON.stringify({ success: true, message: "Seeding default admin account.", data: { email: adminEmail } }));
      const hashedPassword = await bcrypt.hash(adminPassword, 12);
      await User.create({
        email: adminEmail,
        password: hashedPassword,
        phone: null,
        role: ROLES.ADMIN,
        is_verified: true,
        verification_status: "approved"
      });
      // eslint-disable-next-line no-console
      console.log(JSON.stringify({ success: true, message: "Default admin account is ready.", data: { email: adminEmail, role: ROLES.ADMIN } }));
      return;
    }

    const passwordMatches = await bcrypt.compare(adminPassword, adminAccount.password);
    const needsUpdate =
      !passwordMatches ||
      adminAccount.role !== ROLES.ADMIN ||
      adminAccount.is_verified !== true ||
      adminAccount.verification_status !== "approved";

    if (needsUpdate) {
      const hashedPassword = passwordMatches ? adminAccount.password : await bcrypt.hash(adminPassword, 12);
      await adminAccount.update({
        password: hashedPassword,
        role: ROLES.ADMIN,
        is_verified: true,
        verification_status: "approved"
      });
    }

    // eslint-disable-next-line no-console
    console.log(JSON.stringify({ success: true, message: "Admin account verified. Ready.", data: { email: adminEmail, role: ROLES.ADMIN } }));
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(JSON.stringify({ success: false, message: "Admin bootstrapping failed.", data: { error: error.message } }));
  }
}

module.exports = bootstrap;
