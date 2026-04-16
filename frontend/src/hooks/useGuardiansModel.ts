import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type GuardianStatus =
  | "inactive"
  | "pending"
  | "active"
  | "rejected"
  | "resigned"
  | "banned";

export type GuardianState = {
  status: GuardianStatus;
  requiredStake: string;
  bondedAmount: string;
  proposalState: string;
  canOperate: boolean;
};

export type GuardianMetrics = {
  activeGuardians: number;
  pendingApplications: number;
  escrowBalance: string;
};

export type GuardiansModel = {
  state: GuardianState;
  metrics: GuardianMetrics;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useGuardiansModel(): GuardiansModel {
  const capabilities = useProtocolCapabilities();

  // ===== MOCK STATE =====
  const state: GuardianState = {
    status: "inactive",
    requiredStake: "1,000 GOV",
    bondedAmount: "0 GOV",
    proposalState: "—",
    canOperate: false,
  };

  // ===== MOCK METRICS =====
  const metrics: GuardianMetrics = {
    activeGuardians: 14,
    pendingApplications: 3,
    escrowBalance: "24,500 GOV",
  };

  // ===== FUTURO =====
  // TODO:
  // state.status -> GuardianAdministrator.getGuardianDetail(user)
  // state.requiredStake -> GuardianAdministrator.minStake
  // state.bondedAmount -> GuardianBondEscrow balance por usuario
  // state.proposalState -> GuardianAdministrator.getProposalState(user)
  // state.canOperate -> isActiveGuardian(user)
  //
  // metrics.activeGuardians -> indexación / contador global
  // metrics.pendingApplications -> proposals pendientes tipo guardian
  // metrics.escrowBalance -> GuardianBondEscrow.getApplicationTokenBalance()

  return {
    state,
    metrics,
    capabilities,
  };
}