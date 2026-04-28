import {
  getDaoGovernorContract,
  getProtocolCoreContract,
  getTreasuryContract,
} from "@dao/contracts-sdk";
import { useCallback, useMemo, useState } from "react";
import Swal from "sweetalert2";
import { useChainId, useReadContracts } from "wagmi";
import { encodeFunctionData, parseEventLogs, type Address } from "viem";
import type {
  InfrastructureWiring,
  OperationsModel,
  OperationsStatus,
} from "@/types/models/operations";
import { getKnownProtocolAssets } from "@/constants/protocolAssets";
import {
  formatAddress,
  getTransactionError,
  isValidAddress,
  saveProposalMetadata,
} from "@/utils";
import { useProtocolCapabilities } from "./useProtocolCapabilities";
import { getVaultFactoryContract } from "./getVaultFactoryContract";
import {
  getReadContractResult,
  ZERO_ADDRESS,
} from "./shared/contractResults";
import { resolveOptionalContract } from "./shared/resolveContract";
import { useProtocolReads } from "./useProtocolReads";
import useWriteContracts from "./useWriteContracts";

export function useOperationsModel(): OperationsModel {
  const chainId = useChainId();
  const capabilities = useProtocolCapabilities();
  const { executeWrite } = useWriteContracts();
  const knownAssets = useMemo(() => getKnownProtocolAssets(chainId), [chainId]);
  const [supportedVaultAsset, setSupportedVaultAsset] = useState("");
  const [supportedGenesisToken, setSupportedGenesisToken] = useState("");
  const [factoryRouterInput, setFactoryRouterInput] = useState("");
  const [factoryCoreInput, setFactoryCoreInput] = useState("");
  const [guardianAdministratorInput, setGuardianAdministratorInput] =
    useState("");
  const [vaultRegistryInput, setVaultRegistryInput] = useState("");
  const [treasuryProtocolCoreInput, setTreasuryProtocolCoreInput] =
    useState("");
  const {
    isVaultCreationPaused,
    isDepositsPaused,
    assetsSupported,
    refetch,
  } = useProtocolReads([
    {
      key: "isVaultCreationPaused",
      contract: "getProtocolCoreContract",
      functionName: "isVaultCreationPaused",
    },
    {
      key: "isDepositsPaused",
      contract: "getProtocolCoreContract",
      functionName: "isVaultDepositsPaused",
    },
    {
      key: "assetsSupported",
      contract: "getProtocolCoreContract",
      functionName: "getSupportedGenesisTokens",
    },
  ]);

  const vaultFactoryConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getVaultFactoryContract);
  }, [chainId]);

  const protocolCoreConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getProtocolCoreContract);
  }, [chainId]);

  const treasuryConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getTreasuryContract);
  }, [chainId]);

  const governorConfig = useMemo(
    () => resolveOptionalContract(chainId, getDaoGovernorContract),
    [chainId],
  );

  const { data: wiringData } = useReadContracts({
    allowFailure: true,
    contracts: [
      ...(vaultFactoryConfig
        ? [
            {
              abi: vaultFactoryConfig.abi,
              address: vaultFactoryConfig.address,
              functionName: "router" as const,
            },
            {
              abi: vaultFactoryConfig.abi,
              address: vaultFactoryConfig.address,
              functionName: "core" as const,
            },
            {
              abi: vaultFactoryConfig.abi,
              address: vaultFactoryConfig.address,
              functionName: "guardianAdministrator" as const,
            },
            {
              abi: vaultFactoryConfig.abi,
              address: vaultFactoryConfig.address,
              functionName: "vaultRegistry" as const,
            },
          ]
        : []),
      ...(treasuryConfig
        ? [
            {
              abi: treasuryConfig.abi,
              address: treasuryConfig.address,
              functionName: "protocolCore" as const,
            },
          ]
        : []),
    ],
    query: {
      enabled: Boolean(vaultFactoryConfig || treasuryConfig),
    },
  });

  const { data: supportedVaultAssetsData } = useReadContracts({
    allowFailure: true,
    contracts:
      protocolCoreConfig && knownAssets.length > 0
        ? knownAssets.map((asset) => ({
            abi: protocolCoreConfig.abi,
            address: protocolCoreConfig.address,
            functionName: "isVaultAssetSupported" as const,
            args: [asset.address],
          }))
        : [],
    query: {
      enabled: Boolean(protocolCoreConfig) && knownAssets.length > 0,
    },
  });

  const supportedVaultAssetsCount = useMemo(() => {
    return (supportedVaultAssetsData ?? []).filter(
      (result) => getReadContractResult<boolean>(result) === true,
    ).length;
  }, [supportedVaultAssetsData]);

  const supportedGenesisTokensList = useMemo(
    () => {
      const tokens = ((assetsSupported as readonly string[] | undefined) ??
        []) as string[];

      return tokens.filter(
        (token, index, self) =>
          self.findIndex(
            (candidate) => candidate.toLowerCase() === token.toLowerCase(),
          ) === index,
      );
    },
    [assetsSupported],
  );

  const supportedGenesisTokenCount = supportedGenesisTokensList.length;

  const supportedVaultAssetError =
    supportedVaultAsset.trim() !== "" &&
    !isValidAddress(supportedVaultAsset.trim())
      ? "Enter a valid asset address."
      : undefined;
  const supportedGenesisTokenError =
    supportedGenesisToken.trim() !== "" &&
    !isValidAddress(supportedGenesisToken.trim())
      ? "Enter a valid token address."
      : undefined;
  const factoryRouterError =
    factoryRouterInput.trim() !== "" &&
    !isValidAddress(factoryRouterInput.trim())
      ? "Enter a valid router contract address."
      : undefined;
  const factoryCoreError =
    factoryCoreInput.trim() !== "" && !isValidAddress(factoryCoreInput.trim())
      ? "Enter a valid core contract address."
      : undefined;
  const guardianAdministratorError =
    guardianAdministratorInput.trim() !== "" &&
    !isValidAddress(guardianAdministratorInput.trim())
      ? "Enter a valid guardian administrator address."
      : undefined;
  const vaultRegistryError =
    vaultRegistryInput.trim() !== "" && !isValidAddress(vaultRegistryInput.trim())
      ? "Enter a valid vault registry address."
      : undefined;
  const treasuryProtocolCoreError =
    treasuryProtocolCoreInput.trim() !== "" &&
    !isValidAddress(treasuryProtocolCoreInput.trim())
      ? "Enter a valid ProtocolCore address."
      : undefined;

  const canSubmitFactoryRouter =
    capabilities.canCreateProposal &&
    isValidAddress(factoryRouterInput.trim());
  const canSubmitFactoryCore =
    capabilities.canCreateProposal && isValidAddress(factoryCoreInput.trim());
  const canSubmitGuardianAdministrator =
    capabilities.canCreateProposal &&
    isValidAddress(guardianAdministratorInput.trim());
  const canSubmitVaultRegistry =
    capabilities.canCreateProposal && isValidAddress(vaultRegistryInput.trim());
  const canSubmitTreasuryProtocolCore =
    capabilities.canCreateProposal &&
    isValidAddress(treasuryProtocolCoreInput.trim());

  const proposalPermissionMessage = !capabilities.canCreateProposal
    ? "Governance voting power is required to submit proposal-based changes."
    : undefined;

  const executeOperation = useCallback(
    async (
      title: string,
      params: Parameters<typeof executeWrite>[0],
      onSuccess?: () => void | Promise<void>,
    ) => {
      Swal.fire({
        title,
        text: "Confirm the transaction in your wallet.",
        allowOutsideClick: false,
        allowEscapeKey: false,
        showConfirmButton: false,
        didOpen: () => {
          Swal.showLoading();
        },
      });

      try {
        const response = await executeWrite({
          ...params,
          options: {
            waitForReceipt: true,
          },
        });

        if (response?.receipt?.status !== "success") {
          throw new Error("Transaction failed.");
        }

        await refetch();
        await onSuccess?.();
        Swal.close();

        await Swal.fire({
          title: "Operation completed",
          text: "Protocol state was updated successfully.",
          icon: "success",
          confirmButtonText: "OK",
        });
      } catch (error) {
        const transactionError = getTransactionError(error);

        Swal.hideLoading();
        Swal.update({
          title: transactionError.title,
          text: transactionError.message,
          icon: "error",
          showConfirmButton: true,
          confirmButtonText: "OK",
          allowOutsideClick: true,
          allowEscapeKey: true,
        });
      }
    },
    [executeWrite, refetch],
  );

  const createGovernanceProposal = useCallback(
    async (
      title: string,
      description: string,
      target: Address,
      abi: readonly unknown[],
      functionName: string,
      args: readonly unknown[] = [],
    ) => {
      if (!governorConfig) {
        throw new Error("Governance contract unavailable.");
      }

      const calldata = encodeFunctionData({
        abi,
        functionName,
        args,
      }) as `0x${string}`;

      const proposalTitle = title.trim();
      const proposalDescription = [proposalTitle, description.trim()]
        .filter(Boolean)
        .join("\n\n");

      Swal.fire({
        title,
        text: "Confirm the proposal transaction in your wallet.",
        allowOutsideClick: false,
        allowEscapeKey: false,
        showConfirmButton: false,
        didOpen: () => {
          Swal.showLoading();
        },
      });

      try {
        const response = await executeWrite({
          functionContract: "getDaoGovernorContract",
          functionName: "propose",
          args: [[target], [0n], [calldata], proposalDescription],
          options: {
            waitForReceipt: true,
          },
        });

        if (response?.receipt?.status !== "success") {
          throw new Error("Proposal submission failed.");
        }

        const proposalCreatedEvent = parseEventLogs({
          abi: governorConfig.abi,
          logs: response.receipt?.logs ?? [],
          eventName: "ProposalCreated",
        })?.[0];
        const proposalId = proposalCreatedEvent?.args?.proposalId?.toString();

        if (proposalId) {
          saveProposalMetadata(chainId, {
            proposalId,
            title: proposalTitle,
            description: description.trim(),
            composedDescription: proposalDescription,
          });
        }

        await refetch();
        Swal.close();

        await Swal.fire({
          title: "Proposal submitted",
          text: "A governance proposal was created successfully.",
          icon: "success",
          confirmButtonText: "OK",
        });
      } catch (error) {
        const transactionError = getTransactionError(error);

        Swal.hideLoading();
        Swal.update({
          title: transactionError.title,
          text: transactionError.message,
          icon: "error",
          showConfirmButton: true,
          confirmButtonText: "OK",
          allowOutsideClick: true,
          allowEscapeKey: true,
        });
      }
    },
    [chainId, executeWrite, governorConfig, refetch],
  );

  const pauseVaultCreation = useCallback(
    () =>
      executeOperation("Pausing vault creation", {
        functionContract: "getProtocolCoreContract",
        functionName: "pauseVaultCreation",
      }),
    [executeOperation],
  );
  const resumeVaultCreation = useCallback(
    () => {
      if (!protocolCoreConfig) {
        throw new Error("ProtocolCore contract unavailable.");
      }

      return createGovernanceProposal(
        "Resume vault creation",
        "This proposal requests DAO approval to resume vault creation at protocol level.",
        protocolCoreConfig.address as Address,
        protocolCoreConfig.abi,
        "unpauseVaultCreation",
      );
    },
    [createGovernanceProposal, protocolCoreConfig],
  );
  const pauseVaultDeposits = useCallback(
    () =>
      executeOperation("Pausing vault deposits", {
        functionContract: "getProtocolCoreContract",
        functionName: "pauseVaultDeposits",
      }),
    [executeOperation],
  );
  const resumeVaultDeposits = useCallback(
    () => {
      if (!protocolCoreConfig) {
        throw new Error("ProtocolCore contract unavailable.");
      }

      return createGovernanceProposal(
        "Resume vault deposits",
        "This proposal requests DAO approval to resume vault deposits across vault infrastructure.",
        protocolCoreConfig.address as Address,
        protocolCoreConfig.abi,
        "unpauseVaultDeposits",
      );
    },
    [createGovernanceProposal, protocolCoreConfig],
  );
  const addSupportedVaultAsset = useCallback(
    () => {
      if (!protocolCoreConfig) {
        throw new Error("ProtocolCore contract unavailable.");
      }

      return createGovernanceProposal(
        "Add supported vault asset",
        "This proposal requests DAO approval to add a supported vault asset to ProtocolCore.",
        protocolCoreConfig.address as Address,
        protocolCoreConfig.abi,
        "setSupportedVaultAsset",
        [supportedVaultAsset.trim(), true],
      ).then(() => setSupportedVaultAsset(""));
    },
    [createGovernanceProposal, protocolCoreConfig, supportedVaultAsset],
  );
  const updateSupportedGenesisTokens = useCallback(() => {
    const nextToken = supportedGenesisToken.trim();

    if (
      supportedGenesisTokensList.some(
        (token) => token.toLowerCase() === nextToken.toLowerCase(),
      )
    ) {
      return Promise.resolve();
    }

    if (!protocolCoreConfig) {
      throw new Error("ProtocolCore contract unavailable.");
    }

    return createGovernanceProposal(
      "Update supported genesis tokens",
      "This proposal requests DAO approval to update the supported genesis tokens list for ProtocolCore.",
      protocolCoreConfig.address as Address,
      protocolCoreConfig.abi,
      "setSupportedGenesisTokens",
      [[...supportedGenesisTokensList, nextToken]],
    ).then(() => setSupportedGenesisToken(""));
  }, [createGovernanceProposal, protocolCoreConfig, supportedGenesisToken, supportedGenesisTokensList]);
  const setFactoryRouter = useCallback(
    () => {
      if (!vaultFactoryConfig) {
        throw new Error("VaultFactory contract unavailable.");
      }

      return createGovernanceProposal(
        "Update factory router",
        "This proposal requests DAO approval to update the VaultFactory router reference.",
        vaultFactoryConfig.address as Address,
        vaultFactoryConfig.abi,
        "setRouter",
        [factoryRouterInput.trim()],
      ).then(() => setFactoryRouterInput(""));
    },
    [createGovernanceProposal, factoryRouterInput, vaultFactoryConfig],
  );
  const setFactoryCore = useCallback(
    () => {
      if (!vaultFactoryConfig) {
        throw new Error("VaultFactory contract unavailable.");
      }

      return createGovernanceProposal(
        "Update factory core",
        "This proposal requests DAO approval to update the VaultFactory core reference.",
        vaultFactoryConfig.address as Address,
        vaultFactoryConfig.abi,
        "setCore",
        [factoryCoreInput.trim()],
      ).then(() => setFactoryCoreInput(""));
    },
    [createGovernanceProposal, factoryCoreInput, vaultFactoryConfig],
  );
  const setGuardianAdministrator = useCallback(
    () => {
      if (!vaultFactoryConfig) {
        throw new Error("VaultFactory contract unavailable.");
      }

      return createGovernanceProposal(
        "Update guardian administrator",
        "This proposal requests DAO approval to update the VaultFactory guardian administrator reference.",
        vaultFactoryConfig.address as Address,
        vaultFactoryConfig.abi,
        "setGuardianAdministrator",
        [guardianAdministratorInput.trim()],
      ).then(() => setGuardianAdministratorInput(""));
    },
    [createGovernanceProposal, guardianAdministratorInput, vaultFactoryConfig],
  );
  const setVaultRegistry = useCallback(
    () => {
      if (!vaultFactoryConfig) {
        throw new Error("VaultFactory contract unavailable.");
      }

      return createGovernanceProposal(
        "Update vault registry",
        "This proposal requests DAO approval to update the VaultFactory vault registry reference.",
        vaultFactoryConfig.address as Address,
        vaultFactoryConfig.abi,
        "setVaultRegistry",
        [vaultRegistryInput.trim()],
      ).then(() => setVaultRegistryInput(""));
    },
    [createGovernanceProposal, vaultRegistryInput, vaultFactoryConfig],
  );
  const setTreasuryProtocolCore = useCallback(
    () => {
      if (!treasuryConfig) {
        throw new Error("Treasury contract unavailable.");
      }

      return createGovernanceProposal(
        "Update treasury core reference",
        "This proposal requests DAO approval to update the Treasury ProtocolCore reference.",
        treasuryConfig.address as Address,
        treasuryConfig.abi,
        "setProtocolCore",
        [treasuryProtocolCoreInput.trim()],
      ).then(() => setTreasuryProtocolCoreInput(""));
    },
    [createGovernanceProposal, treasuryConfig, treasuryProtocolCoreInput],
  );

  const wiringValues = useMemo(
    () => [
      getReadContractResult<string>(wiringData?.[0]) ?? ZERO_ADDRESS,
      getReadContractResult<string>(wiringData?.[1]) ?? ZERO_ADDRESS,
      getReadContractResult<string>(wiringData?.[2]) ?? ZERO_ADDRESS,
      getReadContractResult<string>(wiringData?.[3]) ?? ZERO_ADDRESS,
      getReadContractResult<string>(wiringData?.[4]) ?? ZERO_ADDRESS,
    ],
    [wiringData],
  );

  const wiring: InfrastructureWiring = {
    factoryRouter: formatAddress(wiringValues[0]),
    factoryCore: formatAddress(wiringValues[1]),
    guardianAdministrator: formatAddress(wiringValues[2]),
    vaultRegistry: formatAddress(wiringValues[3]),
    treasuryProtocolCore: formatAddress(wiringValues[4]),
  };

  const configuredWiringCount = wiringValues.filter(
    (value) => value && value !== ZERO_ADDRESS,
  ).length;

  const status: OperationsStatus = {
    vaultCreation: isVaultCreationPaused ? "paused" : "enabled",
    vaultDeposits: isDepositsPaused ? "paused" : "enabled",
    supportedAssetsCount: supportedVaultAssetsCount,
    infrastructureState:
      configuredWiringCount === 5
        ? "linked"
        : configuredWiringCount > 0
          ? "partial"
          : "unconfigured",
  };

  return {
    status,
    wiring,
    assetSupport: {
      supportedVaultAsset,
      setSupportedVaultAsset,
      supportedVaultAssetError,
      canAddSupportedVaultAsset:
        capabilities.canCreateProposal &&
        isValidAddress(supportedVaultAsset.trim()),
      supportedGenesisToken,
      setSupportedGenesisToken,
      supportedGenesisTokenError,
      canUpdateSupportedGenesisTokens:
        capabilities.canCreateProposal &&
        isValidAddress(supportedGenesisToken.trim()),
      supportedGenesisTokenCount,
      assetSupportPermissionMessage: proposalPermissionMessage,
    },
    wiringForm: {
      factoryRouterInput,
      setFactoryRouterInput,
      factoryRouterError,
      canSubmitFactoryRouter,
      factoryCoreInput,
      setFactoryCoreInput,
      factoryCoreError,
      canSubmitFactoryCore,
      guardianAdministratorInput,
      setGuardianAdministratorInput,
      guardianAdministratorError,
      canSubmitGuardianAdministrator,
      vaultRegistryInput,
      setVaultRegistryInput,
      vaultRegistryError,
      canSubmitVaultRegistry,
      treasuryProtocolCoreInput,
      setTreasuryProtocolCoreInput,
      treasuryProtocolCoreError,
      canSubmitTreasuryProtocolCore,
      wiringPermissionMessage: proposalPermissionMessage,
    },
    actions: {
      pauseVaultCreation,
      resumeVaultCreation,
      pauseVaultDeposits,
      resumeVaultDeposits,
      addSupportedVaultAsset,
      updateSupportedGenesisTokens,
      setFactoryRouter,
      setFactoryCore,
      setGuardianAdministrator,
      setVaultRegistry,
      setTreasuryProtocolCore,
    },
    summary: {
      protocolControlsValue: `${isVaultCreationPaused ? "Paused" : "Enabled"} / ${
        isDepositsPaused ? "Paused" : "Enabled"
      }`,
      infrastructureAccessValue: capabilities.canAccessAdminConsole
        ? "Allowed"
        : "Restricted",
      infrastructureAccessSubtitle: capabilities.canAccessAdminConsole
        ? "Administrative wallet access is available for wiring and control actions."
        : "Administrative wallet access is required for wiring and control actions.",
    },
    refetch,
    capabilities,
  };
}
