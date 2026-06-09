# Batch pairwise-overlap fixture — trips ONLY the content-overlap check
# 2 drafts: different openers, 8 shared content words >4 chars, no other checks fire (n=2 skips uniform/skew/lcop)

DRAFT: The agent fetches candidates, scores them by domain signal, filters by English, writes jsonl output for the next stage.
DRAFT: My scout fetches candidates, ranks them by domain signal, drops non-English, writes jsonl output for the next stage.
