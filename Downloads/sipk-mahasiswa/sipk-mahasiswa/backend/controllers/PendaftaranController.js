import Pendaftaran from "../models/PendaftaranModel.js";
import Kegiatan from "../models/KegiatanModel.js";

// Tambah data pendaftaran mahasiswa
export const createPendaftaran = async (req, res) => {
  try {
    const { nama, nim, prodi, email, no_whatsapp, kegiatan_id } = req.body;

    if (!nama || !nim || !prodi || !email || !no_whatsapp || !kegiatan_id) {
      return res.status(400).json({
        message: "Semua field pendaftaran wajib diisi",
      });
    }

    const dataKegiatan = await Kegiatan.findOne({
      where: {
        id: kegiatan_id,
      },
    });

    if (!dataKegiatan) {
      return res.status(404).json({
        message: "Kegiatan tidak ditemukan",
      });
    }

    if (dataKegiatan.status !== "disetujui") {
      return res.status(400).json({
        message: "Kegiatan belum disetujui admin",
      });
    }

    const jumlahTerdaftar = await Pendaftaran.count({
      where: {
        kegiatan_id: kegiatan_id,
      },
    });

    if (jumlahTerdaftar >= dataKegiatan.kuota) {
      return res.status(400).json({
        message: "Kuota kegiatan sudah penuh",
      });
    }

    const pendaftaran = await Pendaftaran.create({
      nama,
      nim,
      email,
      prodi,
      no_whatsapp,
      kegiatan_id,
      status: "pending",
    });

    res.status(201).json({
      message: "Pendaftaran berhasil dikirim",
      data: pendaftaran,
      infoKuota: {
        kuota: dataKegiatan.kuota,
        terdaftar: jumlahTerdaftar + 1,
        sisaKuota: dataKegiatan.kuota - (jumlahTerdaftar + 1),
      },
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};

// Ambil detail pendaftaran berdasarkan id
export const getPendaftaranById = async (req, res) => {
  try {
    const pendaftaran = await Pendaftaran.findOne({
      where: {
        id: req.params.id,
      },
    });

    if (!pendaftaran) {
      return res.status(404).json({
        message: "Data pendaftaran tidak ditemukan",
      });
    }

    res.status(200).json(pendaftaran);
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};

// Ambil pendaftaran milik mahasiswa yang sedang login
export const getPendaftaranSaya = async (req, res) => {
  try {
    const pendaftaran = await Pendaftaran.findAll({
      where: {
        email: req.user.email,
      },
    });

    const dataDenganKegiatan = await Promise.all(
      pendaftaran.map(async (item) => {
        const kegiatan = await Kegiatan.findOne({
          where: {
            id: item.kegiatan_id,
          },
        });

        return {
          id: item.id,
          nama: item.nama,
          nim: item.nim,
          email: item.email,
          prodi: item.prodi,
          no_whatsapp: item.no_whatsapp,
          kegiatan_id: item.kegiatan_id,
          status: item.status,
          tanggal_daftar: item.tanggal_daftar,
          kegiatan: kegiatan ? kegiatan.nama : "Kegiatan tidak ditemukan",
          kategori: kegiatan ? kegiatan.kategori : "",
          tanggal_kegiatan: kegiatan ? kegiatan.tanggal : null,
          lokasi: kegiatan ? kegiatan.lokasi : "",
        };
      })
    );

    res.status(200).json(dataDenganKegiatan);
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};

// Ambil info kuota berdasarkan id kegiatan
export const getInfoKuotaKegiatan = async (req, res) => {
  try {
    const kegiatan_id = req.params.id;

    const dataKegiatan = await Kegiatan.findOne({
      where: {
        id: kegiatan_id,
      },
    });

    if (!dataKegiatan) {
      return res.status(404).json({
        message: "Kegiatan tidak ditemukan",
      });
    }

    const jumlahTerdaftar = await Pendaftaran.count({
      where: {
        kegiatan_id: kegiatan_id,
      },
    });

    const sisaKuota = dataKegiatan.kuota - jumlahTerdaftar;

    res.status(200).json({
      kegiatan: dataKegiatan.nama,
      kuota: dataKegiatan.kuota,
      terdaftar: jumlahTerdaftar,
      sisaKuota: sisaKuota < 0 ? 0 : sisaKuota,
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};