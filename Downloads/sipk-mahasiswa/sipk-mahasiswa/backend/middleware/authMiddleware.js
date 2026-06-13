import jwt from "jsonwebtoken";

const verifyToken = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({
      message: "Token tidak ditemukan",
    });
  }

  const token = authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({
      message: "Format token tidak valid",
    });
  }

  try {
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || "secret_key_jwt"
    );

    req.user = decoded;
    next();
  } catch (error) {
    return res.status(403).json({
      message: "Token tidak valid atau sudah expired",
    });
  }
};

export default verifyToken;