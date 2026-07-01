const { DataTypes } = require("sequelize");

module.exports = (sequelize) =>
  sequelize.define(
    "ChatMessage",
    {
      id: {
        type: DataTypes.INTEGER,
        autoIncrement: true,
        primaryKey: true
      },
      thread_id: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: {
          model: "Chat_Threads",
          key: "id"
        }
      },
      sender_user_id: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: {
          model: "Users",
          key: "id"
        }
      },
      body: {
        type: DataTypes.TEXT,
        allowNull: false
      },
      created_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW
      },
      read_at: {
        type: DataTypes.DATE,
        allowNull: true
      }
    },
    {
      tableName: "Chat_Messages",
      timestamps: true,
      createdAt: "created_at",
      updatedAt: false
    }
  );
