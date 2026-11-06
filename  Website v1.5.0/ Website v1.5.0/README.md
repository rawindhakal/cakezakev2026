# eCommerce Web

A single-vendor, multi-country storefront built with Next.js 16. Customers browse a catalog, add to cart, checkout with multiple payment options, track orders, chat with support, and manage their account — content, languages, theme, and layout are all controlled from the admin backend.

See the full feature list in [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md).

## Tech stack

- **Framework:** Next.js 16 (Pages Router), React 19
- **State:** Redux Toolkit + redux-persist
- **Data fetching:** TanStack React Query, axios
- **Styling:** Tailwind CSS, Radix UI primitives
- **Maps:** Google Maps or OpenStreetMap (Leaflet) — backend-selectable
- **Payments:** Razorpay, PayPal, Paystack, Stripe, Cashfree, PhonePe
- **Push notifications:** Firebase

## Quick start

```bash
npm install
# create .env in the project root — see docs/INSTALLATION.md for every variable
npm run dev             # http://localhost:3000
```

Production:

```bash
npm run build
npm start               # NODE_ENV=production, port 8004, via server.js
```

## Documentation

| Guide | Read it when |
| --- | --- |
| [Overview](docs/OVERVIEW.md) | Understanding what the project is and how it fits with the Admin Panel |
| [Installation Steps](docs/INSTALLATION.md) | Setting up for the first time — prerequisites, `.env`, first build |
| [Firebase Setup](docs/FIREBASE_SETUP.md) | Push notifications — project, VAPID key, service worker, verification |
| [File Structure](docs/FILE_STRUCTURE.md) | Finding your way around the codebase |
| [Configuration & Theming](docs/CONFIGURATION.md) | Colours, home page blocks, channels, zones, languages |
| [Deployment Guide (VPS)](docs/DEPLOYMENT_VPS.md) | Going live with SEO enabled — Node 20, PM2, Apache/Nginx |

Reference: [Project Overview](docs/PROJECT_OVERVIEW.md) · [URL Structure](docs/url-structure.md) · [Zone SEO](docs/zone-seo.md) · [Language SEO](docs/language-seo.md) · [Map & Location System](docs/MAP_LOCATION_SYSTEM.md)

Full index: [docs/README.md](docs/README.md)
