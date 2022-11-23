using JSON
using AlpacaMarkets
using DataFrames, DataFramesMeta
using Dates
using Plots, PlotThemes
using RollingFunctions, Statistics
theme(:bright)

# https://dm13450.github.io/2022/11/18/Trend-Following-with-ETFs.html

alpaca_conn = JSON.parsefile(joinpath(pwd(), "./user_config/jjm_config.json"))
AlpacaMarkets.auth(alpaca_conn["alpaca_login"]["key"], alpaca_conn["alpaca_login"]["secret"])

spy = stock_bars("SPY", "1Day"; startTime=now() - Year(10), limit=10000, adjustment="all")[1];
bnd = stock_bars("BND", "1Day"; startTime=now() - Year(10), limit=10000, adjustment="all")[1];
gld = stock_bars("GLD", "1Day"; startTime=now() - Year(10), limit=10000, adjustment="all")[1];

function parse_date(t)
    Date(string(split(t, "T")[1]))
end

function clean(df, x)
    df = @transform(df, :Date = parse_date.(:t), :Ticker = x, :NextOpen = [:o[2:end]; NaN])
    @select(df, :Date, :Ticker, :c, :o, :NextOpen)
end

spy = clean(spy, "SPY")
bnd = clean(bnd, "BND")
gld = clean(gld, "GLD");

allPrices = vcat(spy, bnd, gld)
allPrices = sort(allPrices, :Date)
last(allPrices, 6)

plot(plot(spy.Date, spy.c, label=:none, title="SPY"),
    plot(bnd.Date, bnd.c, label=:none, title="BND", color="red"),
    plot(gld.Date, gld.c, label=:none, title="GLD", color="green"), layout=(3, 1))

allPrices = @transform(groupby(allPrices, :Ticker),
    :Return = [NaN; diff(log.(:c))],
    :ReturnTC = [NaN; diff(log.(:NextOpen))]);

allPrices = @transform(groupby(allPrices, :Ticker), :RunVol = sqrt.(runvar(:Return, 256)));
allPrices = @transform(groupby(allPrices, :Ticker), :rhat = :Return .* 0.1 ./ :RunVol);

allPricesClean = @subset(allPrices, .!isnan.(:rhat))
allPricesClean = @transform(groupby(allPricesClean, :Ticker), :rhatC = cumsum(:rhat), :rc = cumsum(:Return));

@combine(groupby(allPricesClean, :Ticker), :AvgReturn = mean(:Return), :AvgNormReturn = mean(:rhat),
    :StdReturn = std(:Return), :StdNormReturn = std(:rhat))

plot(allPricesClean.Date, allPricesClean.rhatC, group=allPricesClean.Ticker, legend=:topleft, title="Normalised Cumulative Returns")

allPricesClean = @transform(groupby(allPricesClean, :Ticker),
    :Signal = sign.(runmean(:rhat, 100)),
    :SignalLO = runmean(:rhat, 100) .> 0);

portRes = @combine(groupby(allPricesClean, :Date),
    :TotalReturn = sum((1 / 3) * (:Signal .* :rhat)),
    :TotalReturnLO = sum((1 / 3) * (:SignalLO .* :rhat)),
    :TotalReturnTC = sum((1 / 3) * (:Signal .* :ReturnTC)),
    :TotalReturnUL = sum((1 / 3) * (:Signal .* :Return)));

portRes = @transform(portRes, :TotalReturnC = cumsum(:TotalReturn),
    :TotalReturnLOC = cumsum(:TotalReturnLO),
    :TotalReturnTCC = cumsum(:TotalReturnTC),
    :TotalReturnULC = cumsum(:TotalReturnUL))


plot(portRes.Date, portRes.TotalReturnC, label="Trend Following", legendposition=:topleft, linewidth=3)
plot!(portRes.Date, portRes.TotalReturnLOC, label="Trend Following - LO", legendposition=:topleft, linewidth=3)

plot!(allPricesClean.Date, allPricesClean.rhatC, group=allPricesClean.Ticker)

portRes2022 = @transform(@subset(portRes, :Date .>= Date("2022-01-01")),
    :TotalReturnC = cumsum(:TotalReturn),
    :TotalReturnLOC = cumsum(:TotalReturnLO),
    :TotalReturnULC = cumsum(:TotalReturnUL))

allPricesClean2022 = @subset(allPricesClean, :Date .>= Date("2022-01-01"))
allPricesClean2022 = @transform(groupby(allPricesClean2022, :Ticker), :rhatC = cumsum(:Return))

plot(portRes2022.Date, portRes2022.TotalReturnULC, label="Trend Following", legendposition=:topleft, linewidth=3)
plot!(portRes2022.Date, portRes2022.TotalReturnLOC, label="Trend Following - LO", legendposition=:topleft, linewidth=3)
plot!(allPricesClean2022.Date, allPricesClean2022.rhatC, group=allPricesClean2022.Ticker)

allPricesClean = @transform(groupby(allPricesClean, :Ticker), :SigChange = [NaN; diff(:Signal)])

trades = @subset(allPricesClean[!, [:Date, :Ticker, :o, :c, :Signal, :NextOpen, :SigChange]],
    :SigChange .!= 0);

@combine(groupby(trades, :Ticker),
    :N = length(:Signal),
    :IS = mean(:Signal .* 1e4 .* (:NextOpen .- :c) ./ :c))

plot(portRes.Date, portRes.TotalReturnULC, label="Trend Following", legendposition=:topleft)
plot!(allPricesClean.Date, allPricesClean.rc, group=allPricesClean.Ticker)
plot!(portRes.Date, portRes.TotalReturnTCC, label="Trend Following - TC", legendposition=:topleft, linewidth=3)