// ========================================
// DEPLOY CONTRACTS TO PREVIEW TESTNET
// scripts/deploy-to-preview.ts (FIXED)
// ========================================
import dotenv from 'dotenv';
import { Blockfrost, Lucid, SpendingValidator, MintingPolicy } from 'lucid-cardano';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// Load environment variables from .env file
dotenv.config();

// Get __dirname equivalent in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ========================================
// CONFIGURATION
// ========================================

const BLOCKFROST_API_KEY = process.env.BLOCKFROST_API_KEY || 'previewKUaiMRZxiqtQZRA2nCzCT9ffPeOjDyBS';
const NETWORK = 'Preview';
// console.log(BLOCKFROST_API_KEY);
// ========================================
// MAIN DEPLOYMENT FUNCTION
// ========================================

async function deployContracts() {
  console.log('🚀 Starting contract deployment to Preview testnet...\n');

  try {
    // Step 1: Validate Blockfrost API Key
    console.log(BLOCKFROST_API_KEY);

    // To this:
    if (!BLOCKFROST_API_KEY) {
      throw new Error('BLOCKFROST_API_KEY is not set in environment variables');
    }


    // if (!BLOCKFROST_API_KEY || BLOCKFROST_API_KEY === 'previewKUaiMRZxiqtQZRA2nCzCT9ffPeOjDyBS') {
    //   throw new Error('Please set BLOCKFROST_API_KEY environment variable');
    // }

    // Step 2: Initialize Lucid
    console.log('1️⃣ Initializing Lucid...');
    const lucid = await Lucid.new(
      new Blockfrost(
        `https://cardano-preview.blockfrost.io/api/v0`,
        BLOCKFROST_API_KEY
      ),
      NETWORK
    );
    console.log('   ✅ Lucid initialized\n');

    // Step 3: Load plutus.json
    console.log('2️⃣ Loading plutus.json...');
    const plutusJsonPath = path.join(__dirname, '../smart-contracts/plutus.json');
    
    if (!fs.existsSync(plutusJsonPath)) {
      throw new Error(`plutus.json not found at: ${plutusJsonPath}\nPlease run 'aiken build' in smart-contracts directory`);
    }
    
    const plutusJson = JSON.parse(fs.readFileSync(plutusJsonPath, 'utf8'));
    console.log(`   ✅ Loaded ${plutusJson.validators.length} validators\n`);

    // Step 4: Extract validators
    console.log('3️⃣ Extracting validators...');

    // Log all validator titles for debugging
    console.log('Available validators:');
    plutusJson.validators.forEach((v: any) => console.log(`  - ${v.title}`));
    console.log('');

    const escrowValidator = plutusJson.validators.find(
      (v: any) => v.title === 'escrow.escrow_validator.spend'
    );

    const nftPolicy = plutusJson.validators.find(
      (v: any) => v.title === 'classroom_nft.classroom_nft_policy.mint'
    );

    const reputationValidator = plutusJson.validators.find(
      (v: any) => v.title === 'reputation.reputation_validator.spend'
    );

    if (!escrowValidator) {
      throw new Error('❌ Escrow validator not found in plutus.json');
    }
    if (!nftPolicy) {
      throw new Error('❌ NFT policy not found in plutus.json');
    }
    if (!reputationValidator) {
      throw new Error('❌ Reputation validator not found in plutus.json');
    }

    console.log('   ✅ All validators found\n');

    // Step 5: Calculate addresses
    console.log('4️⃣ Calculating contract addresses...\n');

    // Escrow address
    const escrowScript: SpendingValidator = {
      type: 'PlutusV2',
      script: escrowValidator.compiledCode,
    };
    const escrowAddress = lucid.utils.validatorToAddress(escrowScript);

    console.log('📜 Escrow Contract:');
    console.log(`   Address: ${escrowAddress}`);
    console.log(`   Hash: ${escrowValidator.hash}\n`);

    // NFT policy
    const nftScript: MintingPolicy = {
      type: 'PlutusV2',
      script: nftPolicy.compiledCode,
    };
    const nftPolicyId = lucid.utils.mintingPolicyToId(nftScript);

    console.log('🎨 NFT Minting Policy:');
    console.log(`   Policy ID: ${nftPolicyId}`);
    console.log(`   Hash: ${nftPolicy.hash}\n`);

    // Reputation address
    const reputationScript: SpendingValidator = {
      type: 'PlutusV2',
      script: reputationValidator.compiledCode,
    };
    const reputationAddress = lucid.utils.validatorToAddress(reputationScript);

    console.log('⭐ Reputation Contract:');
    console.log(`   Address: ${reputationAddress}`);
    console.log(`   Hash: ${reputationValidator.hash}\n`);

    // Step 6: Save configuration
    console.log('5️⃣ Saving contract configuration...');

    const config = {
      network: NETWORK,
      deployedAt: new Date().toISOString(),
      contracts: {
        escrow: {
          address: escrowAddress,
          hash: escrowValidator.hash,
          script: escrowValidator.compiledCode,
        },
        nft: {
          policyId: nftPolicyId,
          hash: nftPolicy.hash,
          script: nftPolicy.compiledCode,
        },
        reputation: {
          address: reputationAddress,
          hash: reputationValidator.hash,
          script: reputationValidator.compiledCode,
        },
      },
    };

    const configPath = path.join(__dirname, 'contract-addresses.json');
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    console.log(`   ✅ Saved to: ${configPath}\n`);

    // Step 7: Generate .env file for frontend
    console.log('6️⃣ Generating .env file for frontend...');

    const envContent = `# Generated by deploy-to-preview.ts on ${new Date().toISOString()}
VITE_BLOCKFROST_API_KEY=${BLOCKFROST_API_KEY}
VITE_NETWORK=${NETWORK}
VITE_ESCROW_ADDRESS=${escrowAddress}
VITE_NFT_POLICY_ID=${nftPolicyId}
VITE_REPUTATION_ADDRESS=${reputationAddress}
`;

    const frontendDir = path.join(__dirname, '../frontend');
    if (!fs.existsSync(frontendDir)) {
      fs.mkdirSync(frontendDir, { recursive: true });
    }

    const envPath = path.join(frontendDir, '.env');
    fs.writeFileSync(envPath, envContent);
    console.log(`   ✅ Saved to: ${envPath}\n`);

    // Step 8: Display CardanoScan links
    console.log('7️⃣ Explorer links:\n');
    console.log(`📍 Escrow: https://preview.cardanoscan.io/address/${escrowAddress}`);
    console.log(`📍 NFT Policy: https://preview.cardanoscan.io/tokenPolicy/${nftPolicyId}`);
    console.log(`📍 Reputation: https://preview.cardanoscan.io/address/${reputationAddress}\n`);

    // Success summary
    console.log('🎉 DEPLOYMENT COMPLETE!\n');
    console.log('Next steps:');
    console.log('1. ✅ Contract addresses saved to contract-addresses.json');
    console.log('2. ✅ Frontend .env file created');
    console.log('3. 📋 Copy plutus.json: cp ../smart-contracts/plutus.json ../frontend/');
    console.log('4. 🚀 Start frontend: cd ../frontend && npm run dev\n');

    return config;
  } catch (error: any) {
    console.error('\n❌ Deployment failed:', error.message);
    
    if (error.message.includes('Blockfrost')) {
      console.error('\n💡 Tip: Check your Blockfrost API key is correct and for Preview network');
    }
    if (error.message.includes('plutus.json')) {
      console.error('\n💡 Tip: Run "cd ../smart-contracts && aiken build" first');
    }
    
    process.exit(1);
  }
}

// ========================================
// RUN DEPLOYMENT
// ========================================

deployContracts().catch(console.error);