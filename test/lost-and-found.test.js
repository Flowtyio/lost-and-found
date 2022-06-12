import {
  emulator,
  getContractAddress,
  executeScript,
} from "flow-js-testing";

import {after, before, lostAndFoundAdmin} from './common'

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

describe("lost-and-found tests", () => {
  beforeEach(async () => {
    await before()
  });

  // Stop emulator, so it could be restarted
  afterEach(async () => {
    await after()
  });

  test("import contracts", async () => {
    const contract = await getContractAddress("LostAndFound");
    expect(contract).toBe(lostAndFoundAdmin)

    // import it and verify the result is successful
    const [result] = await executeScript("import_contracts", []);
    expect(result).toBe(true)
  })
})
