import type { ProtocolCapabilities } from "@/types/capabilities";
import type { GuardianMetrics, GuardianState } from "@/types/guardian";

export interface GuardiansModel {
  state: GuardianState;
  metrics: GuardianMetrics;
  capabilities: ProtocolCapabilities;
  isSubmitting: boolean;
  hasPendingApplication: boolean;
  applicationGuardian: () => Promise<void>;
}
