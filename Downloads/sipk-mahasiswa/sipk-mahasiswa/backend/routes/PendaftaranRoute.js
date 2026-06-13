import express from "express";

import {
  getPendaftaranById,
  createPendaftaran,
  getInfoKuotaKegiatan,
  getPendaftaranSaya,
} from "../controllers/PendaftaranController.js";

import verifyToken from "../middleware/authMiddleware.js";

const router = express.Router();

router.get("/pendaftaran-info/:id", verifyToken, getInfoKuotaKegiatan);
router.get("/pendaftaran-saya", verifyToken, getPendaftaranSaya);
router.post("/pendaftaran", verifyToken, createPendaftaran);
router.get("/pendaftaran/:id", verifyToken, getPendaftaranById);

export default router;