import express from "express";

import {
  getAllPeserta,
  verifyPeserta,
  deletePeserta,
} from "../controllers/AdminPesertaController.js";

const router = express.Router();

router.get("/peserta", getAllPeserta);

router.put("/peserta/:id/verifikasi", verifyPeserta);

router.delete("/peserta/:id", deletePeserta);

export default router;