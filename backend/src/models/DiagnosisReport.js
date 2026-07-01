const { DataTypes } = require("sequelize");

module.exports = (sequelize) =>
  sequelize.define(
    "DiagnosisReport",
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      patient_id: { type: DataTypes.INTEGER, allowNull: false },
      doctor_id: { type: DataTypes.INTEGER, allowNull: false },
      result_id: { type: DataTypes.INTEGER, allowNull: false },
      doctor_notes: { type: DataTypes.TEXT, allowNull: true },
      final_conclusion: { type: DataTypes.TEXT, allowNull: true },
      created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW }
    },
    { tableName: "Diagnosis_Reports", timestamps: false }
  );
