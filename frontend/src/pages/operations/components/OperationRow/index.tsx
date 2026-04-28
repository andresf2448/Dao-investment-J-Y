interface OperationRowProps {
  title: string;
  description: string;
  primaryAction: string;
  secondaryAction?: string;
  disablePrimary: boolean;
  disableSecondary?: boolean;
  statusMessage?: string;
  onPrimaryAction?: () => void;
  onSecondaryAction?: () => void;
}

export function OperationRow({
  title,
  description,
  primaryAction,
  secondaryAction,
  disablePrimary,
  disableSecondary,
  statusMessage,
  onPrimaryAction,
  onSecondaryAction,
}: OperationRowProps) {
  return (
    <div className="rounded-2xl border border-border px-4 py-4">
      <h3 className="text-sm font-semibold text-text-primary">{title}</h3>
      <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>

      <div className="mt-4 flex flex-wrap gap-3">
        <button
          className="btn-primary disabled:cursor-not-allowed disabled:opacity-50"
          disabled={disablePrimary}
          onClick={onPrimaryAction}
        >
          {primaryAction}
        </button>
        {secondaryAction ? (
          <button
            className="btn-secondary disabled:cursor-not-allowed disabled:opacity-50"
            disabled={disableSecondary}
            onClick={onSecondaryAction}
          >
            {secondaryAction}
          </button>
        ) : null}
      </div>
      {statusMessage ? (
        <p className="mt-3 text-sm leading-6 text-text-secondary">
          {statusMessage}
        </p>
      ) : null}
    </div>
  );
}
