# 🧱 Garden Unlocked

Well done — the application traffic now flows exactly the way it's
supposed to, and the database's isolation is intact.

The root cause was a blanket `default-deny-all` NetworkPolicy with no
matching allow rules for the application's real traffic — a very
common real-world mistake: someone locks a namespace down for security
and forgets to open the paths the app actually needs.

The fix wasn't to remove the deny policy — that would have reopened
everything, including the traffic that was supposed to stay blocked.
It was to add narrow, explicit `Ingress` rules that only allow exactly
what should be allowed: `frontend → backend`, and `backend →
database`. Everything else stayed exactly as locked down as it was
meant to be.
