require! \fs
require! \gulp
require! \gulp-livescript

gulp.task \build, ->
    gulp.src <[./index.ls]>
    .pipe gulp-livescript!
    .pipe gulp.dest \./

gulp.task \watch, ->
    gulp.watch <[./index.ls]>, <[build]>

gulp.task \default, <[build watch]>