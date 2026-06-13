import { DataTypes } from "sequelize";
import db from "../config/db.js";

const User = db.define(
  "users",
  {
    name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    nim: {
      type: DataTypes.STRING,
      allowNull: true,
      unique: true,
    },
    prodi: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    no_whatsapp: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
    },
    password: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    role: {
      type: DataTypes.STRING,
      defaultValue: "mahasiswa",
    },
  },
  {
    tableName: "users",
    timestamps: false,
  }
);

export default User;