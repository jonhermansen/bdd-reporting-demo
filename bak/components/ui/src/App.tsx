import { useEffect, useState } from "react";

export function App() {
  const [items, setItems] = useState<{ id: number; name: string }[]>([]);
  const [name, setName] = useState("");

  useEffect(() => {
    fetch("/api/items")
      .then((r) => r.json())
      .then(setItems)
      .catch(() => setItems([]));
  }, []);

  const add = async () => {
    const resp = await fetch("/api/items", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
    const created = await resp.json();
    setItems((prev) => [...prev, created]);
    setName("");
  };

  return (
    <div>
      <h1>Items</h1>
      <ul data-testid="items">
        {items.map((i) => (
          <li key={i.id}>{i.name}</li>
        ))}
      </ul>
      <input
        data-testid="new-item"
        value={name}
        onChange={(e) => setName(e.target.value)}
      />
      <button data-testid="add" onClick={add}>
        Add
      </button>
    </div>
  );
}
