# Tog

Tog is an attempt at a new distributed, caching compiler driver. It sits atop
other compilers and intercepts their compile commands to reuse cached outputs
and distribute compile workloads between multiple nodes.

This is very, very early, and is nowhere near complete or useful.