const { DataTypes } = require("sequelize");
const { ROLES } = require("../constants/roles");

module.exports = (sequelize) =>
  sequelize.define(
    "Doctor",
    {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        field: "user_id",
        references: {
          model: "Users",
          key: "id"
        }
      },
      name: { type: DataTypes.STRING, allowNull: false },
      specialization: { type: DataTypes.STRING, allowNull: false },
      medical_certificate: { type: DataTypes.STRING, allowNull: false },
      approval_status: {
        type: DataTypes.ENUM("PENDING", "APPROVED", "REJECTED"),
        allowNull: false,
        defaultValue: "PENDING"
      },

      // Virtual attributes that delegate directly to the associated User model
      email: {
        type: DataTypes.VIRTUAL,
        get() {
          return this.user ? this.user.email : null;
        }
      },
      phone: {
        type: DataTypes.VIRTUAL,
        get() {
          return this.user ? this.user.phone : null;
        }
      },
      password: {
        type: DataTypes.VIRTUAL,
        get() {
          return this.user ? this.user.password : null;
        }
      },
      role: {
        type: DataTypes.VIRTUAL,
        get() {
          return this.user ? this.user.role : ROLES.DOCTOR;
        }
      },
      is_verified: {
        type: DataTypes.VIRTUAL,
        get() {
          return this.user ? this.user.is_verified : false;
        }
      },
      verification_status: {
        type: DataTypes.VIRTUAL,
        get() {
          return this.user ? this.user.verification_status : "pending";
        }
      }
    },
    { tableName: "Doctors", timestamps: false }
  );
