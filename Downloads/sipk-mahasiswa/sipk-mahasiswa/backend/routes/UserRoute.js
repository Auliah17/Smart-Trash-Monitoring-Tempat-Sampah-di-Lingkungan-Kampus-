import express from "express";

import {
  registerUser,
  loginUser,
  forgotPassword,
  getProfile,
  updateProfile,
  changePassword,
} from "../controllers/UserController.js";

const router = express.Router();

import verifyToken from "../middleware/authMiddleware.js";


router.post("/register", registerUser);
router.post("/login", loginUser);
router.post("/forgot-password", forgotPassword);
router.get("/profile", verifyToken, getProfile);
router.put("/profile", verifyToken, updateProfile);
router.put("/change-password", verifyToken, changePassword);

export default router;