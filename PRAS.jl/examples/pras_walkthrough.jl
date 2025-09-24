# # Quick PRAS walk-through  

# This section provides a more complete example of running a PRAS assessment,
# using the [RTS-GMLC](https://github.com/GridMod/RTS-GMLC) system
# making use of multiple different results.

# Load the PRAS module
using PRAS
using Plots

# ## Read and explore a SystemModel

# You can load in a system model from a .pras file if you have one like so:
# ```julia
# sys = SystemModel("mysystem.pras")
# ```

# For the purposes of this example, we'll just use the built-in RTS-GMLC model.
sys = PRAS.rts_gmlc();

# We see some information about the system by just typing its name
# (or rather the variable that holds it):
sys

# This system has 3 regions, with multiple Generators, one GenerationStorage in 
# region "2" and one Storage in region "3". We can see regional information by 
# indexing the system with the region name:
sys["2"]

# We can find more information about all the Generators in the system by
# retriving the `generators` in the SystemModel:
system_generators = sys.generators

# This returns an object of the asset type [Generators](@ref PRASCore.Systems.Generators)
# and we can retrieve capacities of all generators in the system, which returns 
# a Matrix with the shape (number of generators) x (number of timepoints):
system_generators.capacity

# We can visualize a time series of the total system capacity 
# (sum over individual generators' capacity at each time step)
plot(sys.timestamps, sum(system_generators.capacity, dims=1)', 
     xlabel="Time", ylabel="Total system capacity (MW)", legend=false)

# Or, by category of generators:
category_indices = Dict([cat => findall(==(cat), system_generators.categories) 
                    for cat in unique(system_generators.categories)]);
capacity_matrix = Vector{Vector{Int}}();
for (category,indices) in category_indices
    push!(capacity_matrix, sum(system_generators.capacity[indices, :], dims=1)[1,:])
end
areaplot(sys.timestamps, hcat(capacity_matrix...),  
        label=permutedims(collect(keys(category_indices))),
        xlabel="Time", ylabel="Total system capacity (MW)")

# Similarly we can also retrieve all the Storages in the system and 
# GenerationStorages in the system using `sys.storages` and `sys.generatorstorages`, 
# respectively.

# To retrieve the assets in a particular region, we can index by the region name
# and asset type (`Generators` here):
region_2_generators = sys["2", Generators]

# We get the storage device in region "3" like so:
region_3_storage = sys["3", Storages]
# and the generation-storage device in region "2" like so:
region_2_genstorage = sys["2", GeneratorStorages]

# ## Run a Sequential Monte Carlo simulation

# We can run a Sequential Monte Carlo simulation on this system using the
# [assess](@ref PRASCore.Simulations.assess) function. 
# Here we will also use three different [result specifications](@ref results):
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
