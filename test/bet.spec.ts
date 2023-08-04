import { expect } from "chai";
import { ethers } from "hardhat";
import crypto from 'crypto';
import { BetPlatform, BetFundPool, MyErc20 } from "../typechain-types"
import type { RoomDataParamStruct, } from "../typechain-types/contracts/BetPlatform"
import BetFundPoolJson from "../artifacts/contracts/BetFundPool.sol/BetFundPool.json"
import BetPlatformJson from "../artifacts/contracts/BetPlatform.sol/BetPlatform.json"
import { Wallet } from "ethers";
import * as dotenv from 'dotenv';
dotenv.config();
import { generateKeyPair, getKeyPairData, storeKeyPairData } from './vault'
import { log } from "console";

describe(`test bet`, async function () {
  let betPlatform: BetPlatform;
  let betFundPool: BetFundPool;
  let owner: any;
  let myErc20: MyErc20;
  let betAccount: any
  let betAccount1: any
  let betAccount2: any


  beforeEach(async () => {

    const [signer, account1, account2, account3] = await ethers.getSigners();
    owner = signer;
    betAccount = account1
    betAccount1 = account2
    betAccount2 = account3

    let BetPlatform = (await ethers.getContractFactory("BetPlatform"));
    betPlatform = await BetPlatform.deploy();
    await betPlatform.deployed()
    const betFundPoolAddress = await betPlatform.betFundPool();

    let MyErc20 = (await ethers.getContractFactory("MyErc20"));
    myErc20 = await MyErc20.deploy();
    await myErc20.deployed()

    await myErc20.connect(betAccount).mint(betAccount.address, 100);

    await myErc20.connect(betAccount1).mint(betAccount1.address, 100);

    betFundPool = new ethers.Contract(betFundPoolAddress, BetFundPoolJson.abi).connect(owner) as unknown as BetFundPool;
  });

  it("test", async () => {

    await myErc20.connect(betAccount).approve(betFundPool.address, 10);

    await betFundPool.connect(betAccount).deposit(myErc20.address, 10);

    await myErc20.connect(betAccount1).approve(betFundPool.address, 10);

    await betFundPool.connect(betAccount1).deposit(myErc20.address, 10);

    const betParam: RoomDataParamStruct = {
      betToken: myErc20.address,
      betPrice: 1,
      startTime: Math.round(Date.now() / 1000) - 20,
      endTime: Math.round(Date.now() / 1000) + 20
    }
    // 生成 RSA 密钥对
    const keyPair = await generateKeyPair();

    let betData = [0, 1, 2, 1, 0];
    let betData1 = [0, 1, 2, 1, 1]

    let publicKeyStr = keyPair.publicKey;
    const publicKey = crypto.createPublicKey(publicKeyStr);

    let privateKeyStr = keyPair.privateKey;
    const privateKey = crypto.createPrivateKey(privateKeyStr);

    let betEncryptedData = crypto.publicEncrypt(publicKey, Buffer.from(JSON.stringify(betData)));
    let betEncryptedData1 = crypto.publicEncrypt(publicKey, Buffer.from(JSON.stringify(betData1)));

    console.log("betEncryptedData1",betEncryptedData);
    console.log("betEncryptedData2",betEncryptedData1);
    
    console.log("========");
    
    let storeCustomStrategy = await betPlatform.connect(betAccount).storeCustomStrategy(betEncryptedData);
    let storeCustomStrategy1 = await betPlatform.connect(betAccount1).storeCustomStrategy(betEncryptedData1);

    console.log("storeCustomStrategy",storeCustomStrategy);
    console.log("storeCustomStrategy",storeCustomStrategy1);
    
    let getCustomStrategy = await betPlatform.connect(betAccount).getCustomStrategy(0);
    let getCustomStrategy1 = await betPlatform.connect(betAccount1).getCustomStrategy(0);

    console.log("getCustomStrategy",getCustomStrategy);
    console.log("getCustomStrategy1",getCustomStrategy1);

    let createBetReceipt = await betPlatform.connect(betAccount).createRoom(betParam, getCustomStrategy[1]);

    createBetReceipt = await createBetReceipt.wait()

    const roomId = (await createBetReceipt.events.filter((item: any) => item.event == "RoomCreated"))[0].args[0]

    await storeKeyPairData(roomId, keyPair);


    await betPlatform.connect(betAccount1).bet(roomId, getCustomStrategy1[1]);

    console.log("betEncryptedData",betEncryptedData);
    

    console.log("betAccount0:", betAccount.address)
    console.log("betAccount1:", betAccount1.address)

    let flag = true;

    while (flag) {
      const roomIds: any = await betPlatform.getRoomIds();
      console.log("roomIds:", roomIds.length)
      console.log("start:", new Date().toLocaleString())

      

      for (const roomId of roomIds) {
        const roomData: any = await betPlatform.getRoomData(roomId);
        if (roomData.status == 0) {
          const endTime = roomData.endTime;
          if (endTime < Math.round(Date.now() / 1000)) {
            const keyPair = await getKeyPairData(roomId);
            let privateKeyStr = keyPair.privateKey;
            const privateKey = crypto.createPrivateKey(privateKeyStr);
            const betEncryptedData = await betPlatform.connect(betAccount).getBetDatas(roomId);
            let betDatas = [];
            for (const encryptedData of betEncryptedData) {
              let betData: any = crypto.privateDecrypt(privateKey, Buffer.from(encryptedData.data.slice(2), 'hex'));
              betData = JSON.parse(betData)
              betDatas.push(betData)
            }
            await betPlatform.connect(owner).decodeBetDatas(roomId, betDatas);

            await betPlatform.connect(owner).settlement(roomId);  // 在处理完此房间之后，标记它为已处理

            console.log("1-------========");
            
            console.log("data is :",await betPlatform.getRoomData(roomId))
            flag = false;
          }
        }
      }
   
      await new Promise(resolve => setTimeout(resolve, 1000))
     
    }
    const betAccountBalance = await betFundPool.connect(betAccount).getUserTokenBalance(betAccount.address, myErc20.address)
    const betAccount1Balance = await betFundPool.connect(betAccount1).getUserTokenBalance(betAccount1.address, myErc20.address)

    console.log("==-==资金池=====");
    console.log("bet account balance:", betAccountBalance)
    console.log("bet account 1 balance:", betAccount1Balance)

    console.log("==-==结算前=====");
    console.log("bet account balance:", await myErc20.balanceOf(betAccount.address))
    console.log("bet account1 balance:", await myErc20.balanceOf(betAccount1.address))

    await betFundPool.connect(betAccount).withdraw(myErc20.address, betAccountBalance)
    await betFundPool.connect(betAccount1).withdraw(myErc20.address, betAccount1Balance)
    console.log("==-==结算后=====");

    console.log("bet account balance:", await myErc20.balanceOf(betAccount.address))
    console.log("bet account1 balance:", await myErc20.balanceOf(betAccount1.address))

    console.log("========资金流水=======");
    
    const getUser1TokenFundFlowRecords = await betFundPool.connect(betAccount).getUserTokenFundFlowRecords(betAccount.address)
    const getUser2TokenFundFlowRecords = await betFundPool.connect(betAccount1).getUserTokenFundFlowRecords(betAccount1.address)
    console.log("getUser1TokenFundFlowRecords:",getUser1TokenFundFlowRecords);
    console.log("========================");
    console.log("getUser2TokenFundFlowRecords:",getUser2TokenFundFlowRecords);

    
    
  })
});
