let reserves = 1_000_000_000; // simulated USD reserve
let circulating = 900_000_000;

function getReserveStatus() {
  return {
    reserves,
    circulating,
    fullyBacked: reserves >= circulating
  };
}

function mint(amount) {
  circulating += amount;
}

function burn(amount) {
  circulating -= amount;
}

module.exports = {
  getReserveStatus,
  mint,
  burn
};
