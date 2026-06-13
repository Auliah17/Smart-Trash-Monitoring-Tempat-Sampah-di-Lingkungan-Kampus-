import Pendaftaran from "../models/PendaftaranModel.js";
import Kegiatan from "../models/KegiatanModel.js";

// HUBUNGAN ANTAR MODEL (Agar query include di bawah tidak error/kosong)
Pendaftaran.belongsTo(Kegiatan, { foreignKey: "kegiatan_id", as: "kegiatan" });

export const getAllPeserta = async (req, res) => {
  try {
    const peserta = await Pendaftaran.findAll({
      // Mengambil data pendaftaran sekalian dengan nama kegiatannya
      include: [
        {
          model: Kegiatan,
          as: "kegiatan",
          attributes: ["nama"], // Hanya mengambil kolom nama kegiatan
        },
      ],
      order: [["tanggal_daftar", "DESC"]],
    });

    res.status(200).json({
      success: true,
      data: peserta,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

export const verifyPeserta = async (req, res) => {
  try {
    const { status } = req.body;

    const peserta = await Pendaftaran.findByPk(req.params.id);

    if (!peserta) {
      return res.status(404).json({
        success: false,
        message: "Peserta tidak ditemukan",
      });
    }

    await peserta.update({
      status,
    });

    res.status(200).json({
      success: true,
      message: `Peserta berhasil ${status}`,
      data: peserta,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

export const deletePeserta = async (req, res) => {
  try {
    const peserta = await Pendaftaran.findByPk(req.params.id);

    if (!peserta) {
      return res.status(404).json({
        success: false,
        message: "Peserta tidak ditemukan",
      });
    }

    await peserta.destroy();

    res.status(200).json({
      success: true,
      message: "Peserta berhasil dihapus",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};