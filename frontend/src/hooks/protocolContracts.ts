import type { Abi, Address } from "viem";
import {
  getDaoGovernorContract,
  getGenesisBondingContract,
  getGovernanceTokenContract,
  getGuardianAdministratorContract,
  getGuardianBondEscrowContract,
  getProtocolCoreContract,
  getRiskManagerContract,
  getTreasuryContract,
  getVaultRegistryContract,
  getVaultImplementationContract,
} from "@dao/contracts-sdk";
import { getVaultFactoryContract } from "./getVaultFactoryContract";

export const protocolContractGetters = {
  getGenesisBondingContract,
  getProtocolCoreContract,
  getVaultRegistryContract,
  getTreasuryContract,
  getDaoGovernorContract,
  getRiskManagerContract,
  getGovernanceTokenContract,
  getGuardianAdministratorContract,
  getGuardianBondEscrowContract,
  getVaultFactoryContract,
  getVaultImplementationContract,
} as const;

export type ProtocolContractGetterName = keyof typeof protocolContractGetters;

export type ResolvedProtocolContract = {
  abi: Abi;
  address: Address;
};

export function resolveProtocolContract(
  chainId: number,
  getterName: ProtocolContractGetterName,
): ResolvedProtocolContract | undefined {
  try {
    const contract = protocolContractGetters[getterName](chainId);
    const address = contract?.address as Address | undefined;
    const abi = contract?.abi as Abi | undefined;

    if (!address || !abi?.length) {
      return undefined;
    }

    return {
      abi,
      address,
    };
  } catch {
    return undefined;
  }
}