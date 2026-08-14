# # [Multi-Metric Resource Adequacy Analyses with PRAS](@id multi_metric_resource_adequacy)
#
# In practice, no single metric fully captures system adequacy. Instead,
# multiple complementary metrics should be considered together to understand
# the frequency, distribution and severity of shortfall events.
# ([NERC (2018)](https://www.nerc.com/globalassets/who-we-are/standing-committees/rstc/pawg/probabilistic_adequacy_and_measures_report.pdf),
# [EPRI](https://www.epri.com/research/products/3002027833), 
# [ESIG (2024)](https://www.esig.energy/reports-briefs/new-resource-adequacy-criteria/),
# [Stephen et al. 2022](https://doi.org/10.1109/PMAPS53380.2022.9810615)).
#
# For this reason, PRAS provides multiple result specifications and derived
# metrics that allow different aspects of system risk to be evaluated
# consistently.
# This tutorial compares metrics that describe the temporal occurrence and
# magnitude of shortfalls.

# ## Temporal Occurrence of Shortfall
#
# Resource adequacy metrics can be understood by first defining two related concepts ([Stephen et al. 2022](https://doi.org/10.1109/PMAPS53380.2022.9810615)):
#
# - An **event-period** is a simulation time step in which a shortfall occurs.
# - An **event-day** is a day containing at least one event-period.
#
# These distinctions are important because LOLE and LOLD count different quantities:
#
# - **LOLE** is the expected number of event-periods
# - **LOLD** is the expected number of event-days
#
# These metrics are related, but they are not interchangeable.
#
#md # !!! note
#md #     In PRAS, the time resolution of LOLE is determined by the
#md #     simulation timestamps of the system and is not assumed to always be hourly.

# ## Shortfall Severity
#
# LOLE and LOLD describe when shortfalls occur, but they do not describe their magnitude.
# EUE complements these metrics by measuring the expected total amount of unserved energy over the study horizon.

# ## Why Multiple Metrics Matter
#
# Another important reason to use multiple metrics, as described in
# ([Stephen et al. 2022](https://doi.org/10.1109/PMAPS53380.2022.9810615)), 
# is that systems with similar shortfall magnitudes or counts of event-periods
# can exhibit very different temporal patterns.
#
# We can consider a simple example of two cases next, for which we assume that
# every shortfall hour has the same amount of unserved energy.
#
# **Case A**: One day with 10 hours of shortfall
#
# **Case B**: Ten days with 1 hour of shortfall each
#
# | Metric | Case A | Case B |
# |------|--------|--------|
# | LOLE | 10 | 10 |
# | EUE | same | same |
# | LOLD | 1 | 10 |
#
# As we can see in the table above, even though LOLE and EUE are identical in this case, 
# LOLD reveals that shortfall events are more dispersed in Case B.
#

# Because event-periods may be distributed across many days, a system with the
# same number of shortfall periods can have very different numbers of event-days. 
# As a result, exact conversions between hourly and daily adequacy
# criteria are not generally possible
# ([Stephen et al. 2022](https://doi.org/10.1109/PMAPS53380.2022.9810615)).

# This behavior is reflected in PRAS results, where LOLE and LOLD provide
# complementary views of how shortfall events are distributed in time.
#
#md # !!! note
#md #     LOLD is currently available only for `ShortfallSamples`. Calling LOLD on a `Shortfall` result 
#md #     will raise an error.

# ## Mathematical Interpretation
#
# In PRAS, adequacy metrics can be interpreted from Monte Carlo shortfall
# samples.
#
# Using the following notation:
#
# - ``r`` indexes regions
# - ``t`` indexes timestamps
# - ``d`` indexes calendar days
# - ``s`` indexes Monte Carlo samples
# - ``S_{r,t,s}`` denotes the shortfall in region ``r``, at timestamp ``t``,
#   in Monte Carlo sample ``s``
# - ``T(d)`` is the set of timestamps in day ``d``
# - ``\Delta t`` is the duration of each simulation time step
#
# the adequacy metrics can be expressed as expectations over Monte Carlo samples:
#
# ### LOLE
#
# LOLE counts the expected number of event-periods with shortfall:

# ```math
# \mathrm{LOLE} =
# \mathbb{E}\left[\sum_t
# \mathbf{1}\left(\sum_r S_{r,t,s} > 0\right)\right]
# ```
#
#
# ### LOLD
#
# LOLD counts the expected number of days containing at least one shortfall:

# ```math
# \mathrm{LOLD} = \mathbb{E}\left[\sum_d I_{d,s}\right]
# ```
#
# where:

# ```math
# I_{d,s} =
# \begin{cases}
# 1 & \text{if } \exists t \in T(d) \text{ such that } \sum_r S_{r,t,s} > 0 \\
# 0 & \text{otherwise}
# \end{cases}
# ```

# ### EUE
#
# EUE measures expected total unserved energy across the Monte Carlo samples:

# ```math
# \mathrm{EUE} =
# \mathbb{E}\left[\sum_t \sum_r S_{r,t,s}\,\Delta t\right]
# ```
#
# ## Analysis with PRAS
#
# We revisit the [RTS-GMLC](https://github.com/GridMod/RTS-GMLC) system with increased load to induce shortfall,
# which was described in [PRAS walkthrough](@ref pras_walkthrough)

using PRAS
sys = PRAS.rts_gmlc()
sys.regions.load .+= 700.0

shortfall_samples, = assess(
    sys,
    SequentialMonteCarlo(samples=100, seed=1),
    ShortfallSamples(),
)

# and we calculate the metrics we discussed above:
system_lole = LOLE(shortfall_samples)
system_lold = LOLD(shortfall_samples)
system_eue = EUE(shortfall_samples)

println(system_lole)
println(system_lold)
println(system_eue)

# We can also evaluate upper-tail severity by selecting a CVAR confidence level:
alpha = 0.95
system_cvar = CVAR(:energy, shortfall_samples, alpha)
println(system_cvar)

# In the RTS example above, the system has approximately 85 shortfall hours
# but only 25.8 shortfall days. This indicates that shortfall events are
# temporally clustered, meaning that multiple shortfall hours tend to occur within the
# same day rather than being evenly distributed across the year.
# EUE summarizes the average total unserved energy, while CVAR (``\alpha = 0.95``) summarizes
# unserved energy in outcomes beyond the 95th-percentile threshold.


# ## References
#
# - [NERC (2018), *Probabilistic Adequacy and Measures Technical Reference Report*](https://www.nerc.com/globalassets/who-we-are/standing-committees/rstc/pawg/probabilistic_adequacy_and_measures_report.pdf)
# - [EPRI, *Resource Adequacy Gap Assessment: Resource Adequacy Assessment Framework*](https://www.epri.com/research/products/3002027833)
# - [ESIG (2024), *New Resource Adequacy Criteria for the Energy Transition: Modernizing Reliability Requirements*](https://www.esig.energy/reports-briefs/new-resource-adequacy-criteria/)
# - [Stephen et al. (2022), *Clarifying the Interpretation and Use of the LOLE Resource Adequacy Metric*](https://doi.org/10.1109/PMAPS53380.2022.9810615)
