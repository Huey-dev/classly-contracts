import { useState } from 'react';
import { useLucid } from './useLucid';
import { lockFunds, releaseFunds, refundFunds } from '../lib/escrow';

export function useEscrow() {
  const { lucid, address } = useLucid();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const lock = async (params: LockFundsParams) => {
    setLoading(true);
    setError(null);
    try {
      const txHash = await lockFunds({ lucid, address, ...params });
      return txHash;
    } catch (err: any) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  return { lock, loading, error };
}