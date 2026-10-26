The physical product preview writes `rain_product_failure.txt` here on its first
GPU rejection, using the existing retained receipt and input snapshot. No extra
GPU pass/readback. This bypasses the game's session log-line quota. Preserve the
file before starting another failed runtime: the next rejection replaces it.

Terminal input backpressure saves `rain_product_overload.txt` using the same
ordinary CPU status. It includes the rejected frame's raw duration, staged time,
cadence slots, submitted/audited counts and captured-time balance. No extra GPU
measurement and no per-frame disk writing are involved.
