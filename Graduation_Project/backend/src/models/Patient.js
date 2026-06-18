const { DataTypes } = require("sequelize");
const { ROLES } = require("../constants/roles");

module.exports = (sequelize) =>
  sequelize.define(
    "Patient",
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
      gender: { type: DataTypes.STRING, allowNull: false },
      dob: { type: DataTypes.DATEONLY, allowNull: false },
      medical_history: { type: DataTypes.TEXT, allowNull: true },

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
          return this.user ? this.user.role : ROLES.PATIENT;
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
    { tableName: "Patients", timestamps: false }
  );
