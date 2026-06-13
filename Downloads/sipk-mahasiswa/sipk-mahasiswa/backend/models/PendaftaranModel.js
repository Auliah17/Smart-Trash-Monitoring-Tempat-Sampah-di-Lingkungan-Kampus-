import { DataTypes } from "sequelize";
import db from "../config/db.js";

const Pendaftaran = db.define(
  "peserta",
  {
    nama: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    nim: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    prodi: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    no_whatsapp: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    kegiatan_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    status: {
      type: DataTypes.STRING,
      defaultValue: "pending",
    },
    tanggal_daftar: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: "peserta",
    timestamps: false,
  }
);

export default Pendaftaran;