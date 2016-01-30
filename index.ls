require! \cli-color
{read-file-sync} = require \fs
{Collector, hook, Instrumenter, Report, utils} = require \istanbul
{compile}:livescript = require \livescript
require! \path
{capitalize, each, filter, keys, map, Obj, obj-to-pairs, pairs-to-obj} = require \prelude-ls
{SourceMapConsumer} = require \source-map
through = (require \through2).obj

coverage-variable = "$$cov_#{Date.now!}$$" 
global[coverage-variable] = {}

# transpile :: String, String? -> {compiled-code :: String, source-map :: SourceMap}
transpile = do ->
    cache = {}
    (full-path, original-code) ->
        return cache[full-path] if !!cache[full-path]
        return null if typeof original-code == \undefined
        
        {code, map} = compile original-code, {map: \embedded, filename: full-path}
        cache[full-path] := compiled-code: code, source-map: JSON.parse JSON.stringify map

# an instrumenter injects counting code, for tracking coverage, after statements, branches & functions
# unsurprisingly, the code generated, is referred to as "instrumented code" in the following comments
# instrument-code :: String -> Instrumenter -> String -> {coverage-json :: object, instrumented-code :: String}
instrument-code = do ->
    cache = {}
    (full-path, instrumenter, code) ->
        return cache[full-path] if !!cache[full-path]
        return null if typeof instrumenter == \undefined
        
        instrumented-code = instrumenter.instrument-sync code, full-path
        [result] = /\{.*"path".*"fnMap".*"statementMap".*"branchMap".*\}/g.exec instrumented-code
        cache[full-path] = {coverage-json: (JSON.parse result), instrumented-code}

class LivescriptInstrumenter extends Instrumenter

    # instrument-sync :: String -> String -> String
    instrument-sync: (livescript-code, full-path) ->
        {compiled-code} = transpile full-path, livescript-code
        super compiled-code, full-path

    # get-preamble :: 
    get-preamble: ->
        
        {path, statement-map, branch-map, fn-map} = @cover-state
        source-map-consumer = new SourceMapConsumer (transpile path).source-map

        # the following code does not work without location MUTATION
        # _fix-location :: Location -> Location
        _fix-location = ({start, end}:location) -->

            location <<<
                start: (source-map-consumer.original-position-for start)
                end: (source-map-consumer.original-position-for end)
    
            if location.start.source != path
                location <<<
                    start: 
                        line: 0
                        column: 0
                    end: 
                        line: 0
                        column: 0
                    skip: true
            
            location
        
        statement-map |> Obj.map _fix-location
        branch-map |> Obj.map ({locations}:branch) -> branch <<< locations: locations |> map _fix-location
        fn-map |> Obj.map ({loc}:fn) -> fn <<< loc: _fix-location loc
        
        super ...

module.exports = ->

    # instrument the files and store the coverage information in global space so it can be updated by instrumented code
    instrument: (opts) ->
        through (file, encoding, callback) ->
            full-path = path.resolve file.path

            # decide which instrumenter to use based on the file extension
            instrumenter = new (if (full-path.index-of \.ls) > -1 then LivescriptInstrumenter else Instrumenter) {coverage-variable}

            # use a global variable to store the coverage data so it can be updated by instrumented code later
            {coverage-json, instrumented-code} = instrument-code full-path, instrumenter, file.contents.to-string!
            global[coverage-variable][full-path] = coverage-json

            file.contents = new Buffer instrumented-code
            callback null, file

    # hook calls to the require function and return instrumented code
    hook-require: (opts) ->
        through do 
            (file, encoding, callback) ->
                delete require.cache[path.resolve file.path]
                callback null, file
            (callback) !->
                hook.unhook-require!
                
                # hook-require :: (String -> Boolean) -> (String -> String -> String) -> object -> ?
                hook.hook-require do 
                    (path) -> !!(instrument-code path)
                    (code, path) -> (instrument-code path).instrumented-code
                    extensions: <[.js .ls]>
                callback!

    # must be called after running unit tests
    # ReportName :: String
    # ReportOpts :: {dir :: String, ...}
    # Opts :: {log-summary :: Boolean, reports :: Map ReportName, ReportOpts}
    # write-reports :: Opts -> (? -> ?)
    write-reports: ({log-summary}:opts?) ->
        through do 
            (file, encoding, callback) -> callback null, file
            -> 

                # add the updated coverage information to the collector
                collector = new Collector!
                    ..add global[coverage-variable]

                reports = (opts?.reports ? {lcov: dir: \./coverage})

                if typeof log-summary == \undefined or log-summary == true
                    console.log "============================================================================="
                    reports 
                        |> obj-to-pairs
                        |> filter ([, report-opts]) -> !!report-opts?.dir
                        |> each ([report-name, {dir}]) ->
                            console.log "Writing #{report-name} reports to [#{path.resolve dir}]"
                    console.log "============================================================================="
                    console.log ""

                    # Stats :: {pct :: Number, total :: Int, covered :: Int}
                    # report-summary :: {lines :: Stats, statements :: Stats, branches :: Stats, functions :: Stats, lines-covered :: object}
                    report-summary = utils.summarize-coverage collector.get-final-coverage!

                    console.log "=============================== Coverage summary ==============================="
                    <[statements branches functions lines]> |> each ->
                        {covered, total, pct} = report-summary[it]
                        color = switch
                            | pct < 50 => \redBright
                            | pct >= 80 => \greenBright
                            | _ => \yellowBright
                        console.log cli-color[color] "#{' ' * (13 - it.length)}#{capitalize it} : #{pct}% (#{covered}/#{total})"
                    console.log "================================================================================"

                # write reprots to disk
                reports
                    |> obj-to-pairs
                    |> each ([report-name, report-opts]) ->
                        report = Report.create report-name, report-opts
                            ..write-report collector, true
