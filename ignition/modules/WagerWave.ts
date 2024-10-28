import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("WagerWave", (m) => {
  const wagerWave = m.contract("WagerWave");

  return { wagerWave };
});
