interface LifecycleStepProps {
  title: string;
  description: string;
}

export function LifecycleStep({ title, description }: LifecycleStepProps) {
  return (
    <div className="flex gap-4">
      <div className="mt-1 flex h-8 w-8 items-center justify-center rounded-full bg-blue-50 text-sm font-semibold text-primary">
        •
      </div>
      <div>
        <h3 className="text-sm font-semibold text-text-primary">{title}</h3>
        <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>
      </div>
    </div>
  );
}
