---
name: doctrine-defense-shadow-confession
description: Code is not a closed novel — a dev's defenses are confessions of where he stopped looking; the bug lives in the adjacent-unplayed shadow of each defense
metadata:
  type: feedback
---

Read code as a REWRITABLE proposed story, never as a closed novel. What the dev wrote is a *proposal*; you may — must — rewrite it (play the stories he didn't) to see if his defense holds. If a story exists where his defense falls, THAT is the true story, not the one he wrote.

Every defense the dev placed (`require`, cap, bound, guard, modifier, AND his test/invariant suite) is an **AVEU / confession**: it marks where he was AFRAID, i.e. where he *looked* — and therefore where he **stopped looking right next to it**. It teaches two things at once: (1) what he saw → the danger-type living in that zone; (2) the real treasure — what he saw tells you what he may NOT have seen *just beside it*. A dev who defends a precise danger thought about THAT danger, not its variants; he put the check on the obvious path, not the neighbor path.

**The bug lives in the immediate SHADOW of the defense** — the *variant* of the danger he saw, the *sibling path* of the one he guarded, the *adjacent bound* of the one he bounded. (Morph: guard on `len < bcLen` proves he feared a size/content mismatch, but `bcLen = blockCount*60` overflows uint64 — he watched the size, not the *arithmetic of the size*; his very defense points at his blind spot.)

**Sibling-asymmetry = the loudest confession.** Where a dev defended function A but not its sister B, the asymmetry IS the aveu: he knew this resolver/path needed gating (proven by the guard on A), so its absence on B is a *forgotten hole, not a choice*. (Solv GraphQL: gate on `signingRecords`, absent on `managementBtcStakeRecords` — the present neighbor-defense CONDEMNS the absent one. Without the neighbor defense, open access could read as intentional; the neighbor turns "maybe meant" into "manifestly forgotten.")

**Why fortresses are fortresses (ratio regards/surface decides everything).** A target washed by 10 audits isn't better-defended — it's that 10 rewriters before you already played every move adjacent to the dev's defenses and found his blind spots. On a fortress, only the **defense-shadows nobody has rewritten yet** remain: moves far from the obvious, or moves that need a rewrite nobody dared. On a NAKED target the defenses are fresh and their shadows virgin — each defense is a sign toward a blind spot you're the first to explore. The number of prior rewriters per defense-shadow decides the EV.

**How to apply:**
- Don't bounce off a defense — read it as a confession of the dev's mental map. Each says "I thought of this." Ask: what did he think of *right next to* this, and did he defend there too?
- Enumerate defenses → for each, play the *adjacent* move (the variant of the bounded case, the sibling of the guarded path). Far from defenses there's either no danger or an obvious one others found; in the exact shadow of what he lit is where the bug sleeps.
- A **formal-verification spec / invariant list is the richest confession** — a literal enumerated list of the dev's fears. On such a target, hunt the invariant *adjacent* to the formalized ones, or the cross-contract composition the spec scoped out.
- This is exactly `darkside` **Door A** (defensive-coverage matrix: money-path × covered-Y/N; the N column is the worklist) fused with the shadow concept. Pairs with [[doctrine-surgical-reports-fight-to-the-end]] (verify the shadow-bug before submit) and [[feedback-verify-before-working-no-theater]].
