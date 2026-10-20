# LEKTRI.CO EnergyOS — Home Assistant add-ons

Add this repository in Home Assistant (**Settings → Add-ons → Add-on store →
⋮ → Repositories**) with the URL `https://github.com/lektrico/ha-addon-eos`,
then install **LEKTRI.CO EnergyOS gateway**. See `energyos_gateway/DOCS.md`.

This repository holds only the add-on definition and its startup scripts. No
binaries: the gateway downloads its signed agent from LEKTRI.CO EnergyOS,
authenticated by the site's connect code.
