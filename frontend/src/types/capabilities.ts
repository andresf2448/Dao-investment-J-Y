export interface ProtocolCapabilities {
  canBuyGovernanceTokens: boolean;
  canOpenProposalComposer: boolean;
  canCreateProposal: boolean;
  canApplyAsGuardian: boolean;
  canAccessGuardianOperations: boolean;
  canCreateVault: boolean;
  canExecuteStrategy: boolean;
  canOpenTreasuryOperations: boolean;
  canWithdrawNonDaoAssets: boolean;
  canPauseVaultCreation: boolean;
  canResumeVaultCreation: boolean;
  canPauseVaultDeposits: boolean;
  canResumeVaultDeposits: boolean;
  canPauseRiskExecution: boolean;
  canResumeRiskExecution: boolean;
  canAccessAdminConsole: boolean;
  canSweepBondingTokens: boolean;
}

export interface ProtocolCapabilityContext {
  isWalletConnected: boolean;
  hasProposalThreshold: boolean;
  guardianStatus:
    | "inactive"
    | "pending"
    | "active"
    | "rejected"
    | "resigned"
    | "banned";
  isVaultCreationPaused: boolean;
  isDepositsPaused: boolean;
  isExecutionPaused: boolean;
  isManagerOperator: boolean;
  isEmergencyOperator: boolean;
  isTreasuryOperator: boolean;
  isAdminOperator: boolean;
  hasBondingSweepRole: boolean;
  hasTreasurySweepRole: boolean;
}

export interface WalletState {
  isConnected: boolean;
  address: string | null;
  chainId: number | null;
}
