# 🛒 Checkout Restored

Well done — customers can check out again.

Three very ordinary production problems, stacked on top of each other:

* A **bad image tag** that stopped the container from ever being pulled.
* A **Secret key typo** that stopped the container from ever starting.
* A **readiness probe pointing at the wrong path** that kept a running
  Pod out of service.

None of these are exotic — this is what a real bad deploy usually looks
like: several small, boring mistakes, each hiding behind the one before
it. Want to see exactly how each one was fixed? Check out the optional
Solution step.
