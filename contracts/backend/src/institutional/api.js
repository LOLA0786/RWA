const express = require("express");
const router = express.Router();

const API_KEY = process.env.INSTITUTIONAL_API_KEY;

function auth(req, res, next) {
    if (req.headers["x-api-key"] !== API_KEY) {
        return res.status(403).json({ error: "Unauthorized" });
    }
    next();
}

router.get("/risk/:asset", auth, (req, res) => {
    res.json({
        asset: req.params.asset,
        riskScore: 420,
        status: "MONITORED"
    });
});

router.post("/bridge", auth, (req, res) => {
    res.json({
        status: "ACCEPTED",
        message: "Bridge request queued"
    });
});

module.exports = router;
