import { Op } from "sequelize";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import User from "../models/UserModel.js";

// Register user
export const registerUser = async (req, res) => {
  try {
    const { name, nim, prodi, no_whatsapp, email, password } = req.body;

    if (!name || !nim || !email || !password) {
      return res.status(400).json({
        message: "Nama, NIM, email, dan password wajib diisi",
      });
    }

    const userSudahAda = await User.findOne({
      where: {
        [Op.or]: [{ email: email }, { nim: nim }],
      },
    });

    if (userSudahAda) {
      return res.status(400).json({
        message: "Email atau NIM sudah terdaftar",
      });
    }

    const hashPassword = await bcrypt.hash(password, 10);

    const user = await User.create({
      name,
      nim,
      prodi,
      no_whatsapp,
      email,
      password: hashPassword,
      role: "mahasiswa",
    });

    res.status(201).json({
      message: "Registrasi berhasil",
      data: {
        id: user.id,
        name: user.name,
        nim: user.nim,
        prodi: user.prodi,
        no_whatsapp: user.no_whatsapp,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};

// Login user pakai email atau NIM + JWT
export const loginUser = async (req, res) => {
  try {
    const { identifier, password } = req.body;

    if (!identifier || !password) {
      return res.status(400).json({
        message: "Email/NIM dan password wajib diisi",
      });
    }

    const user = await User.findOne({
      where: {
        [Op.or]: [{ email: identifier }, { nim: identifier }],
      },
    });

    if (!user) {
      return res.status(404).json({
        message: "Email atau NIM tidak ditemukan",
      });
    }

    const passwordCocok = await bcrypt.compare(password, user.password);

    if (!passwordCocok) {
      return res.status(400).json({
        message: "Password salah",
      });
    }

    const token = jwt.sign(
      {
        id: user.id,
        name: user.name,
        nim: user.nim,
        email: user.email,
        role: user.role,
      },
      process.env.JWT_SECRET || "secret_key_jwt",
      {
        expiresIn: "1d",
      }
    );

    res.status(200).json({
      message: "Login berhasil",
      token: token,
      data: {
        id: user.id,
        name: user.name,
        nim: user.nim,
        prodi: user.prodi,
        no_whatsapp: user.no_whatsapp,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};

// Cek email untuk lupa password
export const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        message: "Email wajib diisi",
      });
    }

    const user = await User.findOne({
      where: {
        email: email,
      },
    });

    if (!user) {
      return res.status(404).json({
        message: "Email tidak terdaftar",
      });
    }

    res.status(200).json({
      message: "Email ditemukan. Fitur reset password akan diproses.",
      data: {
        id: user.id,
        name: user.name,
        email: user.email,
      },
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};

// Ambil profil user yang sedang login
export const getProfile = async (req, res) => {
  try {
    const user = await User.findOne({
      where: {
        id: req.user.id,
      },
      attributes: [
        "id",
        "name",
        "nim",
        "prodi",
        "no_whatsapp",
        "email",
        "role",
      ],
    });

    if (!user) {
      return res.status(404).json({
        message: "User tidak ditemukan",
      });
    }

    res.status(200).json(user);
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};

// Update profil user yang sedang login
export const updateProfile = async (req, res) => {
  try {
    const { name, prodi, no_whatsapp } = req.body;

    const user = await User.findOne({
      where: {
        id: req.user.id,
      },
    });

    if (!user) {
      return res.status(404).json({
        message: "User tidak ditemukan",
      });
    }

    await User.update(
      {
        name,
        prodi,
        no_whatsapp,
      },
      {
        where: {
          id: req.user.id,
        },
      }
    );

    const updatedUser = await User.findOne({
      where: {
        id: req.user.id,
      },
      attributes: [
        "id",
        "name",
        "nim",
        "prodi",
        "no_whatsapp",
        "email",
        "role",
      ],
    });

    res.status(200).json({
      message: "Profil berhasil diperbarui",
      data: updatedUser,
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};

// Ganti password user
export const changePassword = async (req, res) => {
  try {
    const { password_lama, password_baru, konfirmasi_password } = req.body;

    if (!password_lama || !password_baru || !konfirmasi_password) {
      return res.status(400).json({
        message: "Semua field wajib diisi",
      });
    }

    if (password_baru !== konfirmasi_password) {
      return res.status(400).json({
        message: "Konfirmasi password tidak cocok",
      });
    }

    const user = await User.findOne({
      where: {
        id: req.user.id,
      },
    });

    if (!user) {
      return res.status(404).json({
        message: "User tidak ditemukan",
      });
    }

    const match = await bcrypt.compare(password_lama, user.password);

    if (!match) {
      return res.status(400).json({
        message: "Password lama salah",
      });
    }

    const salt = await bcrypt.genSalt();
    const hashPassword = await bcrypt.hash(password_baru, salt);

    await User.update(
      {
        password: hashPassword,
      },
      {
        where: {
          id: req.user.id,
        },
      }
    );

    res.status(200).json({
      message: "Password berhasil diubah",
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};