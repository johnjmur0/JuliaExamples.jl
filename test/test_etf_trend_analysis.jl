@testset "Get Prices Test" begin

    prices = JuliaExamples.get_all_prices()

    @test nrow(prices) > 5000
    @test ["Date", "Ticket"] < names(prices)
end