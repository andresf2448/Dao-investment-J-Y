import { Outlet, NavLink, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  Landmark,
  ShieldCheck,
  Vault,
  WalletCards,
  Activity,
  Settings,
  BarChart3,
  Users,
} from "lucide-react";
import { ConnectButton } from "@rainbow-me/rainbowkit";

const navigation = [
  {
    name: "Dashboard",
    href: "/dashboard",
    icon: LayoutDashboard,
  },
  {
    name: "Bonding",
    href: "/bonding",
    icon: WalletCards,
  },
  {
    name: "Governance",
    href: "/governance",
    icon: Landmark,
  },
  {
    name: "Guardians",
    href: "/guardians",
    icon: Users,
  },
  {
    name: "Vaults",
    href: "/vaults",
    icon: Vault,
  },
  {
    name: "Treasury",
    href: "/treasury",
    icon: BarChart3,
  },
  {
    name: "Operations",
    href: "/operations",
    icon: Settings,
  },
  {
    name: "Risk",
    href: "/risk",
    icon: ShieldCheck,
  },
  {
    name: "Admin",
    href: "/admin",
    icon: Activity,
  },
];

export function MainLayout() {
  const location = useLocation();

  return (
    <div className="min-h-screen bg-background text-text-primary">
      <div className="flex min-h-screen">
        <aside className="hidden w-72 flex-col border-r border-border bg-white lg:flex">
          <div className="border-b border-border px-6 py-6">
            <div className="rounded-2xl bg-gradient-to-r from-primary to-primary-light p-[1px]">
              <div className="rounded-2xl bg-white px-5 py-5">
                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">
                  J&amp;Y Protocol
                </p>
                <h1 className="mt-2 text-xl font-semibold text-text-primary">
                  Institutional DeFi
                </h1>
                <p className="mt-2 text-sm leading-6 text-text-secondary">
                  Governed treasury operations, guardian-led vault deployment
                  and risk-aware execution.
                </p>
              </div>
            </div>
          </div>

          <nav className="flex-1 space-y-1 px-4 py-6">
            {navigation.map((item) => {
              const Icon = item.icon;

              return (
                <NavLink
                  key={item.href}
                  to={item.href}
                  className={({ isActive }) =>
                    [
                      "flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium transition",
                      isActive
                        ? "bg-blue-50 text-primary"
                        : "text-text-secondary hover:bg-gray-50 hover:text-text-primary",
                    ].join(" ")
                  }
                >
                  <Icon className="h-4 w-4" />
                  <span>{item.name}</span>
                </NavLink>
              );
            })}
          </nav>

          <div className="border-t border-border px-4 py-4">
            <div className="card">
              <div className="card-content">
                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">
                  Network
                </p>
                <div className="mt-3 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-text-primary">
                      Ethereum Mainnet
                    </p>
                    <p className="mt-1 text-xs text-text-secondary">
                      Live protocol environment
                    </p>
                  </div>
                  <span className="badge-success">Healthy</span>
                </div>
              </div>
            </div>
          </div>
        </aside>

        <div className="flex min-h-screen flex-1 flex-col">
          <header className="sticky top-0 z-20 border-b border-border bg-white/90 backdrop-blur">
            <div className="container-app flex items-center justify-between py-4">
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">
                  Protocol Workspace
                </p>
                <h2 className="mt-1 text-lg font-semibold text-text-primary">
                  {getPageTitle(location.pathname)}
                </h2>
              </div>

              <div className="flex items-center gap-3">
                <ConnectButton />
              </div>
            </div>
          </header>

          <main className="flex-1">
            <div className="container-app py-8">
              <Outlet />
            </div>
          </main>
        </div>
      </div>
    </div>
  );
}

function getPageTitle(pathname: string) {
  switch (pathname) {
    case "/dashboard":
      return "Dashboard";
    case "/bonding":
      return "Bonding";
    case "/governance":
      return "Governance";
    case "/guardians":
      return "Guardians";
    case "/vaults":
      return "Vault Infrastructure";
    case "/treasury":
      return "Treasury";
    case "/operations":
      return "Operations";
    case "/risk":
      return "Risk Monitoring";
    case "/admin":
      return "Admin Console";
    default:
      return "J&Y Protocol";
  }
}

export default MainLayout;
