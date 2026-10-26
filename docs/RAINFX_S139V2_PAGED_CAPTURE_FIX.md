# s139 v2 — CSP texture binding limit and paged capture fix

Date: 2026-10-18
Status: ACTIVE

## User result and cause

The supplied actual s139 run reaches `fault` with
`std/lib_shader:0: Too many textures`. The original tagged log, installed package
and s139 sources/reports are preserved. This is a failed actual experiment; its
local pass must not be read as an actual CSP pass.

The positive extraction shader binds all **40** resource canvases. The installed
`ac_apps/lib.lua` explicitly documents a **32-texture** binding limit. Original
transport calls bind at most 17 and the protocol plan binds eight. A replay of
the frozen v1 controller under a 32-binding mock reproduces the same fault at
the first extraction, after its first forty resource calls are accepted.
The preceding local mock and WARP adapter omitted this CSP limit.

## Fix

Separate default-OFF app **RealVisor s139v2 interval header probe v2** splits
extraction into groups of **24 + 16** resource textures for positive cases.
Negative header-only cases bind nine captured textures. No solver, header value,
physical input, plan criterion or numerical tolerance changes.

Each extraction page has its own compact R32FLOAT canvas. Thirteen readbacks
replace eight; the callback verifies finite values and zero page padding, copies
each page's fields to their original offsets, and emits the same 53,312 float
words and 296 log lines. Duplicate callbacks dispose their CPU data once per
callback without replacing completed pages. Logging waits for all pages.

There are five additional atlas calls/canvases: **255 total calls/resources**.
Compact page dimensions preserve the old **464,672-byte nominal texel payload**;
allocation overhead and actual GPU cost are unmeasured. All used GPU resources
remain retained. Pending page two resumes without replaying page one or accepted
transport calls. No game roots/host time are published and no fence is inferred.

All draw requests now check the documented 32-binding limit before submission.
The mock enforces the same limit, and static coverage checks confirm all original
field ranges occur exactly once across pages.

## Verification and current boundary

- **255 WARP draws / 19 strict /WX /Ges shader bodies** pass. Reassembled
  capture words match frozen s139 v1 and s138 controls bit for bit.
- **22 controller cases** include the original pending/error cases plus page-two
  unknown/nil submission and corrupt page-padding refusal. Every mock request
  enforces the 32-texture limit.
- **16 decoder controls and nine scratch installer cases** pass. Existing
  source/header/plan, conservation and conditional map bounds are preserved.
- A separate regression replays the original failing controller and detects the
  40-binding failure. The actual fault and installed SDK evidence are frozen.
- Production runtime, INI tuning, previous stage sources and the old s139 app
  remain unchanged. v2 uses a separate six-file package and log tag.

Actual CSP results for v2 are pending. Start a **fresh game session** to release
the failed probe's retained allocations and provide a fresh cumulative log quota.
Open **RealVisor s139v2 interval header probe v2**, Enable, then **Run s139v2
probe once**. Report `observed` or the displayed error. Weather/driving/FPS
comparisons are unnecessary. The original s139 app should remain disabled.
