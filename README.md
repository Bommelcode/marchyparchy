# Corporate Coffee

A career-ladder coffee tycoon built in [Godot 4](https://godotengine.org/). Climb from the office coffee juffrouw to CEO of a global chain.

## The ladder

1. **Office Coffee Juffrouw** — colleagues come asking for coffee. Click them, then click the green zone of the brewing bar at the right moment for a perfect cup. Bad cups → colleagues defect and bring their own pod machine. Goal: **$200**.
2. **Café Owner** — your own café. Hire baristas, raise prices. *(Bean sourcing & espresso machine maintenance coming next.)* Goal: **$2k**.
3. **Chain CEO** — open locations across the city. Each has a promo meter that drains every second; revenue scales with promo. Visit a branch (click) to push it back to 100%. Hire managers ($5/s) to double revenue and halve drain. Goal: **$100k**.
4. **Corporate CEO** — Executive dashboard. Live stock ticker (with sparkline) — buybacks cost `100 × current price`, so time them low. Three commodity tickers (Arabica / Robusta / Milk); bulk contract pricing scales with arabica, so lock contracts when arabica is cheap. HR panel shows headcount vs. need (scaled by chain size + cartel + marketing) — understaffed = linear gross penalty. Layoff rounds, wage negotiations (with strike risk), cartel toggle (×2 revenue + antitrust risk), marketing. Goal: **$10M to win**.

A dev "⏭ skip stage" button is in the top right while iterating — bumps your balance and jumps to the next stage.

## Run

1. Install Godot 4.3+ — `sudo pacman -S godot` on Arch, or grab a binary from [godotengine.org](https://godotengine.org/download).
2. `godot project.godot` (or import via the Godot project manager).
3. Press **F5** to play.

## Status

Day 1 of the rebuild. Each stage is functional and balanced for ~5 min progression. Future ideas: random events (PR scandals, viral TikTok), employee personalities, a competitor chain.

## License

MIT — see [LICENSE](LICENSE).
