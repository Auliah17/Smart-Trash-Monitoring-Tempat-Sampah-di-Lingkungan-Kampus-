import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import db from "./config/db.js";

import Kegiatan from "./models/KegiatanModel.js";
import User from "./models/UserModel.js";
import Pendaftaran from "./models/PendaftaranModel.js";

import KegiatanRoute from "./routes/KegiatanRoute.js";
import UserRoute from "./routes/UserRoute.js";
import PendaftaranRoute from "./routes/PendaftaranRoute.js";
import AdminPesertaRoute from "./routes/AdminPesertaRoute.js";
import AdminKegiatanRoute from "./routes/AdminKegiatanRoute.js";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

app.use(KegiatanRoute);
app.use(UserRoute);
app.use(PendaftaranRoute);
app.use(AdminPesertaRoute);
app.use(AdminKegiatanRoute);

db.authenticate()
  .then(() => console.log("Database connected..."))
  .catch((err) => console.error("Connection error:", err));

db.sync()
  .then(() => console.log("Database synced..."))
  .catch((err) => console.error("Sync error:", err));

app.get("/", (req, res) => {
  res.send("API SIPK berjalan...");
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});