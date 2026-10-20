# LEKTRI.CO EnergyOS gateway

Turns this Home Assistant host into the LEKTRI.CO EnergyOS gateway for one site:
it reads the site's chargers, meters, inverters and batteries on the local
network, publishes their data to LEKTRI.CO EnergyOS, and runs the site guard that
keeps the grid connection within its limits.

## Setup

1. In LEKTRI.CO EnergyOS, open the site → **Connect** → **Get my connect code**.
2. Paste it into this add-on's **Connect code** option and start the add-on.
3. Within a couple of minutes the site shows a gateway. Add devices from the
   site's **Integrations** (for example *LEKTRI.CO AC charger*); the gateway
   picks them up on its own — nothing to configure here.

## How it stays up to date

On first start the add-on downloads the agent's supervisor from LEKTRI.CO
EnergyOS, authenticated by the site's connect code, and installs it only if
its checksum and signature verify against the LEKTRI.CO EnergyOS signing key. The
supervisor then installs the agent and follows the releases LEKTRI.CO EnergyOS
assigns this gateway — every update is signature-checked and rolled back if
the new version does not come up healthy.

## Remote access

When LEKTRI.CO EnergyOS staff enable remote access for your site, the gateway
opens a WireGuard tunnel to the LEKTRI.CO EnergyOS operations hub so support can
reach this Home Assistant host. The keys are generated on this device (the
private key never leaves it); the tunnel reaches only the hub. That is why
the add-on asks for the `NET_ADMIN` capability. Staff can disable it at any
time, and the tunnel is removed.

## Notes

- **Host network** is required: the agent talks to devices on the site LAN.
- **Re-issuing the connect code** in LEKTRI.CO EnergyOS revokes the old one; paste
  the new code here and restart the add-on.
- State (the agent, its identity and its outbox) lives in the add-on's own
  storage and survives restarts and add-on updates.
