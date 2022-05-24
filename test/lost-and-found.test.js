import { 
  emulator, 
  getContractAddress, 
  executeScript, 
} from "flow-js-testing";

import {setup} from './common'

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

describe("lost-and-found tests", () => {
  beforeEach(async () => {
    await setup()
  });

  // Stop emulator, so it could be restarted
  afterEach(async () => {
    await emulator.stop()
  });

  test("import contracts", async () => {
    const contract = await getContractAddress("LostAndFound");
    expect(contract).toBe("0xf8d6e0586b0a20c7")

    // import it and verify the result is successful
    const [result] = await executeScript("import_contracts", []);
    expect(result).toBe(true)
  })
})
 