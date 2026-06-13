import Kegiatan from "../models/KegiatanModel.js";

// Ambil semua data kegiatan yang sudah disetujui admin
export const getKegiatan = async (req, res) => {
  try {
    const kegiatan = await Kegiatan.findAll({
      where: {
        status: "disetujui",
      },
    });

    res.status(200).json(kegiatan);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Ambil satu kegiatan berdasarkan id
export const getKegiatanById = async (req, res) => {
  try {
    const kegiatan = await Kegiatan.findOne({
      where: {
        id: req.params.id,
        status: "disetujui",
      },
    });

    if (!kegiatan) {
      return res.status(404).json({
        message: "Kegiatan tidak ditemukan atau belum disetujui",
      });
    }

    res.status(200).json(kegiatan);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Mahasiswa mengajukan kegiatan
export const createPengajuanKegiatan = async (req, res) => {
  try {
    const {
      nama,
      kategori,
      tanggal,
      lokasi,
      kuota,
    } = req.body;

    if (
      !nama ||
      !kategori ||
      !tanggal ||
      !lokasi ||
      !kuota
    ) {
      return res.status(400).json({
        message: "Semua field wajib diisi",
      });
    }

    const kegiatan = await Kegiatan.create({
      nama,
      kategori,
      tanggal,
      lokasi,
      kuota,

      status: "pending",

      pengaju: req.user.name,
      nim_pengaju: req.user.nim,

      terdaftar: 0,
      poin: 0,
      deskripsi: "",
    });

    res.status(201).json({
      message: "Pengajuan kegiatan berhasil dikirim",
      data: kegiatan,
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};