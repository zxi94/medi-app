const { DataTypes } = require("sequelize");

module.exports = (sequelize) =>
  sequelize.define(
    "XrayImage",
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      patient_id: { type: DataTypes.INTEGER, allowNull: true },
      doctor_id: { type: DataTypes.INTEGER, allowNull: true },
      image_path: { type: DataTypes.STRING, allowNull: false },
      upload_date: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW }
    },
    { tableName: "Xray_Images", timestamps: false }
  );
