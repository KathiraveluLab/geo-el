# geo-el

This is a geography game written in Elixir using Phoenix LiveView and Open Telecom Platform (OTP) supervision trees.

## Architecture Overview

- **Orthographic Spherical Projection (`GeoEl.Globe.Projection` and `GeoEl.Globe.Math`):** Performs server-side forward and inverse orthographic projections between spherical Earth coordinates $(\phi, \lambda)$ and two-dimensional Scalable Vector Graphics (SVG) viewport coordinates $(x, y)$, alongside Haversine great-circle distance and geodesic arc interpolation.
- **Bounded Input State Enforcement (`GeoEl.Adventure.BISE`):** Enforces radial domain clamping ($\hat{u} \in [0.0, 1.0]$) during inverse trigonometric projection, sanitizes viewport rotation deltas, and verifies closed cartographic polygon rings at startup.
- **Adaptive Calibration (`GeoEl.Adventure.Calibration`):** Implements the `SkewPNN` skewed exponential kernel and `A2` adaptive clue routing controller with foreshortening compensation and $95\%$ confidence interval tracking.
- **Supervised Adventure Sessions (`GeoEl.Adventure.SessionServer`):** Isolates each active explorer session inside a supervised `GenServer` worker under a `DynamicSupervisor` (`GeoEl.Adventure.Supervisor`) and broadcasts completed expedition legs over `Phoenix.PubSub`.
- **Interactive Light-Themed Viewport (`GeoElWeb.GlobeLive`):** Renders a high-contrast light-themed SVG globe with colocated pointer drag and coordinate picking hooks.

## Development and Verification

To install dependencies, compile, and run the verification suite:

```bash
mix setup
mix precommit
```

To start the Phoenix web endpoint locally:

```bash
mix phx.server
```
