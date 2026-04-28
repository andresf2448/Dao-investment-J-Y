import { useState } from "react";
import { Check, Copy } from "lucide-react";

interface MetaRowProps {
  label: string;
  value: string;
  copyValue?: string;
}

export function MetaRow({ label, value, copyValue }: MetaRowProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    if (!copyValue || copyValue === "—") {
      return;
    }

    try {
      await navigator.clipboard.writeText(copyValue);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopied(false);
    }
  };

  return (
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border px-4 py-4">
      <p className="text-sm text-text-secondary">{label}</p>
      <div className="flex items-center gap-3">
        <p className="text-sm font-medium text-text-primary">{value}</p>
        {copyValue ? (
          <button
            type="button"
            onClick={handleCopy}
            className="inline-flex items-center gap-2 rounded-xl border border-border bg-white/5 px-3 py-2 text-xs font-medium text-text-secondary transition hover:bg-white/10"
          >
            {copied ? (
              <>
                <Check className="h-4 w-4" />
                Copied
              </>
            ) : (
              <>
                <Copy className="h-4 w-4" />
                Copy
              </>
            )}
          </button>
        ) : null}
      </div>
    </div>
  );
}
