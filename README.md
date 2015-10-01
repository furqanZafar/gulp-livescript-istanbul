[![Build Status](https://travis-ci.org/furqanZafar/gulp-livescript-istanbul.svg)](https://travis-ci.org/furqanZafar/gulp-livescript-istanbul)    [![Coverage Status](https://coveralls.io/repos/furqanZafar/gulp-livescript-istanbul/badge.svg?branch=master&service=github)](https://coveralls.io/github/furqanZafar/gulp-livescript-istanbul?branch=master)

# gulp-livescript-istanbul
Istanbul unit test coverage plugin for gulp, covering livescript and javascript.

Allows for in-place testing and coverage of livescripts files without the need for compiling and linking to the compiled source.

Displays coverage report in livescript, thanks to source map support in [livescript@1.4.0](http://livescript.net/) 

Inspired by [gulp-coffee-istanbul](https://github.com/duereg/gulp-coffee-istanbul) & [istanbul-traceur](https://github.com/meoguru/istanbul-traceur)

Works on top of any Node.js unit test framework.

## Installation

```shell
npm install --save-dev gulp-livescript-istanbul
```

## Usage

```livescript
require! \gulp
require! \gulp-exit
require! \gulp-mocha
{instrument, hook-require, write-reports} = (require \gulp-livescript-istanbul)!
 
gulp.task \coverage, ->
    gulp.src <[src/*.ls]>

    # transform livescript code into instrumented javascript code
    .pipe instrument!

    # hook require and return the instrumented code instead of the original livescript code
    .pipe hook-require!
    
    gulp.src <[./test/index.ls]>

    # with the require hook in place we can now run any unit test suite
    .pipe gulp-mocha!

    # write the lcov coverage report to ./coverage directory
    .pipe write-reports!
    .on \finish, -> process.exit!
```
