// ========================================
// TEST APP
// frontend/src/App.tsx
// Simple test to verify deployment
// ========================================

import { useState, useEffect } from 'react';
import { Lucid, Address } from 'lucid-cardano';
import { initLucid, connectWallet, getWalletBalance, isWalletInstalled } from './lib/lucid';
import { getAllContractAddresses } from './lib/contracts';
import { mintClassroomNFT, selectUniqueUtxo } from './lib/nft';
import { initializeReputation } from './lib/reputation';

function App() {
  const [lucid, setLucid] = useState<Lucid | null>(null);
  const [address, setAddress] = useState<Address | null>(null);
  const [balance, setBalance] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState('');
  const [contracts, setContracts] = useState<any>(null);

  // Initialize Lucid on mount
  useEffect(() => {
    initLucid().then(l => {
      setLucid(l);
      const addrs = getAllContractAddresses(l);
      setContracts(addrs);
      setStatus('✅ Lucid initialized!!');
    }).catch(err => {
      setStatus('❌ Failed to initialize: ' + err.message);
    });
  }, []);

  // Connect wallet
  const handleConnect = async (walletName: 'nami' | 'eternl' | 'flint') => {
    if (!lucid) {
      setStatus('❌ Lucid not initialized');
      return;
    }

    setLoading(true);
    try {
      const addr = await connectWallet(lucid, walletName);
      setAddress(addr);
      
      const bal = await getWalletBalance(lucid);
      setBalance((Number(bal.lovelace) / 1_000_000).toFixed(2));
      
      setStatus(`✅ Connected to ${walletName}`);
    } catch (err: any) {
      setStatus('❌ Connection failed: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  // Test NFT minting
  const handleMintNFT = async () => {
    if (!lucid || !address) {
      setStatus('❌ Connect wallet first');
      return;
    }

    setLoading(true);
    setStatus('🎨 Minting NFT...');

    try {
      const utxo = await selectUniqueUtxo(lucid);
      
      const result = await mintClassroomNFT({
        lucid,
        teacherAddress: address,
        classroomId: 'TEST_' + Date.now(),
        oneTimeUtxo: utxo,
      });

      await lucid.awaitTx(result.txHash);
      
      setStatus(`✅ NFT Minted! TxHash: ${result.txHash.slice(0, 20)}...`);
    } catch (err: any) {
      setStatus('❌ Minting failed: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  // Test reputation initialization
  const handleInitReputation = async () => {
    if (!lucid || !address) {
      setStatus('❌ Connect wallet first');
      return;
    }

    setLoading(true);
    setStatus('⭐ Initializing reputation...');

    try {
      const txHash = await initializeReputation({
        lucid,
        teacherAddress: address,
      });

      await lucid.awaitTx(txHash);
      
      setStatus(`✅ Reputation initialized! TxHash: ${txHash.slice(0, 20)}...`);
    } catch (err: any) {
      setStatus('❌ Initialization failed: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #667eea 0%, #01378fff 100%)',
      padding: '20px',
      fontFamily: 'system-ui, -apple-system, sans-serif',
    }}>
      <div style={{
        maxWidth: '800px',
        margin: '0 auto',
        background: 'white',
        borderRadius: '16px',
        padding: '32px',
        boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
      }}>
        <h1 style={{
          fontSize: '2.5rem',
          marginBottom: '8px',
          color: '#667eea',
        }}>
          🎓 Classly Contracts Project
        </h1>
        <p style={{ color: '#666', marginBottom: '32px' }}>
          Preview Testnet Deployment Test
        </p>

        {/* Status */}
        <div style={{
          padding: '16px',
          background: '#f0f0f0',
          borderRadius: '8px',
          marginBottom: '24px',
          fontFamily: 'monospace',
        }}>
          {status || 'Initializing...'}
        </div>

        {/* Contract Info */}
        {contracts && (
          <div style={{
            padding: '16px',
            background: '#f9f9f9',
            borderRadius: '8px',
            marginBottom: '24px',
            fontSize: '14px',
          }}>
            <h3 style={{ marginTop: 0 }}>📜 Contract Addresses:</h3>
            <p style={{ wordBreak: 'break-all', margin: '8px 0' }}>
              <strong>Escrow:</strong><br />
              <code>{contracts.escrowAddress}</code>
            </p>
            <p style={{ wordBreak: 'break-all', margin: '8px 0' }}>
              <strong>NFT Policy:</strong><br />
              <code>{contracts.nftPolicyId}</code>
            </p>
            <p style={{ wordBreak: 'break-all', margin: '8px 0' }}>
              <strong>Reputation:</strong><br />
              <code>{contracts.reputationAddress}</code>
            </p>
          </div>
        )}

        {/* Wallet Connection */}
        {!address ? (
          <div>
            <h3>1. Connect Wallet</h3>
            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
              {isWalletInstalled('nami') && (
                <button
                  onClick={() => handleConnect('nami')}
                  disabled={loading}
                  style={buttonStyle}
                >
                  Connect Nami
                </button>
              )}
              {isWalletInstalled('eternl') && (
                <button
                  onClick={() => handleConnect('eternl')}
                  disabled={loading}
                  style={buttonStyle}
                >
                  Connect Eternl
                </button>
              )}
              {isWalletInstalled('lace') && (
                <button
                  onClick={() => handleConnect('lace')}
                  disabled={loading}
                  style={buttonStyle}
                >
                  Connect Lace
                </button>
              )}
            </div>
          </div>
        ) : (
          <div>
            {/* Wallet Info */}
            <div style={{
              padding: '16px',
              background: '#e8f5e9',
              borderRadius: '8px',
              marginBottom: '24px',
            }}>
              <h3 style={{ marginTop: 0 }}>👛 Wallet Connected</h3>
              <p style={{ margin: '8px 0', wordBreak: 'break-all' }}>
                <strong>Address:</strong><br />
                {address}
              </p>
              <p style={{ margin: '8px 0' }}>
                <strong>Balance:</strong> {balance} ADA
              </p>
            </div>

            {/* Test Actions */}
            <h3>2. Test Contract Functions</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <button
                onClick={handleMintNFT}
                disabled={loading}
                style={buttonStyle}
              >
                Test: Mint Classroom NFT
              </button>
              
              <button
                onClick={handleInitReputation}
                disabled={loading}
                style={buttonStyle}
              >
                Test: Initialize Reputation
              </button>

              <button
                onClick={() => setAddress(null)}
                style={{...buttonStyle, background: '#f44336'}}
              >
                Disconnect Wallet
              </button>
            </div>
          </div>
        )}

        {/* Loading Indicator */}
        {loading && (
          <div style={{
            marginTop: '24px',
            textAlign: 'center',
            color: '#667eea',
          }}>
            <div style={{
              display: 'inline-block',
              width: '40px',
              height: '40px',
              border: '4px solid #f3f3f3',
              borderTop: '4px solid #667eea',
              borderRadius: '50%',
              animation: 'spin 1s linear infinite',
            }} />
            <style>{`
              @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
              }
            `}</style>
          </div>
        )}

        {/* Footer */}
        <div style={{
          marginTop: '48px',
          paddingTop: '24px',
          borderTop: '1px solid #e0e0e0',
          fontSize: '14px',
          color: '#666',
          textAlign: 'center',
        }}>
          <p>🌐 Preview Testnet</p>
          <p>
            View on <a
              href="https://preview.cardanoscan.io"
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: '#667eea' }}
            >
              CardanoScan
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}

const buttonStyle: React.CSSProperties = {
  padding: '12px 24px',
  background: '#667eea',
  color: 'white',
  border: 'none',
  borderRadius: '8px',
  fontSize: '16px',
  cursor: 'pointer',
  transition: 'all 0.3s',
  fontWeight: '500',
};

export default App;