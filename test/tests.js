const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const config = require("../config.json");

describe("Hash Valley tests", function () {
  let accounts;
  let vineyard;
  let bottle;
  let cellar;
  let vinegar;
  let storage;
  let provider;

  const deploy = async () => {
    const Storage = await hre.ethers.getContractFactory("AddressStorage");
    storage = await Storage.deploy();
    await storage.deployed();

    const Vineyard = await hre.ethers.getContractFactory("VineyardV1");
    vineyard = await Vineyard.deploy(
      config.vine_base_uri,
      config.vine_img_uri,
      storage.address
    );
    await vineyard.deployed();

    const Cellar = await hre.ethers.getContractFactory("CellarV1");
    cellar = await Cellar.deploy(storage.address);
    await cellar.deployed();

    const WineBottle = await hre.ethers.getContractFactory("WineBottleV1");
    bottle = await WineBottle.deploy(
      config.bottle_base_uri,
      config.bottle_img_uri,
      storage.address
    );
    await bottle.deployed();

    const Vinegar = await hre.ethers.getContractFactory("Vinegar");
    vinegar = await Vinegar.deploy(storage.address);
    await vinegar.deployed();

    await storage.setAddresses(
      cellar.address,
      vinegar.address,
      vineyard.address,
      bottle.address
    );

    accounts = await ethers.getSigners();
    provider = await ethers.getDefaultProvider();
  };

  describe("Setup and minting", function () {
    beforeEach(async () => {
      await deploy();
    });

    it("Should have addresses set correctly", async () => {
      expect(await storage.vineyard()).to.equal(vineyard.address);
      expect(await storage.cellar()).to.equal(cellar.address);
      expect(await storage.bottle()).to.equal(bottle.address);
      expect(await storage.vinegar()).to.equal(vinegar.address);
    });

    it("Owner set correctly", async () => {
      expect(await vineyard.owner()).to.equal(accounts[0].address);
    });

    it("first 100 are free, 0.05 eth after that", async () => {
      for (let i = 0; i < 100; i++) {
        const tx = await vineyard
          .connect(accounts[1])
          .newVineyards([4, 2, 0, 4]);
        expect(tx)
          .to.emit(vineyard, "Transfer")
          .withArgs(
            "0x0000000000000000000000000000000000000000",
            accounts[1].address,
            i
          );
      }
      await expect(
        vineyard.connect(accounts[1]).newVineyards([4, 2, 0, 4], {
          value: ethers.utils.parseEther("0.04"),
        })
      ).to.be.revertedWith("Value below price");

      const tx = await vineyard
        .connect(accounts[1])
        .newVineyards([4, 2, 0, 4], { value: ethers.utils.parseEther("0.05") });
      expect(tx)
        .to.emit(vineyard, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          accounts[1].address,
          100
        );
    });

    it("Correct number of params", async () => {
      await expect(
        vineyard.connect(accounts[1]).newVineyards([1, 2, 3, 4, 5])
      ).to.be.revertedWith("Incorrect number of params");

      await expect(
        vineyard.connect(accounts[1]).newVineyards([1, 2, 3])
      ).to.be.revertedWith("Incorrect number of params");
    });

    it("Third attribute must be 0 or 1", async () => {
      await expect(
        vineyard.connect(accounts[1]).newVineyards([4, 2, 3, 4])
      ).to.be.revertedWith("Invalid third attribute");
    });

    it("Only owner can withdraw", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 130, 0, 3]);

      await expect(
        vineyard.connect(accounts[1]).withdrawAll()
      ).to.be.revertedWith("Ownable: caller is not the owner");

      const tx = await vineyard.connect(accounts[0]).withdrawAll();
    });

    it("get params", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);
      const attr = await vineyard.getTokenAttributes(0);
      expect(attr[0].toString()).to.equal("12");
      expect(attr[1].toString()).to.equal("13");
      expect(attr[2].toString()).to.equal("0");
      expect(attr[3].toString()).to.equal("4");
    });

    it("can't plant before game start", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);
      await expect(vineyard.connect(accounts[1]).plant(0)).to.be.revertedWith(
        "Not planting time"
      );
    });

    it("can't harvest before game start", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);
      await expect(vineyard.connect(accounts[1]).harvest(0)).to.be.revertedWith(
        "Not harvest time"
      );
    });

    it("season is 0", async () => {
      let season = Number(await vineyard.currSeason());
      expect(season).to.equal(0);
    });

    it("token uri", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 130, 0, 3]);
      let uri = await vineyard.tokenURI(0);
      console.log(uri);
    });
  });

  describe("Game flow", function () {
    beforeEach(async () => {
      await deploy();
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);
      await vineyard.start();
      await ethers.provider.send("evm_mine", []);
    });

    it("first season 3 weeks, subsequent seasons 12 weeks", async () => {
      let season = Number(await vineyard.currSeason());
      expect(season).to.equal(1);

      let seasonLength = Number(await vineyard.firstSeasonLength());
      await ethers.provider.send("evm_increaseTime", [seasonLength + 1]);
      await ethers.provider.send("evm_mine", []);
      season = Number(await vineyard.currSeason());
      expect(season).to.equal(2);

      seasonLength = Number(await vineyard.seasonLength());
      await ethers.provider.send("evm_increaseTime", [seasonLength + 1]);
      await ethers.provider.send("evm_mine", []);
      season = Number(await vineyard.currSeason());
      expect(season).to.equal(3);

      await ethers.provider.send("evm_increaseTime", [seasonLength + 1]);
      await ethers.provider.send("evm_mine", []);
      season = Number(await vineyard.currSeason());
      expect(season).to.equal(4);
    });

    it("game already started", async () => {
      const start = await vineyard.gameStart();
      expect(Number(start)).to.be.greaterThan(0);
      await expect(vineyard.start()).to.be.revertedWith("Game already started");
    });

    it("can plant", async () => {
      const tx = await vineyard.connect(accounts[1]).plant(0);
      expect(tx).to.emit(vineyard, "Planted").withArgs(0, 1);
    });

    it("can't plant after 1 week", async () => {
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
      await expect(vineyard.connect(accounts[1]).plant(0)).to.be.revertedWith(
        "Not planting time"
      );
    });

    it("watering", async () => {
      await vineyard.connect(accounts[1]).plant(0);
      const planted = Number(await vineyard.watered(0));

      await expect(vineyard.connect(accounts[1]).water(0)).to.be.revertedWith(
        "Vineyard can't be watered"
      );

      // can be watered after 24 hours
      let time = Number(await vineyard.minWaterTime(0));
      await ethers.provider.send("evm_increaseTime", [time]);
      await vineyard.connect(accounts[1]).water(0);

      let firstWater = Number(await vineyard.watered(0));
      expect(firstWater).to.equal(planted + time + 1);

      // can't be watered again yet
      await expect(vineyard.connect(accounts[1]).water(0)).to.be.revertedWith(
        "Vineyard can't be watered"
      );

      // can water again after another 24 hours
      await ethers.provider.send("evm_increaseTime", [time]);
      await vineyard.connect(accounts[1]).water(0);

      let secondWater = Number(await vineyard.watered(0));
      expect(secondWater).to.equal(firstWater + time + 1);

      // can water again up to 48 hours later
      time = time + Number(await vineyard.waterWindow(0)) - 1;
      await ethers.provider.send("evm_increaseTime", [time]);
      await vineyard.connect(accounts[1]).water(0);

      let thirdWater = Number(await vineyard.watered(0));
      expect(thirdWater).to.be.greaterThanOrEqual(secondWater + time);
      expect(thirdWater).to.be.lessThanOrEqual(secondWater + time + 2);

      // can't water over 48 hours later
      time = time + 2;
      await ethers.provider.send("evm_increaseTime", [time]);
      await expect(vineyard.connect(accounts[1]).water(0)).to.be.revertedWith(
        "Vineyard can't be watered"
      );
    });

    it("can't harvest early", async () => {
      await vineyard.connect(accounts[1]).plant(0);

      let time = Number(await vineyard.minWaterTime(0));
      for (let i = 0; i <= 12; i++) {
        await ethers.provider.send("evm_increaseTime", [time]);
        await vineyard.connect(accounts[1]).water(0);
      }

      await expect(vineyard.connect(accounts[1]).harvest(0)).to.be.revertedWith(
        "Not harvest time"
      );

      await ethers.provider.send("evm_increaseTime", [time]);
      expect(await vineyard.connect(accounts[1]).harvest(0))
        .to.emit(vineyard, "Harvested")
        .withArgs(0, 1, 0);
      console.log(await bottle.tokenURI(0));

      await ethers.provider.send("evm_increaseTime", [time]);
      await expect(vineyard.connect(accounts[1]).harvest(0)).to.be.revertedWith(
        "Vineyard already harvested"
      );
    });

    it("can't harvest late", async () => {
      await vineyard.connect(accounts[1]).plant(0);

      let time = Number(await vineyard.minWaterTime(0));
      for (let i = 0; i <= 21; i++) {
        await ethers.provider.send("evm_increaseTime", [time]);
        await vineyard.connect(accounts[1]).water(0);
      }

      await expect(vineyard.connect(accounts[1]).harvest(0)).to.be.revertedWith(
        "Not harvest time"
      );
    });

    it("second season", async () => {
      let seasonLength = Number(await vineyard.firstSeasonLength());
      await ethers.provider.send("evm_increaseTime", [seasonLength + 1]);
      await ethers.provider.send("evm_mine", []);

      // correct season number
      let season = Number(await vineyard.currSeason());
      expect(season).to.equal(2);

      await vineyard.connect(accounts[1]).plant(0);

      let time = Number(await vineyard.minWaterTime(0));
      for (let i = 0; i <= 75; i++) {
        await ethers.provider.send("evm_increaseTime", [time]);
        await vineyard.connect(accounts[1]).water(0);
      }

      // can't harvest early
      await expect(vineyard.connect(accounts[1]).harvest(0)).to.be.revertedWith(
        "Not harvest time"
      );

      // can harvest on time
      await ethers.provider.send("evm_increaseTime", [time]);
      expect(await vineyard.connect(accounts[1]).harvest(0))
        .to.emit(vineyard, "Harvested")
        .withArgs(0, 2, 0);
    });

    it("second season can't harvest late", async () => {
      let seasonLength = Number(await vineyard.firstSeasonLength());
      await ethers.provider.send("evm_increaseTime", [seasonLength + 1]);
      await ethers.provider.send("evm_mine", []);

      // correct season number
      let season = Number(await vineyard.currSeason());
      expect(season).to.equal(2);

      await vineyard.connect(accounts[1]).plant(0);

      let time = Number(await vineyard.minWaterTime(0));
      for (let i = 0; i <= 84; i++) {
        await ethers.provider.send("evm_increaseTime", [time]);
        await vineyard.connect(accounts[1]).water(0);
      }

      await expect(vineyard.connect(accounts[1]).harvest(0)).to.be.revertedWith(
        "Not harvest time"
      );
    });

    it("plant multiple", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);

      expect(Number(await vineyard.planted(0))).to.equal(0);
      expect(Number(await vineyard.planted(1))).to.equal(0);
      expect(Number(await vineyard.planted(2))).to.equal(0);

      await vineyard.connect(accounts[1]).plantMultiple([0, 1, 2]);
      expect(Number(await vineyard.planted(0))).to.be.greaterThan(0);
      expect(Number(await vineyard.planted(1))).to.be.greaterThan(0);
      expect(Number(await vineyard.planted(2))).to.be.greaterThan(0);
    });

    it("water multiple", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);
      await vineyard.connect(accounts[1]).plantMultiple([0, 1, 2]);

      let planted0 = Number(await vineyard.watered(0));
      let planted1 = Number(await vineyard.watered(1));
      let planted2 = Number(await vineyard.watered(2));

      let time = Number(await vineyard.minWaterTime(0));
      await ethers.provider.send("evm_increaseTime", [time]);

      await vineyard.connect(accounts[1]).waterMultiple([0, 1, 2]);
      expect(Number(await vineyard.watered(0))).to.be.greaterThan(planted0);
      expect(Number(await vineyard.watered(1))).to.be.greaterThan(planted1);
      expect(Number(await vineyard.watered(2))).to.be.greaterThan(planted2);

      await ethers.provider.send("evm_increaseTime", [time]);
      await vineyard.connect(accounts[1]).waterMultiple([0, 1]);
      await ethers.provider.send("evm_increaseTime", [time + 1]);

      await expect(
        vineyard.connect(accounts[1]).waterMultiple([0, 1, 2])
      ).to.be.revertedWith("Vineyard can't be watered");
    });

    it("harvest multiple", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 0, 4]);
      await vineyard.connect(accounts[1]).plantMultiple([0, 1, 2]);

      let time = Number(await vineyard.minWaterTime(0));
      for (let i = 0; i <= 12; i++) {
        await ethers.provider.send("evm_increaseTime", [time]);
        await vineyard.connect(accounts[1]).waterMultiple([0, 1, 2]);
      }

      // can't harvest early
      await expect(
        vineyard.connect(accounts[1]).harvestMultiple([0, 1, 2])
      ).to.be.revertedWith("Not harvest time");

      // can harvest on time
      await ethers.provider.send("evm_increaseTime", [time]);
      const tx = await vineyard.connect(accounts[1]).harvestMultiple([0, 1, 2]);
      expect(tx).to.emit(vineyard, "Harvested").withArgs(0, 1, 0);
      expect(tx).to.emit(vineyard, "Harvested").withArgs(1, 1, 1);
      expect(tx).to.emit(vineyard, "Harvested").withArgs(2, 1, 2);
    });

    it("bottle age", async () => {
      await vineyard.connect(accounts[1]).plant(0);

      let time = Number(await vineyard.minWaterTime(0));
      for (let i = 0; i <= 18; i++) {
        await ethers.provider.send("evm_increaseTime", [time]);
        await vineyard.connect(accounts[1]).water(0);
      }

      expect(await vineyard.connect(accounts[1]).harvest(0))
        .to.emit(vineyard, "Harvested")
        .withArgs(0, 1, 0);

      await ethers.provider.send("evm_increaseTime", [12]);
      await ethers.provider.send("evm_mine", []);

      const age = await bottle.bottleAge(0);
      expect(age).to.equal(12);
    });
  });

  describe("Cellar", function () {
    beforeEach(async () => {
      await deploy();
      await vineyard.newVineyards([12, 13, 0, 4]);
      await vineyard.newVineyards([12, 13, 0, 4]);
      await vineyard.newVineyards([12, 13, 0, 4]);
      await vineyard.start();
      await vineyard.plantMultiple([0, 1, 2]);

      let time = Number(await vineyard.minWaterTime(0));
      for (let i = 0; i <= 18; i++) {
        await ethers.provider.send("evm_increaseTime", [time]);
        await vineyard.waterMultiple([0, 1, 2]);
      }

      await ethers.provider.send("evm_increaseTime", [time]);
      await vineyard.harvestMultiple([0, 1, 2]);
      await bottle.setApprovalForAll(cellar.address, true);
    });

    it("stake bottle", async () => {
      await cellar.stake(0);
      await cellar.stake(1);
      await cellar.stake(2);
      await ethers.provider.send("evm_increaseTime", [10]);
      await ethers.provider.send("evm_mine", []);
      await cellar.withdraw(0);
      await cellar.withdraw(1);
      await cellar.withdraw(2);
      const vinegarBalance = await vinegar.balanceOf(accounts[0].address);
      expect(Number(vinegarBalance)).to.be.greaterThan(0);

      await expect(bottle.ownerOf(0)).to.be.revertedWith(
        "ERC721: owner query for nonexistent token"
      );
      await expect(bottle.ownerOf(2)).to.be.revertedWith(
        "ERC721: owner query for nonexistent token"
      );

      await bottle.rejuvenate(0);
      const newVinegarBalance = await vinegar.balanceOf(accounts[0].address);
      expect(Number(newVinegarBalance)).to.equal(0);

      const newBottleOwner = await bottle.ownerOf(3);
      expect(newBottleOwner).to.equal(accounts[0].address);

      await expect(bottle.rejuvenate(0)).to.be.revertedWith("cannot rejuve");
    });
  });
});
