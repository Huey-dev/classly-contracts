import { useState } from 'react';
import { Lucid } from 'lucid-cardano';
import ContractTester from './ContractTester';

export default function WalletConnect() {
  const [lucid, setLucid] = useState<Lucid | null>(null);
  const [connected, setConnected] = useState(false);
  const [address, setAddress] = useState('');

  const connectWallet = async () => {
    try {
      // @ts-ignore - Cardano object is injected by wallet
      const api = await window.cardano.nami.enable();
      const lucid = await Lucid.new(undefined, 'Preview');
      lucid.selectWallet(api);
      const address = await lucid.wallet.address();
      setLucid(lucid);
      setAddress(address);
      setConnected(true);
    } catch (err) {
      console.error('Error connecting wallet:', err);
      alert('Failed to connect wallet. Make sure Nami wallet is installed and on the testnet.');
    }
  };

  const disconnectWallet = () => {
    setConnected(false);
    setAddress('');
    setLucid(null);
  };

  return (
    <div className="p-4 max-w-2xl mx-auto mt-10 bg-white rounded-lg shadow-md">
      <h2 className="text-2xl font-bold mb-4">Classly Contracts Tester</h2>
      
      {!connected ? (
        <button
          onClick={connectWallet}
          className="w-full bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Connect Wallet
        </button>
      ) : (
        <div className="space-y-6">
          <div className="p-4 bg-gray-50 rounded-md">
            <p className="font-medium">Connected Address:</p>
            <p className="text-sm text-gray-600 break-all">{address}</p>
            <button
              onClick={disconnectWallet}
              className="mt-2 text-sm text-red-600 hover:text-red-800"
            >
              Disconnect Wallet
            </button>
          </div>

          {lucid && <ContractTester lucid={lucid} />}
        </div>
      )}
    </div>
  );
}