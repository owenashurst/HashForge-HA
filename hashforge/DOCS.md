# HashForge

Run your own Bitcoin mining pool from Home Assistant. The app contains everything the pool needs: the
[HashForge](https://github.com/owenashurst/HashForge) pool, a Bitcoin Core node, and the two databases
the pool stores its records in.

## Before you start

- **Disk.** The bundled node downloads and checks the whole blockchain once, then keeps only the most
  recent blocks. On mainnet, allow about 20 GB of free space and expect the first synchronisation to take
  from a day on a fast machine with an SSD to a week or more on a Raspberry Pi. An SD card is not
  suitable: it is too slow and the constant writing wears it out.
- **Memory.** Allow about 2 GB for the app.
- **The pool cannot hand out work until the node has caught up.** The web interface shows the
  synchronisation progress while you wait.
- If you already run a Bitcoin Core node, you can use it instead and skip all of the above; see
  [Using your own node](#using-your-own-node).

To try the pool without waiting, set **Bitcoin network** to `testnet4`, a test network with a much
smaller blockchain and coins that have no value.

## Setting up

1. Install the app and open its **Configuration** tab.
2. Set **Address miners connect to** to the address of your Home Assistant machine as your miners see
   it, for example `192.168.1.10`. The default, `homeassistant.local`, works on many networks.
3. Choose which pools to run. Only the solo pool is on by default.
4. Start the app and choose **Open Web UI**. To keep the pool one click away, turn on **Show in
   sidebar** on the app's **Info** tab.

## Connecting a miner

Point the miner at the pool you want, using your own Bitcoin address as the user name. Anything after a
dot is the worker's name. The password is ignored.

| Pool | Address | User name |
|---|---|---|
| Solo | `stratum+tcp://<your-address>:3333` | `<your Bitcoin address>.<worker>` |
| PPLNS | `stratum+tcp://<your-address>:3334` | `<your Bitcoin address>.<worker>` |
| Proportional | `stratum+tcp://<your-address>:3335` | `<your Bitcoin address>.<worker>` |
| Finder bonus | `stratum+tcp://<your-address>:3336` | `<your Bitcoin address>.<worker>` |

Rewards are paid by the block itself, straight to each miner's address. The pool never holds anyone's
bitcoin.

The ports can be changed on the app's **Network** tab. If you change them, the pool's "Connect" page
still shows the numbers above, because it cannot see which ports Home Assistant has published.

## Options

Only the options most people need are shown at first. Turn on **Show unused optional configuration
options** to see the rest; each has a description beside it.

### Fees

Every pool's fee is 0 unless you set one. If any pool that is switched on charges a fee, **Pool fee
address** must be set to an address on the chosen network, or the app will stop at start-up and say so
in its log.

### The admin page

The pool's admin page (`/admin`) can add pools, change fees and more. Opened inside Home Assistant it
is available to Home Assistant administrators, who are the only people shown the pool there.

Opened directly on port 8080 it has no password, and is open only to the address ranges listed under
**Networks allowed to open the admin page**. The default allows every private home network range.
Narrow it to your own network, and do not publish port 8080 to the internet.

The five spare ports (3337 to 3341) are for pools you add from the admin page. They are switched off
until you give them a number on the **Network** tab.

### Using your own node

Set **External node address**, **External node user** and **External node password** to the RPC
details of your node. The bundled node then stays off and uses no disk. Your node must:

- allow RPC connections from Home Assistant (`rpcbind` and `rpcallowip` in its `bitcoin.conf`);
- be started with `-blockreservedweight=100000` if you run a pool that pays many miners per block.

Setting **External node block announcements** to your node's ZeroMQ address (`zmqpubhashblock` in
`bitcoin.conf`) lets miners switch to a new block the instant it arrives. Without it the pool checks for
new blocks every few seconds instead.

## Backups

The app is included in Home Assistant backups while it keeps running. A backup holds the pool's records
(blocks found, payouts and miner statistics) and its settings. It does not hold the blockchain, which
is large and is downloaded again after a restore.

## Updates

Updates appear in Home Assistant like those of any other app. Each release is built from the newest
HashForge code at the time; the app's log names the exact revision on its first line.

## Good to know

- The pool can be opened two ways. Inside Home Assistant (**Open Web UI** or the sidebar) it is
  protected by your Home Assistant login and works wherever Home Assistant does.
  Directly at `http://<your-address>:8080` it needs no login, which suits a wall display or sharing
  statistics with other miners on your network. To allow only the first way, clear port 8080 on the
  app's **Network** tab.
- Stratum is unencrypted (Stratum V1).
- Stopping the app can take a minute or two while the node writes its databases to disk. Let it finish;
  cutting the power forces a long re-check the next time it starts.
- Changing **Bitcoin network** keeps the old network's blocks on disk. Uninstalling the app removes
  everything it stored.

## Support

Problems with the app itself: <https://github.com/owenashurst/HashForge-HA/issues>.
Problems with the pool: <https://github.com/owenashurst/HashForge/issues>.
