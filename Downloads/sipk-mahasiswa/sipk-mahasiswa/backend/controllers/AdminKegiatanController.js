import Kegiatan from "../models/KegiatanModel.js";
import sequelize from "sequelize";

export const getAllKegiatanAdmin = async (req, res) => {
    try {
        const kegiatan = await Kegiatan.findAll({
            attributes: {
                include: [
                    [
                        // Perbaikan: Menggunakan nama tabel 'pendaftarans' dan 'kegiatans'
                        // sesuai dengan struktur di phpMyAdmin Anda.
                        sequelize.literal(`(
                            SELECT COUNT(*) 
                            FROM pendaftarans AS pendaftaran 
                            WHERE pendaftaran.kegiatan = kegiatans.id
                        )`), 
                        "terdaftar"
                    ]
                ]
            },
            order: [["id", "DESC"]],
        });
        res.status(200).json({ success: true, data: kegiatan });
    } catch (error) {
        console.error("Error Detail:", error);
        res.status(500).json({ success: false, message: error.message });
    }
};

export const createPengajuanKegiatan = async (req, res) => {
    try {
        const data = await Kegiatan.create({ ...req.body, status: "pending" });
        res.status(201).json({ success: true, data });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const updateKegiatanAdmin = async (req, res) => {
    try {
        const k = await Kegiatan.findByPk(req.params.id);
        if (!k) return res.status(404).json({ message: "Data tidak ditemukan" });
        await k.update(req.body);
        res.status(200).json({ success: true, message: "Berhasil diupdate" });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const verifyKegiatan = async (req, res) => {
    try {
        const k = await Kegiatan.findByPk(req.params.id);
        if (!k) return res.status(404).json({ message: "Data tidak ditemukan" });
        await k.update({ status: req.body.status });
        res.status(200).json({ success: true, message: "Berhasil verifikasi" });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const deleteKegiatan = async (req, res) => {
    try {
        const k = await Kegiatan.findByPk(req.params.id);
        if (!k) return res.status(404).json({ message: "Data tidak ditemukan" });
        await k.destroy();
        res.status(200).json({ success: true, message: "Berhasil dihapus" });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};