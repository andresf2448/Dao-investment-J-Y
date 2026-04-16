export interface ProtocolCapabilities {
  canAccessAdminConsole: boolean;
  canCreateProposal: boolean;
  canVoteOnProposal: boolean;
  canExecuteProposal: boolean;
  canManageTreasury: boolean;
  canOpenTreasuryOperations: boolean;
  canCreateVault: boolean;
  canExecuteStrategy: boolean;
  canApplyAsGuardian: boolean;
  canAccessGuardianOperations: boolean;
  canPauseRiskExecution: boolean;
  canResumeRiskExecution: boolean;
  canBuyGovernanceTokens: boolean;
}

export interface WalletState {
  isConnected: boolean;
  address: string | null;
  chainId: number | null;
}
