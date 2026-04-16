import { Blocks, CheckCircle2 } from "lucide-react";

interface ContractGroupProps {
  title: string;
  items: Array<{ name: string; address: string }>;
}

export function ContractGroup({ title, items }: ContractGroupProps) {
  return (
    <div>
      <div className="mb-3 flex items-center gap-2">
        <Blocks className="h-4 w-4 text-primary" />
        <h3 className="text-sm font-semibold text-text-primary">{title}</h3>
      </div>

      <div className="space-y-3">
        {items.map((item) => (
          <div
            key={item.address}
            className="flex items-center justify-between rounded-2xl border border-border px-4 py-4"
          >
            <div>
              <p className="text-sm font-medium text-text-primary">{item.name}</p>
              <p className="mt-1 text-sm text-text-secondary">{item.address}</p>
            </div>
            <CheckCircle2 className="h-5 w-5 text-success" />
          </div>
        ))}
      </div>
    </div>
  );
}
