export type GuardianStatus = "inactive" | "pending" | "active" | "rejected" | "resigned" | "banned";

export interface GuardianState {
  status: GuardianStatus;
  requiredStake: string;
  bondedAmount: string;
  proposalState: string;
  canOperate: boolean;
}

export interface GuardianMetrics {
  activeGuardians: number;
  pendingApplications: number;
  escrowBalance: string;
}
