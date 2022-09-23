const chai = require("chai");
const { expect } = chai;
const { ethers } = require("hardhat");
const { utils } = ethers;
const { solidity } = require("ethereum-waffle");

chai.use(solidity);

const config = require("../config");

const day = 24 * 60 * 60;
const month = 30 * day;
const spCost = ethers.utils.parseEther("0.01");

describe("Hash Valley tests", function () {
  let accounts;
  let vineyard;
  let bottle;
  let cellar;
  let vinegar;
  let token;
  let storage;
  let royalty;
  let quixotic;

  let multi;

  let wineUri;
  let vineUri;

  let grape;
  let alchemy;
  let spellParams;

  const deploy = async () => {
    const Quixotic = await hre.ethers.getContractFactory("DummyQuixotic");
    quixotic = await Quixotic.deploy();
    await quixotic.deployed();

    const Storage = await hre.ethers.getContractFactory("AddressStorage");
    storage = await Storage.deploy();
    await storage.deployed();

    const Royalty = await hre.ethers.getContractFactory("RoyaltyManager");
    royalty = await Royalty.deploy(storage.address, quixotic.address);
    await royalty.deployed();

    const Cellar = await hre.ethers.getContractFactory("Cellar");
    cellar = await Cellar.deploy(storage.address);
    await cellar.deployed();

    const WineUri = await hre.ethers.getContractFactory("VotableUri");
    wineUri = await WineUri.deploy(
      storage.address,
      config.bottle_animation_uri,
      config.bottle_img_uri
    );
    await wineUri.deployed();

    const WineBottle = await hre.ethers.getContractFactory("WineBottle");
    bottle = await WineBottle.deploy(
      config.bottle_base_uri,
      storage.address,
      config.eraBounds
    );
    await bottle.deployed();

    const VineUri = await hre.ethers.getContractFactory("VotableUri");
    vineUri = await VineUri.deploy(
      storage.address,
      config.vine_animation_uri,
      config.vine_img_uri
    );
    await vineUri.deployed();

    const Vineyard = await hre.ethers.getContractFactory("Vineyard");
    vineyard = await Vineyard.deploy(
      config.vine_base_uri,
      storage.address,
      config.mintReqs,
      config.climates
    );
    await vineyard.deployed();

    const Vinegar = await hre.ethers.getContractFactory("Vinegar");
    vinegar = await Vinegar.deploy(storage.address);
    await vinegar.deployed();

    const Alchemy = await hre.ethers.getContractFactory("Alchemy");
    alchemy = await Alchemy.deploy(storage.address);
    await alchemy.deployed();

    const Grape = await hre.ethers.getContractFactory("Grape");
    grape = await Grape.deploy(storage.address);
    await grape.deployed();

    const Token = await hre.ethers.getContractFactory("GiveawayToken");
    token = await Token.deploy();
    await token.deployed();

    const SpellParams = await hre.ethers.getContractFactory("SpellParams");
    spellParams = await SpellParams.deploy(storage.address);
    await spellParams.deployed();

    const Multi = await hre.ethers.getContractFactory("Multicall");
    multi = await Multi.deploy();
    await multi.deployed();

    const SaleParams = await hre.ethers.getContractFactory("SaleParams");
    saleParams = await SaleParams.deploy();
    await saleParams.deployed();
    await vineyard.setSaleParams(saleParams.address);

    await storage.setAddresses(
      cellar.address,
      vinegar.address,
      vineyard.address,
      bottle.address,
      token.address,
      royalty.address,
      alchemy.address,
      grape.address,
      spellParams.address,
      wineUri.address,
      vineUri.address
    );

    await vineyard.initR();
    await bottle.initR();

    accounts = await ethers.getSigners();
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

    it("Owner set to royalty manager", async () => {
      expect(await vineyard.owner()).to.equal(royalty.address);
    });

    it("Sale params", async () => {
      const vals = await Promise.all([
        saleParams.getSalesPrice(999),
        saleParams.getSalesPrice(1000),
        saleParams.getSalesPrice(1500),
        saleParams.getSalesPrice(2000),
        saleParams.getSalesPrice(2500),
        saleParams.getSalesPrice(3000),
        saleParams.getSalesPrice(3500),
        saleParams.getSalesPrice(4000),
        saleParams.getSalesPrice(4500),
        saleParams.getSalesPrice(5000),
        saleParams.getSalesPrice(5499),
        saleParams.getSalesPrice(5500),
      ]);
      expect(vals.map((x) => x.toString())).to.eql([
        "0",
        utils.parseEther("0.01").toString(),
        utils.parseEther("0.02").toString(),
        utils.parseEther("0.03").toString(),
        utils.parseEther("0.04").toString(),
        utils.parseEther("0.05").toString(),
        utils.parseEther("0.06").toString(),
        utils.parseEther("0.07").toString(),
        utils.parseEther("0.08").toString(),
        utils.parseEther("0.09").toString(),
        utils.parseEther("0.09").toString(),
        utils.parseEther("0.1").toString(),
      ]);
    });

    it.skip("first 100 are free, 0.07 eth after that", async () => {
      for (let i = 0; i < 100; i++) {
        const tx = await vineyard.connect(accounts[1]).newVineyards([4, 2, 4]);
        expect(tx)
          .to.emit(vineyard, "Transfer")
          .withArgs(
            "0x0000000000000000000000000000000000000000",
            accounts[1].address,
            i
          );
      }
      await expect(
        vineyard.connect(accounts[1]).newVineyards([4, 2, 4], {
          value: ethers.utils.parseEther("0.04"),
        })
      ).to.be.revertedWith("Value below price");

      const tx = await vineyard
        .connect(accounts[1])
        .newVineyards([4, 2, 4], { value: ethers.utils.parseEther(".07") });
      expect(tx)
        .to.emit(vineyard, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          accounts[1].address,
          100
        );
    });

    it("use giveaway token", async () => {
      const tx = await vineyard.newVineyardGiveaway([4, 2, 4]);
      expect(tx)
        .to.emit(vineyard, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          accounts[0].address,
          0
        );
      await expect(
        vineyard.connect(accounts[1]).newVineyardGiveaway([4, 2, 4])
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });

    it.skip("use giveaway token with max supply", async () => {
      const max = Number(await vineyard.maxVineyards());
      for (let i = 0; i < max; i++) {
        await vineyard.newVineyards([4, 2, 4], {
          value: ethers.utils.parseEther("0.09"),
        });
      }

      await expect(
        vineyard.newVineyards([4, 2, 4], {
          value: ethers.utils.parseEther("0.1"),
        })
      ).to.be.revertedWith("Max vineyards minted");

      const tx = await vineyard.newVineyardGiveaway([4, 2, 4]);
      expect(tx)
        .to.emit(vineyard, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          accounts[0].address,
          5500
        );
    });

    it("Correct number of params", async () => {
      await expect(
        vineyard.connect(accounts[1]).newVineyards([1, 2, 3, 4])
      ).to.be.revertedWith("wrong #params");

      await expect(
        vineyard.connect(accounts[1]).newVineyards([1, 2])
      ).to.be.revertedWith("wrong #params");
    });

    it("Only owner can withdraw", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 130, 3]);

      await expect(
        vineyard.connect(accounts[1]).withdrawAll()
      ).to.be.revertedWith("!deployer");

      await vineyard.connect(accounts[0]).withdrawAll();
    });

    it("get params", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      const attr = await vineyard.getTokenAttributes(0);
      expect(attr[0].toString()).to.equal("12");
      expect(attr[1].toString()).to.equal("13");
      expect(attr[2].toString()).to.equal("4");
    });

    it("can't plant before game start", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      await expect(vineyard.connect(accounts[1]).plant(0)).to.be.revertedWith(
        "Not planting time"
      );
    });

    it("can't harvest before game start", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      await expect(vineyard.connect(accounts[1]).harvest(0)).to.be.revertedWith(
        "Not harvest time"
      );
    });

    it("season is 0", async () => {
      let season = Number(await vineyard.currSeason());
      expect(season).to.equal(0);
    });

    it("token uri", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 130, 3]);
      const uri = await vineyard.tokenURI(0);
      console.log(Buffer.from(uri.slice(29), "base64").toString("ascii"));
    });

    it("airdrop", async () => {
      await token.airdrop([accounts[11].address, accounts[12].address], [2, 1]);
      await expect(
        token.airdrop([accounts[11].address], [4])
      ).to.be.revertedWith("!");
      await vineyard.connect(accounts[11]).newVineyardGiveaway([12, 130, 3]);
      await vineyard.connect(accounts[11]).newVineyardGiveaway([12, 130, 3]);
      await expect(
        vineyard.connect(accounts[11]).newVineyardGiveaway([12, 130, 3])
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");

      await vineyard.connect(accounts[12]).newVineyardGiveaway([12, 130, 3]);
      await expect(
        vineyard.connect(accounts[12]).newVineyardGiveaway([12, 130, 3])
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });
  });

  describe("Game flow", function () {
    beforeEach(async () => {
      await deploy();
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
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
      expect(thirdWater).to.be.lessThanOrEqual(secondWater + time + 3);

      // can't water over 48 hours later
      time = time + 2;
      await ethers.provider.send("evm_increaseTime", [time]);
      await expect(vineyard.connect(accounts[1]).water(0)).to.be.revertedWith(
        "Vineyard can't be watered"
      );
    });

    it("sprinkler means you don't have to water", async () => {
      await vineyard.connect(accounts[1]).buySprinkler(0, { value: spCost });
      await vineyard.connect(accounts[1]).plant(0);

      let seasonLength = Number(await vineyard.firstSeasonLength());
      await ethers.provider.send("evm_increaseTime", [seasonLength - 10]);
      await ethers.provider.send("evm_mine", []);

      await vineyard.connect(accounts[1]).harvest(0);
    });

    it("sprinkler lasts 3 years", async () => {
      await vineyard.connect(accounts[1]).buySprinkler(0, { value: spCost });

      let firstSeasonLength = Number(await vineyard.firstSeasonLength());
      let seasonLength = Number(await vineyard.seasonLength());
      await ethers.provider.send("evm_increaseTime", [firstSeasonLength]);
      for (let i = 0; i < 10; i++) {
        await ethers.provider.send("evm_increaseTime", [seasonLength]);
      }
      await ethers.provider.send("evm_mine", []);

      await vineyard.connect(accounts[1]).plant(0);
      await ethers.provider.send("evm_increaseTime", [seasonLength - 10]);
      await ethers.provider.send("evm_mine", []);
      await vineyard.connect(accounts[1]).harvest(0);

      await ethers.provider.send("evm_increaseTime", [100]);
      await ethers.provider.send("evm_mine", []);
      await vineyard.connect(accounts[1]).plant(0);
      await ethers.provider.send("evm_increaseTime", [seasonLength - 200]);
      await ethers.provider.send("evm_mine", []);
      await expect(vineyard.connect(accounts[1]).harvest(0)).to.be.revertedWith(
        "Vineyard not alive"
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

      const uri = await bottle.tokenURI(0);
      console.log(Buffer.from(uri.slice(29), "base64").toString("ascii"));

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
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);

      expect(Number(await vineyard.planted(0))).to.equal(0);
      expect(Number(await vineyard.planted(1))).to.equal(0);
      expect(Number(await vineyard.planted(2))).to.equal(0);

      await vineyard.connect(accounts[1]).plantMultiple([0, 1, 2]);
      expect(Number(await vineyard.planted(0))).to.be.greaterThan(0);
      expect(Number(await vineyard.planted(1))).to.be.greaterThan(0);
      expect(Number(await vineyard.planted(2))).to.be.greaterThan(0);
    });

    it("water multiple", async () => {
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
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
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
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

      const age = Number(await bottle.bottleAge(0));
      expect(age === 12 || age === 13).to.be.true;
    });

    it("cellar age", async () => {
      const ages = await Promise.all([
        bottle.cellarAged(15 * day),
        bottle.cellarAged(5 * month + 1 * day),
        bottle.cellarAged(11 * month),
        bottle.cellarAged(11 * month + 1 * day),
        bottle.cellarAged(11 * month + 29 * day),
        bottle.cellarAged(11 * month + 30 * day),
        bottle.cellarAged(11 * month + 31 * day),
        bottle.cellarAged(11 * month + 67 * day),
      ]);

      expect(ages.map((x) => x.toString())).to.eql([
        "1576800000",
        "51613920000",
        "126144000000000000",
        "135604800000000000",
        "400507200000000000",
        "409968000000000000",
        "409968000000000000",
        "409968000000000000",
      ]);
    });
  });

  describe("Cellar", function () {
    beforeEach(async () => {
      await deploy();
      await vineyard.newVineyards([12, 13, 4]);
      await vineyard.newVineyards([12, 13, 4]);
      await vineyard.newVineyards([12, 13, 4]);
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
      await ethers.provider.send("evm_increaseTime", [31104000]);
      await ethers.provider.send("evm_mine", []);
      await cellar.withdraw(0);
      await cellar.withdraw(1);
      await cellar.withdraw(2);

      // vinegar received from one spoiled bottle
      const oneYear = "4745000000000000000000000000000";
      // vinegar received from three spoiled bottle
      const threeYears = ethers.BigNumber.from(oneYear).mul(3).toString();

      const vinegarBalance = await vinegar.balanceOf(accounts[0].address);
      // if all three bottles spoiled, this should pass
      // if one of them didn't, the rest of this test will fail anyways
      // in which case just run it again until the random numbers work out
      // (only 5% chance of one of these bottles not spoiling)
      expect(vinegarBalance.toString()).to.equal(threeYears);

      await expect(bottle.ownerOf(0)).to.be.revertedWith(
        "ERC721: owner query for nonexistent token"
      );
      await expect(bottle.ownerOf(1)).to.be.revertedWith(
        "ERC721: owner query for nonexistent token"
      );
      await expect(bottle.ownerOf(2)).to.be.revertedWith(
        "ERC721: owner query for nonexistent token"
      );

      await bottle.rejuvenate(0);
      const newVinegarBalance = await vinegar.balanceOf(accounts[0].address);
      expect(newVinegarBalance.toString()).to.equal("0");

      const newBottleOwner = await bottle.ownerOf(3);
      expect(newBottleOwner).to.equal(accounts[0].address);

      await expect(bottle.rejuvenate(0)).to.be.revertedWith("cannot rejuve");
    });

    it("spoil chance", async () => {
      const chances = await Promise.all([
        cellar.spoilChance(1),
        cellar.spoilChance(24),
        cellar.spoilChance(163),
        cellar.spoilChance(180),
        cellar.spoilChance(270),
        cellar.spoilChance(360),
        cellar.spoilChance(362),
        cellar.spoilChance(364),
        cellar.spoilChance(365),
        cellar.spoilChance(366),
        cellar.spoilChance(370),
      ]);

      expect(chances.map((x) => x.toString())).to.eql([
        "8600",
        "6900",
        "3000",
        "2100",
        "900",
        "500",
        "500",
        "500",
        "500",
        "500",
        "500",
      ]);
    });
  });

  describe("CouncilV1", function () {
    beforeEach(async () => {
      await deploy();
      await vineyard.newVineyards([12, 13, 4]);
      await vineyard.newVineyards([12, 13, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      await vineyard.connect(accounts[2]).newVineyards([12, 13, 4]);
      await vineyard.buySprinkler(0, { value: spCost });
      await vineyard.buySprinkler(1, { value: spCost });
      await vineyard.buySprinkler(2, { value: spCost });
      await vineyard.buySprinkler(3, { value: spCost });
      await vineyard.start();
      await vineyard.plantMultiple([0, 1, 2, 3]);

      let time = 19 * day;
      await ethers.provider.send("evm_increaseTime", [time]);

      await vineyard.harvestMultiple([0, 1]);
      await vineyard.connect(accounts[1]).harvestMultiple([2]);
      await vineyard.connect(accounts[2]).harvestMultiple([3]);
      await ethers.provider.send("evm_increaseTime", [10]);
      await ethers.provider.send("evm_mine", []);
    });

    it("suggest proposal", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      const age = await bottle.bottleAge(0);
      const tx = await vineUri.suggest(0, newCid, newAddress);

      expect(await vineUri.newArtist()).to.equal(newAddress);
      expect(await vineUri.newUri()).to.equal(newCid);
      expect(tx)
        .to.emit(vineUri, "Suggest")
        .withArgs(
          await vineUri.startTimestamp(),
          newCid,
          newAddress,
          0,
          age.add(ethers.BigNumber.from(1))
        );
    });

    it("have to use owned bottle to suggest", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;

      await expect(vineUri.suggest(2, newCid, newAddress)).to.be.revertedWith(
        "Bottle not owned"
      );
    });

    it("only open 36 hours for voting", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineUri.suggest(0, newCid, newAddress);

      await ethers.provider.send("evm_increaseTime", [36 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      await expect(vineUri.support(2)).to.be.revertedWith("Bottle not owned");
      await expect(vineUri.support(1)).to.be.revertedWith("No queue");

      await expect(vineUri.retort(2)).to.be.revertedWith("Bottle not owned");
      await expect(vineUri.retort(1)).to.be.revertedWith("No queue");
    });

    it("can re-suggest if not settled within 12 hours of passing", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineUri.suggest(0, newCid, newAddress);

      await ethers.provider.send("evm_increaseTime", [48 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      let age = await bottle.bottleAge(0);
      let tx = await vineUri.suggest(0, newCid, newAddress);
      expect(tx)
        .to.emit(vineUri, "Suggest")
        .withArgs(
          await vineUri.startTimestamp(),
          newCid,
          newAddress,
          0,
          age.add(ethers.BigNumber.from(1))
        );
    });

    it("can re-suggest if failed and 36 hours passed", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineUri.suggest(0, newCid, newAddress);
      await ethers.provider.send("evm_increaseTime", [1 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);
      await vineUri.connect(accounts[1]).retort(2);

      await ethers.provider.send("evm_increaseTime", [35 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      let age = await bottle.bottleAge(0);
      let tx = await vineUri.suggest(0, newCid, newAddress);
      expect(tx)
        .to.emit(vineUri, "Suggest")
        .withArgs(
          await vineUri.startTimestamp(),
          newCid,
          newAddress,
          0,
          age.add(ethers.BigNumber.from(1))
        );
    });

    it("can support", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineUri.suggest(0, newCid, newAddress);
      let tx = await vineUri.support(1);

      expect(tx)
        .to.emit(vineUri, "Support")
        .withArgs(await vineUri.startTimestamp(), 1, await vineUri.forVotes());
    });

    it("can't double support", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineUri.suggest(0, newCid, newAddress);
      await vineUri.support(1);
      await expect(vineUri.support(1)).to.be.revertedWith("Double vote");
    });

    it("can retort", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineUri.suggest(0, newCid, newAddress);
      let tx = await vineUri.retort(1);

      expect(tx)
        .to.emit(vineUri, "Retort")
        .withArgs(
          await vineUri.startTimestamp(),
          1,
          await vineUri.againstVotes()
        );
    });

    it("can't double retort", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineUri.suggest(0, newCid, newAddress);
      await vineUri.retort(1);
      await expect(vineUri.retort(1)).to.be.revertedWith("Double vote");
    });

    it("can complete if passes", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineUri.suggest(0, newCid, newAddress);

      await ethers.provider.send("evm_increaseTime", [36 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      let tx = await vineUri.complete();
      expect(tx)
        .to.emit(vineUri, "Complete")
        .withArgs(await vineUri.startTimestamp(), newCid, newAddress);
      expect((await vinegar.balanceOf(newAddress)).toString()).to.equal(
        "500000000000000000000"
      );
      expect(await quixotic.payouts(vineyard.address)).to.equal(newAddress);
    });

    it("9 day total cooldown if passed and settled", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineUri.suggest(0, newCid, newAddress);

      await ethers.provider.send("evm_increaseTime", [36 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      await vineUri.complete();
      await expect(vineUri.suggest(0, newCid, newAddress)).to.be.revertedWith(
        "Too soon"
      );

      await ethers.provider.send("evm_increaseTime", [180 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      let age = await bottle.bottleAge(0);
      let tx = await vineUri.suggest(0, newCid, newAddress);
      expect(tx)
        .to.emit(vineUri, "Suggest")
        .withArgs(
          await vineUri.startTimestamp(),
          newCid,
          newAddress,
          0,
          age.add(ethers.BigNumber.from(1))
        );
    });
  });

  describe.only("Alchemy + Grapes", function () {
    beforeEach(async () => {
      await deploy();
      await vineyard.newVineyards([12, 13, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      await vineyard.buySprinkler(0, { value: spCost });
      await vineyard.buySprinkler(1, { value: spCost });

      await vineyard.start();
      await vineyard.plantMultiple([0, 1]);
    });

    it("harvest grapes, proportionally to bottle failure", async () => {
      let time = 5 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      expect(await grape.balanceOf(accounts[0].address)).to.equal(0);
      await vineyard.harvestGrapes(0);
      expect(await grape.balanceOf(accounts[0].address)).to.equal(
        utils.parseEther("2380")
      );

      time = 14 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);
      await vineyard.harvestGrapes(0);
      expect(await grape.balanceOf(accounts[0].address)).to.equal(
        utils.parseEther("9047")
      );
      expect(await vineyard.harvest(0))
        .to.emit(vineyard, "HarvestFailure")
        .withArgs(0, 1);
    });

    it("harvest grapes, xp = higher yield", async () => {
      let time = 15 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      await vineyard.harvest(0);
      time = 5 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      expect(Number(await vineyard.maxGrapes(0))).to.be.greaterThan(10000);
    });

    it("vitality", async () => {
      let time = 15 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      await vineyard.harvestGrapes(0);

      time = 7 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      await vineyard.plantMultiple([0]);
      await alchemy.vitality(0);

      await vineyard.connect(accounts[1]).plantMultiple([1, 2]);
      await alchemy.connect(accounts[1]).batchSpell([1, 2], 2);
      expect(await alchemy.vitalized(0)).to.equal(2);
      expect(await alchemy.vitalized(1)).to.equal(2);
      expect(await alchemy.vitalized(2)).to.equal(2);

      time = 79 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      expect(await vineyard.xp(0)).to.equal(0);
      await vineyard.harvest(0);
      expect(await vineyard.xp(0)).to.equal(200);
    });

    it("wither and vineyard dies", async () => {
      let time = 19 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      await vineyard.harvest(0);

      await bottle.setApprovalForAll(cellar.address, true);
      await cellar.stake(0);
      // fast forward 4 planting times
      await ethers.provider.send("evm_increaseTime", [
        (4 * 12 * 7 + 4) * 86400,
      ]);
      await ethers.provider.send("evm_mine", []);
      await cellar.withdraw(0);

      expect(
        (await vinegar.balanceOf(accounts[0].address)).toString() == "0"
      ).to.equal(false);

      await vineyard.plantMultiple([0, 1]);

      expect(await vineyard.vineyardAlive(1)).to.equal(true);
      await alchemy.wither(0);
      time = 0.5 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      expect(await vineyard.vineyardAlive(0)).to.equal(true);
      time = 0.5 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);
      expect(await vineyard.vineyardAlive(0)).to.equal(false);

      await alchemy.batchSpell([1, 2], 0);
      expect((await alchemy.withered(1))[1]).to.equal(6);
      expect((await alchemy.withered(2))[1]).to.equal(6);
    });

    it("wither and block", async () => {
      let time = 19 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      await vineyard.harvest(0);
      await vineyard.connect(accounts[1]).harvestGrapes(1);

      await bottle.setApprovalForAll(cellar.address, true);
      await cellar.stake(0);
      // fast forward 4 planting times
      await ethers.provider.send("evm_increaseTime", [
        (4 * 12 * 7 + 4) * 86400,
      ]);
      await ethers.provider.send("evm_mine", []);
      await cellar.withdraw(0);

      expect(
        (await vinegar.balanceOf(accounts[0].address)).toString() == "0"
      ).to.equal(false);

      await vineyard.plantMultiple([0, 1]);

      expect(await vineyard.vineyardAlive(1)).to.equal(true);
      await alchemy.wither(1);
      time = 0.5 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);

      expect(await vineyard.vineyardAlive(1)).to.equal(true);

      await alchemy.connect(accounts[1]).defend(1);

      time = 0.5 * day;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine", []);
      expect(await vineyard.vineyardAlive(1)).to.equal(true);
    });
  });

  describe.skip("CouncilV2", function () {
    beforeEach(async () => {
      await deploy();
      await vineyard.newVineyards([12, 13, 4]);
      await vineyard.newVineyards([12, 13, 4]);
      await vineyard.connect(accounts[1]).newVineyards([12, 13, 4]);
      await vineyard.connect(accounts[2]).newVineyards([12, 13, 4]);
      await vineyard.buySprinkler(0, { value: spCost });
      await vineyard.buySprinkler(1, { value: spCost });
      await vineyard.buySprinkler(2, { value: spCost });
      await vineyard.buySprinkler(3, { value: spCost });
      await vineyard.start();
      await vineyard.plantMultiple([0, 1, 2, 3]);

      let time = 19 * day;
      await ethers.provider.send("evm_increaseTime", [time]);

      await vineyard.harvestMultiple([0, 1, 2, 3]);
      await ethers.provider.send("evm_increaseTime", [10]);
      await ethers.provider.send("evm_mine", []);

      // await vineyard.fakes(0)
      // await vineyard.fakes(100)
      // await vineyard.fakes(200)
      // await vineyard.fakes(300)
      // await vineyard.fakes(400)
      // await vineyard.fakes(500)
      // await vineyard.fakes(600)
      // await vineyard.fakes(700)
      // await vineyard.fakes(800)
      // await vineyard.fakes(900)
      // await vineyard.fakes(1000)
    });

    it("suggest proposal (vine)", async () => {
      const newCid = "ipfs://QmXmtwt2gYUNsPAGsLWyzkPQaATMWM1Q8ZkMUKfeWV5sGU";
      const newAddress = accounts[1].address;
      await vineyard.suggest(0, newCid, newAddress);
      await ethers.provider.send("evm_increaseTime", [3]);
      await vineyard.connect(accounts[1]).suggest(2, newCid, newAddress);

      await ethers.provider.send("evm_increaseTime", [7 * day]);
      await expect(vineyard.complete(accounts[0].address)).to.be.revertedWith(
        "!highest"
      );
      await vineyard.complete(accounts[1].address);
    });
  });
});
