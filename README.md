# CapacityCredit

CapacityCredit.jl builds on the resource adequacy assessment capabilities of
[ResourceAdequacy.jl](https://github.com/NREL/ResourceAdequacy.jl)
to provided capacity-based quantifications of the marginal benefit to
system resource adequacy associated with a specific resource or collection of
resources. Two capacity credit metrics (EFC and ELCC) are currently supported.

## Available Capacity Credit Metrics

### Equivalent Firm Capacity (EFC)

`EFC` estimates the amount of idealized, 100%-available capacity that, when
added to a baseline system, reproduces the level of system adequacy associated
with the baseline system plus the study resource. The following parameters must
be specified:

 - The risk metric to be used for comparison (i.e. EUE or LOLE)
 - A known upper bound on the EFC value (usually the resource's nameplate
   capacity)
 - The regional distribution of the firm capacity to be added. This is
   typically chosen to match the regional distribution of the study resource's
   nameplate capacity.

For example, to assess the EUE-based EFC of a new resource with 1000 MW nameplate
capacity, added to the system in a single region labelled "A":

```julia
using ResourceAdequacy, CapacityCredit

# The base system, with power units in MW
base_system

# The base system augmented with some incremental resource of interest
augmented_system

assess(EFC{EUE}(1000, "A"),
       Modern(nsamples=100_000), Minimal(),
       base_system, augmented_system)
```

If the study resource were instead split between regions "A" (600MW) and "B"
(400 MW), one could specify the firm capacity distribution as:

```julia
assess(EFC{EUE}(1000, ["A"=>0.6, "B"=>0.4]),
       Modern(nsamples=100_000), Minimal(),
       base_system, augmented_system)
```

### Equivalent Load Carrying Capability (ELCC)

`ELCC` estimates the amount of additional load that can be added to the system
(in every time period) in the presence of a new study resource, while
maintaining the baseline system's original adequacy level. The following
parameters must be specified:

 - The risk metric to be used for comparison (i.e. EUE or LOLE)
 - A known upper bound on the ELCC value (usually the resource's nameplate
   capacity)
 - The regional distribution of the load to be added. Note that this choice is
   somewhat ambiguous in multi-region systems, so assumptions should be clearly
   specified when reporting analysis results.

For example, to assess the EUE-based ELCC of a new resource with 1000 MW nameplate
capacity, serving load in region "A":

```julia
using ResourceAdequacy, CapacityCredit

# The base system, with power units in MW
base_system

# The base system augmented with some incremental resource of interest
augmented_system

assess(ELCC{EUE}(1000, "A"),
       Modern(nsamples=100_000), Minimal(),
       base_system, augmented_system)
```

If instead the goal was to study the ability of the new resource to provide
load evenly to regions "A" and "B", one could use:

```julia
assess(ELCC{EUE}(1000, ["A"=>0.5, "B"=>0.5]),
       Modern(nsamples=100_000), Minimal(),
       base_system, augmented_system)
```

## Comparisons under uncertainty in RA metric estimates

For non-deterministic assessment methods (i.e. Monte Carlo simulations),
running a resource adequacy assessment with different random number generation
seeds can result in different risk metric estimates for the same underlying
system. Capacity credit assessments can be sensitive to this uncertainty,
particularly when attempting to study the impact of a small resource on a
large system with a limited number of simulation samples.

CapacityCredit.jl takes steps to a) limit this uncertainty and b) warn against
potential deficiencies in statistical power resulting from this uncertainty.

First, the same random seed is used across all simulations in the capacity
credit assessment process. If the number of resources and their reliability
parameters (MTTF and MTTR) remain constant across the baseline and augmented
test systems, seed re-use ensures that unit-level outage profiles remain
identical across RA assessments, providing a fixed background against which to
measure changes in RA resulting from the addition of the study resource. Note
that satisfying this condition requires that the study resource be present in
the baseline case, but with its contributions eliminated (e.g. by setting its
capacity to zero). Assessment methods that modify the system to add new
resources (such as EFC) should assume this invariance exists, and
not violate it in any automated modifications.

Second, capacity credit assessments have two different stopping criteria. The
ideal case is that the upper and lower bounds on the capacity
credit metric converge to be sufficiently tight relative to a desired level
of precision. This target precision is 1 system power unit by default, but can
be relaxed to loosen the convergence bounds if desired via the `capacity_gap`
keyword argument.

Additionally, at each bisection step, a hypothesis test is performed to ensure
that the upper bounding metric is larger than the lower bounding metric with
a specified level of statistical significance. By default, this is a maximum
p-value of 0.05, although this value can be changed as desired via the
`p_value` keyword argument. If at some point the null hypothesis (the upper
bound is not larger than the lower bound) cannot be rejected at the desired
significance level, the assessment will provide a warning indicating the size
of the remaining capacity gap and return the midpoint between the two bounds.
