interface StatusCardProps {
  status: "Ready";
  detail: string;
}

export function StatusCard({ status, detail }: StatusCardProps) {
  return (
    <section className="status-card" aria-labelledby="status-title">
      <div>
        <p className="eyebrow">État local</p>
        <h2 id="status-title">{status}</h2>
      </div>
      <p className="stack-detail">{detail}</p>
    </section>
  );
}
