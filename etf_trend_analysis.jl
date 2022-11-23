using AlpacaMarkets
using DataFrames, DataFramesMeta
using Dates
using Plots, PlotThemes
using RollingFunctions, Statistics
theme(:bright)

spy = stock_bars("SPY", "1Day"; startTime=now() - Year(10), limit=10000, adjustment="all")[1]
bnd = stock_bars("BND", "1Day"; startTime=now() - Year(10), limit=10000, adjustment="all")[1];
gld = stock_bars("GLD", "1Day"; startTime=now() - Year(10), limit=10000, adjustment="all")[1];