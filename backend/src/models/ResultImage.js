const { DataTypes } = require("sequelize");

module.exports = (sequelize) =>
  sequelize.define(
    "ResultImage",
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      xray_id: { type: DataTypes.INTEGER, allowNull: false },
      diagnosis_output: { type: DataTypes.JSONB, allowNull: false },
      heatmap_path: { type: DataTypes.STRING, allowNull: true },
      bounding_boxes: { type: DataTypes.JSONB, allowNull: true },
      ai_report: { type: DataTypes.JSONB, allowNull: true }
    },
    { tableName: "Result_Images", timestamps: false }
  );
