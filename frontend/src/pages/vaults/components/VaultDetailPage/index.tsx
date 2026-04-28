import { useState } from "react";
import { useParams } from "react-router-dom";
import { ShieldCheck, Vault, WalletCards, Zap } from "lucide-react";
import { useVaultDetailModel } from "@/hooks/useVaultDetailModel";
import { HeroMetric, MetricCard } from "@/components/shared";
import { SummaryStat, MetaRow, ActionField, CopyableAddressCard } from "../";
import { formatAddress } from "@/utils";

export default function VaultDetailPage() {
  const { vaultAddress } = useParams();
  const [depositAmount, setDepositAmount] = useState("");
  const [mintSharesAmount, setMintSharesAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [redeemSharesAmount, setRedeemSharesAmount] = useState("");
const {
    vault,
    position,
    controls,
    capabilities,
    isSubmitting,
    depositAssetBalance,
    hasDepositAssetBalance,
    canShowGuardianOperations,
    deposit,
    mint,
    withdraw,
    redeem,
    executeStrategy,
  } = useVaultDetailModel(vaultAddress);

  const depositsStatusLabel = controls.depositsEnabled ? "Enabled" : "Paused";
  const strategyExecutionLabel = controls.strategyExecutionEnabled
    ? "Enabled"
    : "Restricted";
  const depositControlsDescription = controls.depositsEnabled
    ? "Deposits and minting are available while protocol and vault controls remain enabled."
    : "Deposits and minting are currently blocked by protocol pause or inactive vault status.";
  const strategyExecutionDescription = controls.strategyExecutionEnabled
    ? "Execution is available at vault level while risk controls remain enabled."
    : "Execution is blocked by risk controls or inactive vault status.";
  const isPositiveNumber = (value: string) =>
    value.trim() !== "" &&
    Number.isFinite(Number(value)) &&
    Number(value) > 0;
  const canDeposit =
    controls.depositsEnabled &&
    isPositiveNumber(depositAmount) &&
    hasDepositAssetBalance;
  const canMint = controls.depositsEnabled && isPositiveNumber(mintSharesAmount);
  const canWithdraw = isPositiveNumber(withdrawAmount);
  const canRedeem = isPositiveNumber(redeemSharesAmount);
  const depositAmountError =
    depositAmount.trim() !== "" && !isPositiveNumber(depositAmount)
      ? `Enter a valid ${vault.asset} amount greater than 0.`
      : depositAmount.trim() !== "" && !hasDepositAssetBalance
      ? `You have no ${vault.asset} balance to deposit.`
      : undefined;
  const mintSharesAmountError =
    mintSharesAmount.trim() !== "" && !isPositiveNumber(mintSharesAmount)
      ? "Enter a valid share amount greater than 0."
      : undefined;
  const withdrawAmountError =
    withdrawAmount.trim() !== "" && !isPositiveNumber(withdrawAmount)
      ? `Enter a valid ${vault.asset} amount greater than 0.`
      : undefined;
  const redeemSharesAmountError =
    redeemSharesAmount.trim() !== "" && !isPositiveNumber(redeemSharesAmount)
      ? "Enter a valid share amount greater than 0."
      : undefined;

  const handleDeposit = async () => {
    if (await deposit(depositAmount)) {
      setDepositAmount("");
    }
  };

  const handleMint = async () => {
    if (await mint(mintSharesAmount)) {
      setMintSharesAmount("");
    }
  };

  const handleWithdraw = async () => {
    if (await withdraw(withdrawAmount)) {
      setWithdrawAmount("");
    }
  };

  const handleRedeem = async () => {
    if (await redeem(redeemSharesAmount)) {
      setRedeemSharesAmount("");
    }
  };

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Vault Details
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Review vault state, user position and asset-level operations.
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Vault activity is tied to guardian-linked infrastructure, protocol
          controls and strategy execution safety checks.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <CopyableAddressCard label="Vault Address" value={vault.address} />
          <HeroMetric label="Asset" value={vault.asset} />
          <CopyableAddressCard label="Guardian" value={vault.guardian} />
          <HeroMetric label="Status" value={vault.status} />
        </div>
      </section>

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          title="Registered At"
          value={vault.registeredAt}
          subtitle="Vault registration reference date"
          icon={<Vault className="h-5 w-5" />}
        />
        <MetricCard
          title="Decimals"
          value={String(vault.decimals)}
          subtitle="Underlying asset precision"
          icon={<WalletCards className="h-5 w-5" />}
        />
        <MetricCard
          title="Deposits"
          value={depositsStatusLabel}
          subtitle={depositControlsDescription}
          icon={<ShieldCheck className="h-5 w-5" />}
        />
        <MetricCard
          title="Strategy Execution"
          value={strategyExecutionLabel}
          subtitle={strategyExecutionDescription}
          icon={<Zap className="h-5 w-5" />}
        />
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr,1fr]">
        <div className="card">
          <div className="card-header">Vault Summary</div>

          <div className="card-content grid gap-4 sm:grid-cols-2">
            <SummaryStat
              label="Vault Total Assets"
              value={vault.totalAssets}
            />
          </div>
        </div>

        <div className="card">
          <div className="card-header">My Position</div>

          <div className="card-content grid gap-4 sm:grid-cols-2">
            <SummaryStat
              label="My Deposited Assets"
              value={position.depositedAssets}
            />
            <SummaryStat label="Minted Shares" value={position.mintedShares} />
            <SummaryStat
              label="Withdrawable Assets"
              value={position.withdrawableAssets}
            />
            <SummaryStat
              label="Redeemable Shares"
              value={position.redeemableShares}
            />
          </div>
        </div>
      </section>

      <section className="card">
        <div className="card-header">Vault Metadata</div>

        <div className="card-content space-y-4">
          <MetaRow
            label="Vault Address"
            value={formatAddress(vault.address)}
            copyValue={vault.address}
          />
          <MetaRow label="Underlying Asset" value={vault.asset} />
          <MetaRow
            label="Guardian"
            value={formatAddress(vault.guardian)}
            copyValue={vault.guardian}
          />
          <MetaRow label="Registered At" value={vault.registeredAt} />
          <MetaRow label="Status" value={vault.status} />
          <MetaRow label="Decimals" value={String(vault.decimals)} />
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr,1fr]">
        <div className="card">
          <div className="card-header">Deposit & Mint</div>

          <div className="card-content space-y-5">
            <ActionField
              label="Deposit Assets"
              placeholder={`Enter ${vault.asset} amount`}
              value={depositAmount}
              onChange={setDepositAmount}
              error={depositAmountError}
              inputMode="decimal"
            />
            <div className="flex items-center justify-between text-sm text-text-secondary">
              <span>Your balance</span>
              <span>{depositAssetBalance}</span>
            </div>
            <button
              className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!canDeposit || isSubmitting}
              onClick={() => void handleDeposit()}
            >
              Deposit Assets
            </button>

            <ActionField
              label="Mint Shares"
              placeholder="Enter share amount"
              value={mintSharesAmount}
              onChange={setMintSharesAmount}
              error={mintSharesAmountError}
              inputMode="decimal"
            />
            <button
              className="btn-secondary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!canMint || isSubmitting}
              onClick={() => void handleMint()}
            >
              Mint Shares
            </button>
            {/* TODO: deshabilitar además por wallet/session si aplica */}
          </div>
        </div>

        <div className="card">
          <div className="card-header">Withdraw & Redeem</div>

          <div className="card-content space-y-5">
            <ActionField
              label="Withdraw Assets"
              placeholder={`Enter ${vault.asset} amount`}
              value={withdrawAmount}
              onChange={setWithdrawAmount}
              error={withdrawAmountError}
              inputMode="decimal"
            />
            <div className="flex items-center justify-between text-sm text-text-secondary">
              <span>Your balance</span>
              <span>{depositAssetBalance}</span>
            </div>
            <button
              className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!canWithdraw || isSubmitting}
              onClick={() => void handleWithdraw()}
            >
              Withdraw Assets
            </button>

            <ActionField
              label="Redeem Shares"
              placeholder="Enter share amount"
              value={redeemSharesAmount}
              onChange={setRedeemSharesAmount}
              error={redeemSharesAmountError}
              inputMode="decimal"
            />
            <button
              className="btn-secondary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!canRedeem || isSubmitting}
              onClick={() => void handleRedeem()}
            >
              Redeem Shares
            </button>
          </div>
        </div>
      </section>

      {canShowGuardianOperations ? (
        <section className="card">
          <div className="card-header">Guardian Operations</div>

          <div className="card-content space-y-4">
            <p className="text-sm leading-7 text-text-secondary">
              Guardian-linked execution remains subject to protocol controls,
              vault status and risk monitoring.
            </p>

            <div className="rounded-2xl border border-border bg-gray-50 px-4 py-4">
              <p className="text-sm font-medium text-text-primary">
                Strategy Execution
              </p>
              <p className="mt-1 text-sm leading-6 text-text-secondary">
                {controls.strategyExecutionEnabled
                  ? "Execution is enabled at vault level, but still requires guardian capability from the connected wallet."
                  : "Execution is currently restricted by vault status or protocol risk controls."}
              </p>
            </div>

            <button
              className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={
                !capabilities.canExecuteStrategy ||
                !controls.strategyExecutionEnabled ||
                isSubmitting
              }
              onClick={() => void executeStrategy()}
            >
              Execute Strategy
            </button>
          </div>
        </section>
      ) : null}
    </div>
  );
}
