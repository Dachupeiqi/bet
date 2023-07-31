import crypto from 'crypto';
import * as dotenv from 'dotenv';
dotenv.config();

// 设置 Vault 服务器地址和访问令牌
const vaultUrl: any = process.env.vaultUrl;
const vaultToken: any = process.env.vaultToken;

export const storeKeyPairData = async (key: any, keyPair: any) => {
  // 使用 Vault API 存储数据
  const response = await fetch(`${vaultUrl}/v1/secret/data/${key}`, {
    method: 'POST',
    headers: {
      'X-Vault-Token': vaultToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      data: keyPair,
    }),
  });

  if (!response.ok) {
    throw new Error('Failed to store data in Vault');
  }

  console.log('Data successfully stored in Vault.');
}

export const getKeyPairData = async (key:any) => {
  // 使用 Vault API 获取数据
  const response = await fetch(`${vaultUrl}/v1/secret/data/${key}`, {
    headers: {
      'X-Vault-Token': vaultToken,
    },
  });

  if (!response.ok) {
    throw new Error('Failed to get data from Vault');
  }
  const data = await response.json();
  return data.data.data;
}

export const generateKeyPair = async () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  const publicKeyPem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
  const privateKeyPem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();

  return {
    publicKey: publicKeyPem,
    privateKey: privateKeyPem,
  };
}
