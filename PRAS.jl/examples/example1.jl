# # Additional Examples

# This section provides a more complete example of running a PRAS assessment,
# with a hypothetical analysis process making use of multiple different
# results.


using PRAS

# Load in a system model from a .pras file.
# This hypothetical system has an hourly time resolution with an
# extent / simulation horizon of one year.
sys = PRAS.rts_gmlc()

# This system has multiple regions and relies on battery storage, so
# run a sequential Monte Carlo analysis:
shortfall, utilization, storage = assess(
    sys, SequentialMonteCarlo(samples=100, seed=1),
    Shortfall(), Utilization(), StorageEnergy());

# Start by checking the overall system adequacy:
lole = LOLE(shortfall) # event-hours per year
eue = EUE(shortfall) # unserved energy per year

# Suppose LOLE is below the target threshold but EUE seems high, suggesting large
# amounts of unserved energy are concentrated in a small number of hours. What
# do the hourly results show?


# Note 1: LOLE.(shortfall, many_hours) is Julia shorthand for calling LOLE
#         on every timestep in the collection many_hours
# Note 2: Here results are in terms of event-hours per hour, which is
#         equivalent to the loss-of-load probability (LOLP) for each hour
lolps = LOLE.(shortfall, sys.timestamps)

# One might see that a particular hour has an LOLP near 1.0, indicating that
# load is consistently getting dropped in that period. Is this a local issue or
# system-wide? One can check the unserved energy by region in that hour:


shortfall_period = ZonedDateTime(2020, 8, 21, 17, tz"America/Denver")
unserved_by_region = EUE.(shortfall, sys.regions.names, shortfall_period)

# Perhaps only one region (D) has non-zero EUE in that hour, indicating that this
# must be a load pocket issue. We can also look at the utilization of interfaces
# into that region in that period:


utilization["1" => "2", shortfall_period]
utilization["2" => "3", shortfall_period]
utilization["3" => "1", shortfall_period]

# These sample-averaged utilizations should all be very close to 1.0, indicating
# that power transfers are consistently maxed out; neighbouring regions have
# power available but can't send it to Region D.

# Transmission expansion is clearly one solution to this adequacy issue. Is local
# storage another alternative? One can check on the average state-of-charge of
# the existing battery in that region, both in the hour before and during the
# problematic period:


storage["313_STORAGE_1", shortfall_period-Hour(1)]
storage["313_STORAGE_1", shortfall_period]

# It may be that the battery is on average fully charged going in to the event,
# and perhaps retains some energy during the event, even as load is being
# dropped. The device's ability to mitigate the shortfall must then be limited
# only by its discharge capacity, so given that the event doesn't last long,
# adding additional short-duration storage in this region would help.

# Note that if the event was less consistent, this analysis could also have been
# performed on the subset of samples in which the event was observed, using the
# `ShortfallSamples`, `UtilizationSamples`, and
# `StorageEnergySamples` result specifications instead.
