import { DataTypes } from "sequelize";
import db from "../config/db.js";

const Kegiatan = db.define(
  "kegiatans",
  {
    nama: {
      type: DataTypes.STRING,
      allowNull: false,
    },

    deskripsi: {
      type: DataTypes.TEXT,
    },

    kategori: {
      type: DataTypes.STRING,
    },

    tanggal: {
      type: DataTypes.DATEONLY,
    },

    lokasi: {
      type: DataTypes.STRING,
    },

    kuota: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 10,
    },

    terdaftar: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },

    status: {
      type: DataTypes.STRING,
      defaultValue: "pending",
    },

    poin: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },

    pengaju: {
      type: DataTypes.STRING,
    },

    nim_pengaju: {
      type: DataTypes.STRING,
    },
  },
  {
    tableName: "kegiatans",
    timestamps: false,
  }
);

export default Kegiatan;