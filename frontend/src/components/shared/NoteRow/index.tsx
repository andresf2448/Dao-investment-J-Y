import { ReactNode } from "react";

interface NoteRowProps {
  icon?: ReactNode;
  title: string;
  description: string;
}

export function NoteRow({ icon, title, description }: NoteRowProps) {
  return (
    <div className="rounded-2xl border border-border px-4 py-4">
      {icon && <div className="w-fit rounded-xl bg-blue-50 p-2 text-primary">{icon}</div>}
      <h3 className={`text-sm font-semibold text-text-primary ${icon ? "mt-4" : ""}`}>
        {title}
      </h3>
      <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>
    </div>
  );
}
