import { useMemo } from "react";
import type { Abi, Address } from "viem";
import { useChainId, useReadContracts } from "wagmi";
import { getReadResultValue } from "./shared/contractResults";
import {
  resolveProtocolContract,
  type ProtocolContractGetterName,
} from "./protocolContracts";

type ProtocolReadArgs<TContext> =
  | readonly unknown[]
  | ((context: TContext) => readonly unknown[] | undefined);

type ProtocolContractSpec = ProtocolContractGetterName | { abi: Abi; address: Address } | { functionContract: ProtocolContractGetterName; address: Address };

export type ProtocolReadDefinition<
  TKey extends string = string,
  TContext = void,
> = {
  key: TKey;
  contract: ProtocolContractSpec;
  functionName: string;
  args?: ProtocolReadArgs<TContext>;
};

type ProtocolReadPrimitive = bigint | boolean | string | void;

type ProtocolReadArray = readonly unknown[] | readonly Address[];

type ProtocolReadValue =
  | ProtocolReadPrimitive
  | ProtocolReadArray
  | undefined;

export type ProtocolReadsResult<TKey extends string> = Record<TKey, ProtocolReadValue>;

export type ProtocolReadsHookResult<TKey extends string> =
  ProtocolReadsResult<TKey> & {
    refetch: () => Promise<unknown>;
  };

type ResolvedProtocolReadDefinition<TKey extends string = string> = {
  key: TKey;
  contract: ProtocolContractSpec;
  functionName: string;
  args?: readonly unknown[];
};

type ProtocolReadContractConfig<TKey extends string = string> = {
  key: TKey;
  abi: Abi;
  address: Address;
  functionName: string;
  args?: readonly unknown[];
};

function isValidProtocolReadContractConfig<TKey extends string>(
  value: ProtocolReadContractConfig<TKey> | undefined,
): value is ProtocolReadContractConfig<TKey> {
  return !!value && !!value.address && value.abi.length > 0;
}

function resolveDefinitionArgs<TContext>(
  args: ProtocolReadArgs<TContext> | undefined,
  context: TContext | undefined,
) {
  if (typeof args === "function") {
    return args(context as TContext);
  }

  return args;
}

export function useProtocolReads<TKey extends string, TContext = void>(
  definitions: readonly ProtocolReadDefinition<TKey, TContext>[],
  context?: TContext,
): ProtocolReadsHookResult<TKey> {
  const chainId = useChainId();

  const resolvedDefinitions = useMemo<ResolvedProtocolReadDefinition<TKey>[]>(() => {
    return definitions.reduce<ResolvedProtocolReadDefinition<TKey>[]>((accumulator, definition) => {
      const resolvedArgs = resolveDefinitionArgs(definition.args, context);

      if (definition.args && resolvedArgs === undefined) {
        return accumulator;
      }

      accumulator.push({
        key: definition.key,
        contract: definition.contract,
        functionName: definition.functionName,
        args: resolvedArgs,
      });

      return accumulator;
    }, []);
  }, [context, definitions]);

  const contracts = useMemo<ProtocolReadContractConfig<TKey>[]>(() => {
    if (!chainId || resolvedDefinitions.length === 0) {
      return [];
    }

    const resolvedContracts = resolvedDefinitions
      .map((definition) => {
        let contract: { abi: Abi; address: Address } | undefined;

        if (typeof definition.contract === 'string') {
          contract = resolveProtocolContract(chainId, definition.contract);
        } else if ('functionContract' in definition.contract) {
          const resolved = resolveProtocolContract(chainId, definition.contract.functionContract);
          if (resolved) {
            contract = { ...resolved, address: definition.contract.address };
          }
        } else {
          contract = definition.contract;
        }

        if (!contract || !contract.address) {
          return undefined;
        }

        return {
          key: definition.key,
          ...contract,
          functionName: definition.functionName,
          args: definition.args,
        };
      })
      .filter(isValidProtocolReadContractConfig);

    return resolvedContracts as ProtocolReadContractConfig<TKey>[];
  }, [chainId, resolvedDefinitions]);

  const { data, refetch } = useReadContracts({
    allowFailure: true,
    contracts: contracts as readonly ProtocolReadContractConfig<TKey>[],
    query: {
      enabled: contracts.length > 0,
    },
  });

  const initialResult = useMemo(() => {
    return definitions.reduce((accumulator, definition) => {
      accumulator[definition.key] = undefined;
      return accumulator;
    }, {} as ProtocolReadsResult<TKey>);
  }, [definitions]);

  return useMemo(() => {
    const values = contracts.reduce((accumulator, contract, index) => {
      accumulator[contract.key] = getReadResultValue<ProtocolReadValue>(
        data?.[index],
      );
      return accumulator;
    }, { ...initialResult });

    return {
      ...values,
      refetch,
    };
  }, [contracts, data, initialResult, refetch]);
}