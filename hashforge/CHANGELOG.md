# Changelog

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
