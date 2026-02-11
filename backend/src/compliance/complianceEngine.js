const sanctionedAddresses = new Set();
const verifiedKYC = new Set();

function verifyKYC(address) {
  verifiedKYC.add(address);
}

function sanctionAddress(address) {
  sanctionedAddresses.add(address);
}

function checkCompliance(address) {
  if (sanctionedAddresses.has(address)) {
    return { allowed: false, reason: "Sanctioned address" };
  }

  if (!verifiedKYC.has(address)) {
    return { allowed: false, reason: "KYC not verified" };
  }

  return { allowed: true };
}

module.exports = {
  verifyKYC,
  sanctionAddress,
  checkCompliance
};
