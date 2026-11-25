# HashForge

Run your own Bitcoin mining pool from Home Assistant.

This app bundles the open-source [HashForge](https://github.com/owenashurst/HashForge) pool with a
Bitcoin Core node and the databases it needs, so one install gives you a working pool with solo, PPLNS,
proportional and finder-bonus payouts, a web interface and optional Discord messages. Rewards are paid
by the block itself, straight to each miner's own address.

The bundled node has to download the blockchain before the pool can hand out work. See the
**Documentation** tab for what that needs, or point the app at a node you already run.
