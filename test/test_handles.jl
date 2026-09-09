@testset "typed-handles registry fields" begin
    s = CommandSpec(path=["estimate", "var"], summary="x",
                    args=[ArgSpec(name="data")],
                    handler=wrap_legacy((; kwargs...) -> nothing))
    @test s.data_kinds == Symbol[]
    @test s.model_types == Symbol[]
    @test s.result_types == Symbol[]
    @test MODEL_OPTION.handle === true
    @test SAVE_MODEL_OPTION.handle === false
    tagged = with_data_kinds([s], [:timeseries, :csv])
    @test tagged[1].data_kinds == [:timeseries, :csv]
    @test tagged[1].path == s.path
    @test tagged[1].handler === s.handler
    copied = with_options([s], [MODEL_OPTION])
    @test copied[1].data_kinds == s.data_kinds
    @test any(o -> o.name == "model" && o.handle, copied[1].options)
end
