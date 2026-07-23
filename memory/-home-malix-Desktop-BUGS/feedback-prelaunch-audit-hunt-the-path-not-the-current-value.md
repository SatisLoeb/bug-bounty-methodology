---
name: feedback-prelaunch-audit-hunt-the-path-not-the-current-value
description: "On a PRE-LAUNCH / contest audit the pool is empty, so 'no value to steal now / not organically reachable / self-rug' is the WRONG reachability gate — it's an artifact of the empty state, not proof the exploit path is absent. The finding is the CODE PATH that steals/bricks REAL funds once the protocol is FUNDED. And permissionless pool/vault creation makes the ATTACKER the admin — every 'trusted admin' power obtainable-without-permission is attacker-reachable, with the depositing users as victims."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0e8b7796-917c-4113-a4d6-26f7932d10af
---

Operator correction on the Metric OMM Sherlock **pre-launch** contest (2026-07-06), after I ran ~2 days of executed verification, concluded "fortress-null," and dismissed the live leads (first-depositor, timelock=0, malicious-provider) as "unreachable / dampened / self-rug." His words: *"c'est un audit pre-launch, c'est normal que tu ne trouves pas d'argent à voler — ça ne veut pas dire que le path pour voler QUAND il y en aura n'existe pas."*

**The error I made (name it, it polluted half my verdicts):** I evaluated reachability as *"is there value to steal RIGHT NOW / is the exploit state organically present in the current chain state / is it a self-rug."* On a pre-launch audit the pool is EMPTY — so of course the fuzzes find nothing to *steal* and every state looks "unreachable." That emptiness is an **artifact of the pre-funding state, not evidence the exploit path is absent.** The audit exists precisely to secure the code that WILL hold real money at launch.

**Why:** the correct gate for a pre-launch / contest / fresh-deploy audit is **"does the CODE PATH exist that steals / bricks / corrupts REAL user funds once the protocol is FUNDED?"** — evaluate whether an attacker can *construct* the exploit on the live funded protocol, NOT whether there is value on it in the test harness today. A value-conservation fuzz that HOLDS is still real signal (a leak is a leak at any TVL); but a *reachability* dismissal built on "no money now / not organic / self-rug" is a category error on a pre-launch target.

**The pivot that follows (the highest-leverage half of the lesson):** when creation is **PERMISSIONLESS** (permissionless `createPool` / vault-factory / market-creation), **the attacker can BE the admin/creator of the instance they deploy.** So every "semi-trusted admin / creator-set config" power is **attacker-reachable** — it is a role *obtainable-without-permission* (the exact Sherlock "not-trusted" clause), and the OTHER users who deposit into that instance are the VICTIMS. "The admin can rug their own pool" is therefore **NOT a valid dismissal** when other users deposit into it. (Metric: `createPool` lets anyone set themselves admin, supply an ARBITRARY priceProvider with no registry check, and set `priceProviderTimelock=0` — and price is 100% the provider, so an attacker-created pool drains the LPs who join. I had dismissed all of this as "self-rug / dampened / LP-due-diligence.")

**How to apply:**
1. **On any pre-launch / fresh-deploy / contest target, delete the "is there value now" and "self-rug" reachability gates.** Ask instead: *once funded, does this path move/lock/corrupt another user's funds?* If yes, it's a finding regardless of current TVL.
2. **Map the permissionless-creation surface FIRST.** If anyone can create an instance and be its admin/creator, enumerate every creator/admin-set config (oracle/provider, fees, timelock, extensions/hooks, initial params) and ask: *can the attacker-creator use it to steal from / brick the users who deposit?* Roles obtainable-without-permission are untrusted (Sherlock explicit).
3. **Separate the TWO kinds of dismissal.** "Oracle value correctness assumed" for the protocol's OWN trusted provider = legit scope. But the SAME assumption COLLAPSES the moment an attacker supplies their own provider/config via permissionless creation — re-evaluate every "dampened by trust" lead under "is this input attacker-supplied via createPool?"
4. **Keep the conservation/solvency fuzz results** (they're TVL-independent) but **re-open every reachability-null** that leaned on "no value / not organic / self-rug."
5. The trigger phrase to STOP and re-frame: catching myself write "unreachable because the pool is empty / no one would deposit / it's the creator's own pool" on a pre-launch target.

Links: [[feedback-reachability-is-kill-gate-not-severity-modifier]] (reachability is still a kill-gate — but on a pre-launch target it's gated on the PATH-when-funded, not value-now), [[feedback-depth-is-an-edge-only-where-ore-remains]] (a contest is fresh-ore where depth pays — this is why the null felt wrong), [[feedback-compliance-control-bypass-severity-frame]] (control-defeat framing), [[feedback-target-diet-is-the-binding-constraint]].
