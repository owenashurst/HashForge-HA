# Changelog

## 0.1.7

- A pool you stop on the pool's admin page now stays stopped, through restarts and updates, until you
  press Start there. Before, a pool switched on in these options came back at the next restart, and a
  pool created on the admin page was deleted when stopped.
- The pool switches in these options decide which built-in pools exist; the admin page decides whether
  each one is running. Switch a pool off here to remove it. Switch it on again and it returns running.
- Pools created on the admin page can be deleted there once stopped.
- A stopped shared pool keeps the work its miners have handed in.

## 0.1.6

- New option, **Websites allowed to use the API**: list the address of a web page of your own so it can
  read the pool's JSON API from a browser without a "CORS" error. Nothing is allowed until you add one.

## 0.1.5

- Fixes "duplicate share" rejections after the pool changed a miner's difficulty. Some miners were
  made to repeat work they had already handed in; they are now given new work instead.

## 0.1.4

- Rejected shares are shown as a reject rate, such as 0.12%, with the count beside it. A count on
  its own only grows, so it looked worse the longer a pool had been running.

## 0.1.3

- A proper HashForge logo: on the app in Home Assistant, and in the pool's header and browser tab.

## 0.1.2

- Worker names can use letters and digits from any language, so a name like Gårdsrigg or 矿机一号 is
  accepted. The other characters allowed are still `.`, `_` and `-`.

## 0.1.1

- No longer marked experimental, after running on a real Home Assistant machine.

## 0.1.0

- First release: the HashForge pool, Bitcoin Core 32.1, Redis and PostgreSQL 17 in one app.
- Works with the bundled node or with a Bitcoin Core node you already run.
- The pool opens inside Home Assistant and can be added to the sidebar.
- The pool's records are included in Home Assistant backups; the blockchain is not.
