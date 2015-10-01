require! \assert
{exists-sync, read-file-sync, write-file-sync} = require \fs
require! \gulp
require! \gulp-exit
require! \gulp-mocha
require! \gulp-util
gulp-livescript-istanbul = (require \../index)
require! \path
require! \rimraf

describe "gulp-livescript-istanbul", ->

    before-each ->
        @test-file = new gulp-util.File do 
            path: \test/fixtures/calculator.ls
            cwd: \test/
            base: \test/fixtures/
            contents: read-file-sync \test/fixtures/calculator.ls
    
    describe "instrumentation & hooking", ->

        specify "must instrument code", (done) ->
            {instrument} = gulp-livescript-istanbul!
            stream = instrument!
                ..on \data, (file) -> 
                    assert (file.contents.to-string!.index-of \__cov_) > -1
                    assert (file.contents.to-string!.index-of \$$cov_) > -1
                    done!
                ..write @test-file
                ..end!

        specify "must hook require", (done) ->
            {instrument, hook-require} = gulp-livescript-istanbul!
            add-before-hook = require \./fixtures/calculator
            stream = instrument!
                .pipe hook-require!
                .on \finish, ->
                    add-after-hook = require \./fixtures/calculator
                    assert.not-equal add-before-hook, add-after-hook
                    done!
            stream.write @test-file
            stream.end!

    describe "report writing", ->

        before-each (done) ->
            {instrument, hook-require, write-reports} = gulp-livescript-istanbul!
            stream = instrument!
                .pipe hook-require!
                .on \finish, done
            stream.write @test-file
            stream.end!
            @out = process.stdout.write.bind process.stdout
            @write-reports = write-reports

        after-each ->
            rimraf.sync \coverage
            rimraf.sync \_coverage
            process.stdout.write = @out

        specify "must write reports", (done) ->
            process.stdout.write = ->
            gulp.src <[test/fixtures/index.ls]>
                .pipe gulp-mocha!
                .pipe @write-reports!
                .on \finish, ->
                    assert exists-sync \coverage
                    done!

        specify "must write reports to specified output directory", (done) ->
            process.stdout.write = ->
            gulp.src <[test/fixtures/index.ls]>
                .pipe gulp-mocha!
                .pipe @write-reports reports: lcov: dir: \./_coverage
                .on \finish, ->
                    assert exists-sync \_coverage
                    done!
