interface BulletProps {
  text: string;
}

export function Bullet({ text }: BulletProps) {
  return (
    <div className="flex items-start gap-3">
      <div className="mt-2 h-2 w-2 rounded-full bg-primary" />
      <p className="text-sm text-text-secondary">{text}</p>
    </div>
  );
}
