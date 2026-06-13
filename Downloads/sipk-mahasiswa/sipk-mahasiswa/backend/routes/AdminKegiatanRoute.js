import express from "express";
import {
  getAllKegiatanAdmin,
  createPengajuanKegiatan,
  updateKegiatanAdmin,
  verifyKegiatan,
  deleteKegiatan,
} from "../controllers/AdminKegiatanController.js";

const router = express.Router();

router.get("/admin/kegiatan", getAllKegiatanAdmin);
router.post("/admin/kegiatan", createPengajuanKegiatan);
router.put("/admin/kegiatan/:id", updateKegiatanAdmin);
router.put("/admin/kegiatan/:id/verifikasi", verifyKegiatan);
router.delete("/admin/kegiatan/:id", deleteKegiatan);

export default router;