# Output ownership contract

Machine output roles implement local ownership only. This contract is not a completion claim for native GPU/driver behavior. Cross-PC authenticated peer leases require separate acceptance.

Local file recording follows video output ownership. A creation lease is admitted after activation validation. The outer sync owns the stop-to-start fence and re-admits the current epoch. Worker send/render failure fences ownership before sender teardown. Worker spawn failure creates no sender before the worker exists. Spout has no asynchronous close acknowledgement.

Lighting, Video, Both, and Standby transitions fence stale producers before teardown. Invalid, foreign, stale, or ambiguous ownership cannot activate output. Native resource creation and publication revalidate the current lease; failed transitions remain observable and fail closed.
