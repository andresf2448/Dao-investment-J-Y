import { Routes, Route, Navigate } from "react-router-dom";
import { MainLayout } from "@/components/layout/MainLayout";

// Pages
import DashboardPage from "@/pages/dashboard";
import BondingPage from "@/pages/bonding";
import GovernancePage from "@/pages/governance";
import GuardiansPage from "@/pages/guardians";
import VaultsPage from "@/pages/vaults";
import TreasuryPage from "@/pages/treasury";
import OperationsPage from "@/pages/operations";
import RiskPage from "@/pages/risk";
import AdminPage from "@/pages/admin";
import { VaultDetailPage, GuardianToolsPage, MyPositionsPage } from "@/pages/vaults/components";
import { CreateProposalPage, ProposalDetailPage } from "@/pages/governance/components";
import { OperationsPage as TreasuryOperationsPage } from "@/pages/treasury/components";

export function AppRouter() {
  return (
    <Routes>
      <Route element={<MainLayout />}>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />

        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/bonding" element={<BondingPage />} />
        <Route path="/governance" element={<GovernancePage />} />
        <Route path="/governance/create" element={<CreateProposalPage />} />
        <Route path="/governance/:proposalId" element={<ProposalDetailPage />} />
        <Route path="/guardians" element={<GuardiansPage />} />
        <Route path="/vaults" element={<VaultsPage />} />
        <Route path="/vaults/:vaultAddress" element={<VaultDetailPage />} />
        <Route path="/vaults/positions" element={<MyPositionsPage />} />
        <Route path="/vaults/guardian-tools" element={<GuardianToolsPage />} />
        <Route path="/treasury" element={<TreasuryPage />} />
        <Route path="/treasury/operations" element={<TreasuryOperationsPage />} />
        <Route path="/operations" element={<OperationsPage />} />
        <Route path="/risk" element={<RiskPage />} />
        <Route path="/admin" element={<AdminPage />} />
      </Route>
    </Routes>
  );
}