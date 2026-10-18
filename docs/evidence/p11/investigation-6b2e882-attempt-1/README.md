# P11 supplementary investigations

These records are separate from successful completion evidence. Original JSON
bytes retain their observed failed results; review.json binds source, run,
attempt and SHA-256. They must not be used to close a passing native gate.

The first attempt of integration run
[39082021205](https://github.com/kurasis/SecureRun/actions/runs/39082021205/attempts/1)
at source `6b2e8828a28b2660ef331106736bfc8f768aa433` had two failures:

- P09 Windows 11 ARM64: unreviewed WerFault remained alive for 60000 ms during
  environment six seeding. The manager refused cleanup authority. Readonly
  metadata found no associated live target or fixed-component crash report.
  The cause remains undetermined. No termination, trust or Windows security
  change was dispatched.
- P05 Server x64: one synthetic fixture stop reported LAB_STOP_INCOMPLETE;
  44 applicable native cases passed and one failed in this attempt. This is
  not a passing containment/cleanup record.

Any subsequent successful execution must retain the full unchanged workload
and assertions and independently pass its native gate. Repeating a disposable
runner does not establish that either intermittent failure cause was fixed.
