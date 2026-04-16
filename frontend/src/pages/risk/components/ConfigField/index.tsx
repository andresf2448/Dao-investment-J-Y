interface ConfigFieldProps {
  label: string;
  placeholder: string;
}

export function ConfigField({ label, placeholder }: ConfigFieldProps) {
  return (
    <div>
      <label className="text-sm text-text-secondary">{label}</label>
      <input
        type="text"
        placeholder={placeholder}
        className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
      />
    </div>
  );
}
