
## Automatic ICA Processing 
- Last Update: November 23, 2024
- Erin Schaeffer & Ido Haber


In both cases the entrypoint is `run_ica.sh`
- path to `eeglab` & `MATLAB` need to be modified 

---

### parallel-ICA 

- Takes a path to a directory as an input an performs ICA in parallel based on the number of cores the machine has.
- Up to 64 parallelization maximum, and always has to be no more than half the core number of the machine.
- requires `Parallel Computing Toolbox`
- removed thread count. Running one thread as a default

---

### serial-ICA 

- Takes a path to a directory as an input an performs ICA in parallel based on the number of cores the machine has.
- Trying to run 2 threads as a default. If fails reduced to one. 

---


