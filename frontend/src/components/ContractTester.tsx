import { useState } from 'react';
import { mintNFT } from '../lib/nft';

export default function ContractTester({ lucid }: { lucid: any }) {
  const [classroomId, setClassroomId] = useState('');
  const [teacherAddress, setTeacherAddress] = useState('');
  const [status, setStatus] = useState('');

  const handleMint = async () => {
    if (!classroomId || !teacherAddress) {
      setStatus('Please fill in all fields');
      return;
    }

    setStatus('Minting NFT...');
    const result = await mintNFT(lucid, teacherAddress, classroomId);
    
    if (result.success) {
      setStatus(`NFT minted successfully! Tx Hash: ${result.txHash}`);
    } else {
      setStatus(`Error: ${result.error}`);
    }
  };

  return (
    <div className="mt-8 p-4 bg-white rounded-lg shadow-md">
      <h3 className="text-lg font-semibold mb-4">Test NFT Contract</h3>
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">Teacher Address</label>
          <input
            type="text"
            value={teacherAddress}
            onChange={(e) => setTeacherAddress(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            placeholder="Enter teacher address"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Classroom ID</label>
          <input
            type="text"
            value={classroomId}
            onChange={(e) => setClassroomId(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            placeholder="Enter classroom ID"
          />
        </div>
        <button
          onClick={handleMint}
          disabled={!classroomId || !teacherAddress}
          className={`px-4 py-2 rounded-md text-white ${
            (classroomId && teacherAddress) 
              ? 'bg-indigo-600 hover:bg-indigo-700' 
              : 'bg-gray-400 cursor-not-allowed'
          }`}
        >
          Mint Test NFT
        </button>
        {status && (
          <div className="mt-4 p-3 bg-blue-50 text-blue-700 rounded-md">
            {status}
          </div>
        )}
      </div>
    </div>
  );
}